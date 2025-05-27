#!/usr/bin/env python3
"""
Keycloak Authentication Integration for AI Testing Agent
Integrates with PlannerDDF Keycloak instance for seamless authentication
"""

import os
import jwt
import time
import yaml
import requests
from typing import Dict, Optional, Tuple, Any
from functools import wraps
from flask import Flask, request, jsonify, g, redirect, session
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)

class KeycloakAuth:
    """Keycloak authentication integration for AI Testing Agent"""
    
    def __init__(self, config_path: str = "/app/config/auth/keycloak-integration-deployment.yml"):
        self.config = self._load_config(config_path)
        self.keycloak_config = self.config['keycloak']
        self.token_cache = {}  # Cache for validated tokens
        
        # Build Keycloak URLs
        self.server_url = self.keycloak_config['server_url']
        self.realm = self.keycloak_config['realm']
        self.client_id = self.keycloak_config['client_id']
        self.client_secret = os.getenv('KEYCLOAK_CLIENT_SECRET', self.keycloak_config.get('client_secret', ''))
        
        # Keycloak endpoints
        self.auth_url = f"{self.server_url}/auth/realms/{self.realm}/protocol/openid-connect/auth"
        self.token_url = f"{self.server_url}/auth/realms/{self.realm}/protocol/openid-connect/token"
        self.userinfo_url = f"{self.server_url}/auth/realms/{self.realm}/protocol/openid-connect/userinfo"
        self.introspect_url = f"{self.server_url}/auth/realms/{self.realm}/protocol/openid-connect/token/introspect"
        
        logger.info(f"Keycloak auth initialized for realm: {self.realm}")
    
    def _load_config(self, config_path: str) -> Dict[str, Any]:
        """Load Keycloak configuration"""
        try:
            with open(config_path, 'r') as f:
                config = yaml.safe_load(f)
            
            # Apply environment-specific overrides
            env = os.getenv('ENVIRONMENT', 'development')
            if env in config.get('environments', {}):
                env_config = config['environments'][env]
                config = self._merge_config(config, env_config)
            
            return config
        except Exception as e:
            logger.error(f"Failed to load Keycloak config: {e}")
            # Fallback configuration
            return {
                'keycloak': {
                    'enabled': False,
                    'server_url': 'http://localhost:8080',
                    'realm': 'planner-ddf',
                    'client_id': 'deployer-ddf-mod-llm-models'
                },
                'authentication': {'method': 'api_token'}
            }
    
    def _merge_config(self, base: Dict, override: Dict) -> Dict:
        """Merge configuration dictionaries"""
        result = base.copy()
        for key, value in override.items():
            if isinstance(value, dict) and key in result:
                result[key] = self._merge_config(result[key], value)
            else:
                result[key] = value
        return result
    
    def get_auth_url(self, state: str = None) -> str:
        """Generate Keycloak authorization URL"""
        params = {
            'client_id': self.client_id,
            'redirect_uri': self.keycloak_config['redirect_uri'],
            'response_type': 'code',
            'scope': 'openid profile email'
        }
        
        if state:
            params['state'] = state
        
        query_string = '&'.join([f"{k}={v}" for k, v in params.items()])
        return f"{self.auth_url}?{query_string}"
    
    def exchange_code_for_token(self, code: str) -> Tuple[bool, Optional[Dict], Optional[str]]:
        """Exchange authorization code for access token"""
        try:
            data = {
                'grant_type': 'authorization_code',
                'client_id': self.client_id,
                'client_secret': self.client_secret,
                'code': code,
                'redirect_uri': self.keycloak_config['redirect_uri']
            }
            
            response = requests.post(self.token_url, data=data)
            
            if response.status_code == 200:
                token_data = response.json()
                logger.info("Successfully exchanged code for token")
                return True, token_data, None
            else:
                error_msg = f"Token exchange failed: {response.status_code}"
                logger.error(error_msg)
                return False, None, error_msg
                
        except Exception as e:
            error_msg = f"Token exchange error: {str(e)}"
            logger.error(error_msg)
            return False, None, error_msg
    
    def validate_token(self, access_token: str) -> Tuple[bool, Optional[Dict], Optional[str]]:
        """Validate access token with Keycloak"""
        # Check cache first
        cache_key = f"token_{access_token[:16]}"
        if cache_key in self.token_cache:
            cached_data = self.token_cache[cache_key]
            if datetime.utcnow() < cached_data['expires_at']:
                return True, cached_data['user_info'], None
            else:
                del self.token_cache[cache_key]
        
        try:
            # Introspect token
            data = {
                'token': access_token,
                'client_id': self.client_id,
                'client_secret': self.client_secret
            }
            
            response = requests.post(self.introspect_url, data=data)
            
            if response.status_code == 200:
                introspect_data = response.json()
                
                if not introspect_data.get('active', False):
                    return False, None, "Token is not active"
                
                # Get user info
                headers = {'Authorization': f'Bearer {access_token}'}
                userinfo_response = requests.get(self.userinfo_url, headers=headers)
                
                if userinfo_response.status_code == 200:
                    user_info = userinfo_response.json()
                    
                    # Check required roles
                    if not self._check_required_roles(user_info):
                        return False, None, "Insufficient permissions"
                    
                    # Cache the result
                    cache_duration = self.config['authentication']['keycloak']['cache_duration']
                    self.token_cache[cache_key] = {
                        'user_info': user_info,
                        'expires_at': datetime.utcnow() + timedelta(seconds=cache_duration)
                    }
                    
                    logger.info(f"Token validated for user: {user_info.get('preferred_username')}")
                    return True, user_info, None
                else:
                    return False, None, "Failed to get user info"
            else:
                return False, None, f"Token introspection failed: {response.status_code}"
                
        except Exception as e:
            error_msg = f"Token validation error: {str(e)}"
            logger.error(error_msg)
            return False, None, error_msg
    
    def _check_required_roles(self, user_info: Dict) -> bool:
        """Check if user has required roles"""
        required_roles = self.keycloak_config.get('required_roles', [])
        if not required_roles:
            return True
        
        user_roles = []
        
        # Extract roles from different possible locations
        realm_access = user_info.get('realm_access', {})
        if 'roles' in realm_access:
            user_roles.extend(realm_access['roles'])
        
        # Check if user has any of the required roles
        for role in required_roles:
            if role in user_roles:
                return True
        
        logger.warning(f"User {user_info.get('preferred_username')} lacks required roles: {required_roles}")
        return False
    
    def authenticate_request(self) -> Tuple[bool, Optional[str], Optional[Dict]]:
        """Authenticate request using Keycloak token"""
        # Check for Bearer token in Authorization header
        auth_header = request.headers.get('Authorization', '')
        
        if not auth_header.startswith('Bearer '):
            return False, "Missing or invalid Authorization header", None
        
        access_token = auth_header.split(' ', 1)[1]
        
        # Validate token with Keycloak
        valid, user_info, error = self.validate_token(access_token)
        
        if valid:
            return True, None, {
                'user_id': user_info.get('preferred_username'),
                'email': user_info.get('email'),
                'roles': user_info.get('realm_access', {}).get('roles', []),
                'method': 'keycloak'
            }
        else:
            return False, error, None
    
    def logout_user(self, refresh_token: str = None) -> bool:
        """Logout user from Keycloak"""
        try:
            if refresh_token:
                data = {
                    'client_id': self.client_id,
                    'client_secret': self.client_secret,
                    'refresh_token': refresh_token
                }
                
                logout_url = f"{self.server_url}/auth/realms/{self.realm}/protocol/openid-connect/logout"
                response = requests.post(logout_url, data=data)
                
                return response.status_code == 204
            
            return True
            
        except Exception as e:
            logger.error(f"Logout error: {str(e)}")
            return False

def setup_keycloak_routes(app: Flask, keycloak_auth: KeycloakAuth):
    """Setup Keycloak authentication routes"""
    
    @app.route('/auth/keycloak/login')
    def keycloak_login():
        """Initiate Keycloak login"""
        state = os.urandom(16).hex()
        session['oauth_state'] = state
        
        auth_url = keycloak_auth.get_auth_url(state)
        return redirect(auth_url)
    
    @app.route('/auth/keycloak/callback')
    def keycloak_callback():
        """Handle Keycloak callback"""
        code = request.args.get('code')
        state = request.args.get('state')
        
        # Verify state parameter
        if state != session.get('oauth_state'):
            return jsonify({'error': 'Invalid state parameter'}), 400
        
        if not code:
            return jsonify({'error': 'Authorization code not provided'}), 400
        
        # Exchange code for token
        success, token_data, error = keycloak_auth.exchange_code_for_token(code)
        
        if success:
            # Store tokens in session (or return to client)
            session['access_token'] = token_data['access_token']
            session['refresh_token'] = token_data.get('refresh_token')
            
            return jsonify({
                'message': 'Authentication successful',
                'access_token': token_data['access_token'],
                'expires_in': token_data.get('expires_in'),
                'usage': f"Authorization: Bearer {token_data['access_token']}"
            })
        else:
            return jsonify({'error': error}), 400
    
    @app.route('/auth/keycloak/logout', methods=['POST'])
    def keycloak_logout():
        """Logout from Keycloak"""
        refresh_token = session.get('refresh_token') or request.json.get('refresh_token')
        
        success = keycloak_auth.logout_user(refresh_token)
        
        # Clear session
        session.clear()
        
        if success:
            return jsonify({'message': 'Logout successful'})
        else:
            return jsonify({'message': 'Logout completed (with warnings)'}), 200

# Integration with existing auth middleware
def create_keycloak_auth_decorator(keycloak_auth: KeycloakAuth):
    """Create Keycloak authentication decorator"""
    def require_keycloak_auth(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            authenticated, error, user_info = keycloak_auth.authenticate_request()
            
            if not authenticated:
                logger.warning(f"Keycloak authentication failed: {error}")
                return jsonify({
                    'error': 'Authentication failed',
                    'message': error,
                    'auth_url': keycloak_auth.get_auth_url(),
                    'timestamp': datetime.utcnow().isoformat()
                }), 401
            
            # Store user info in Flask's g object
            g.user = user_info
            g.authenticated = True
            
            return f(*args, **kwargs)
        return decorated_function
    return require_keycloak_auth

# Example usage
if __name__ == "__main__":
    app = Flask(__name__)
    app.secret_key = os.urandom(24)
    
    keycloak_auth = KeycloakAuth()
    setup_keycloak_routes(app, keycloak_auth)
    require_keycloak_auth = create_keycloak_auth_decorator(keycloak_auth)
    
    @app.route('/api/generate', methods=['POST'])
    @require_keycloak_auth
    def generate_test():
        return jsonify({
            'message': 'Test generation endpoint',
            'user': g.user,
            'authenticated': g.authenticated
        })
    
    app.run(debug=True, port=5000) 