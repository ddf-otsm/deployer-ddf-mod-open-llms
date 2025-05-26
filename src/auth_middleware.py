#!/usr/bin/env python3
"""
AI Testing Agent Authentication Middleware
Professional authentication implementation with multiple auth methods
"""

import os
import jwt
import time
import yaml
import boto3
import hashlib
import secrets
from typing import Dict, Optional, Tuple, Any
from functools import wraps
from flask import Flask, request, jsonify, g
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)

class AuthenticationError(Exception):
    """Custom authentication exception"""
    pass

class AuthMiddleware:
    """Professional authentication middleware for AI Testing Agent"""
    
    def __init__(self, config_path: str = "/app/config/auth-config.yml"):
        self.config = self._load_config(config_path)
        self.auth_method = self.config['authentication']['method']
        self.tokens = {}  # In-memory token store (use Redis in production)
        self.rate_limits = {}  # Rate limiting store
        
        # Initialize AWS clients if needed
        if self.auth_method == 'iam_role':
            self.sts_client = boto3.client('sts')
            
        logger.info(f"Authentication middleware initialized with method: {self.auth_method}")
    
    def _load_config(self, config_path: str) -> Dict[str, Any]:
        """Load authentication configuration"""
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
            logger.error(f"Failed to load auth config: {e}")
            # Fallback to no authentication
            return {
                'authentication': {'method': 'none'},
                'security': {'rate_limiting': {'enabled': False}}
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
    
    def generate_api_token(self, user_id: str = "deployer-ddf-mod-llm-models") -> str:
        """Generate a new API token"""
        token_config = self.config['authentication']['api_token']
        
        # Generate secure random token
        token = secrets.token_urlsafe(token_config['token_length'])
        
        # Store token with expiration
        expiration = datetime.utcnow() + timedelta(hours=token_config['expiration_hours'])
        self.tokens[token] = {
            'user_id': user_id,
            'created_at': datetime.utcnow(),
            'expires_at': expiration,
            'requests_count': 0
        }
        
        logger.info(f"Generated new API token for user: {user_id}")
        return token
    
    def validate_api_token(self, token: str) -> Tuple[bool, Optional[str]]:
        """Validate API token"""
        if token not in self.tokens:
            return False, "Invalid token"
        
        token_data = self.tokens[token]
        
        # Check expiration
        if datetime.utcnow() > token_data['expires_at']:
            del self.tokens[token]
            return False, "Token expired"
        
        # Update usage count
        token_data['requests_count'] += 1
        
        return True, None
    
    def validate_iam_role(self, aws_access_key: str, aws_secret_key: str, aws_session_token: str = None) -> Tuple[bool, Optional[str]]:
        """Validate AWS IAM role authentication"""
        try:
            # Create temporary credentials
            session = boto3.Session(
                aws_access_key_id=aws_access_key,
                aws_secret_access_key=aws_secret_key,
                aws_session_token=aws_session_token
            )
            
            sts = session.client('sts')
            
            # Verify credentials by getting caller identity
            response = sts.get_caller_identity()
            
            # Check if the role ARN matches expected pattern
            arn = response.get('Arn', '')
            expected_role = self.config['authentication']['iam_role']['role_arn']
            
            if 'deployer-ddf-mod-llm-models' in arn or arn == expected_role:
                logger.info(f"IAM authentication successful for ARN: {arn}")
                return True, None
            else:
                return False, f"Unauthorized role: {arn}"
                
        except Exception as e:
            logger.error(f"IAM authentication failed: {e}")
            return False, f"IAM authentication error: {str(e)}"
    
    def check_rate_limit(self, client_id: str) -> Tuple[bool, Optional[str]]:
        """Check rate limiting"""
        if not self.config['security']['rate_limiting']['enabled']:
            return True, None
        
        rate_config = self.config['security']['rate_limiting']
        window_minutes = rate_config['window_minutes']
        max_requests = rate_config['max_requests']
        
        now = datetime.utcnow()
        window_start = now - timedelta(minutes=window_minutes)
        
        # Clean old entries
        if client_id in self.rate_limits:
            self.rate_limits[client_id] = [
                req_time for req_time in self.rate_limits[client_id]
                if req_time > window_start
            ]
        else:
            self.rate_limits[client_id] = []
        
        # Check limit
        if len(self.rate_limits[client_id]) >= max_requests:
            return False, f"Rate limit exceeded: {max_requests} requests per {window_minutes} minutes"
        
        # Add current request
        self.rate_limits[client_id].append(now)
        return True, None
    
    def authenticate_request(self) -> Tuple[bool, Optional[str], Optional[Dict]]:
        """Main authentication method"""
        client_id = request.remote_addr
        
        # Check rate limiting first
        rate_ok, rate_error = self.check_rate_limit(client_id)
        if not rate_ok:
            return False, rate_error, None
        
        # Skip authentication if method is 'none'
        if self.auth_method == 'none':
            logger.warning("No authentication enabled - development mode")
            return True, None, {'user_id': 'anonymous', 'method': 'none'}
        
        # API Token authentication
        elif self.auth_method == 'api_token':
            auth_header = request.headers.get('Authorization', '')
            token_config = self.config['authentication']['api_token']
            
            if not auth_header.startswith(f"{token_config['token_prefix']} "):
                return False, "Missing or invalid Authorization header", None
            
            token = auth_header.split(' ', 1)[1]
            valid, error = self.validate_api_token(token)
            
            if valid:
                return True, None, {'user_id': self.tokens[token]['user_id'], 'method': 'api_token'}
            else:
                return False, error, None
        
        # AWS IAM Role authentication
        elif self.auth_method == 'iam_role':
            aws_access_key = request.headers.get('X-AWS-Access-Key-Id')
            aws_secret_key = request.headers.get('X-AWS-Secret-Access-Key')
            aws_session_token = request.headers.get('X-AWS-Session-Token')
            
            if not aws_access_key or not aws_secret_key:
                return False, "Missing AWS credentials in headers", None
            
            valid, error = self.validate_iam_role(aws_access_key, aws_secret_key, aws_session_token)
            
            if valid:
                return True, None, {'user_id': 'aws-role', 'method': 'iam_role'}
            else:
                return False, error, None
        
        # mTLS authentication (placeholder - requires SSL context)
        elif self.auth_method == 'mtls':
            # This would require SSL context and client certificate validation
            # Implementation depends on the web server (nginx, Apache, etc.)
            return False, "mTLS authentication not implemented in this context", None
        
        else:
            return False, f"Unknown authentication method: {self.auth_method}", None

def create_auth_decorator(auth_middleware: AuthMiddleware):
    """Create authentication decorator"""
    def require_auth(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            authenticated, error, user_info = auth_middleware.authenticate_request()
            
            if not authenticated:
                logger.warning(f"Authentication failed: {error}")
                return jsonify({
                    'error': 'Authentication failed',
                    'message': error,
                    'timestamp': datetime.utcnow().isoformat()
                }), 401
            
            # Store user info in Flask's g object
            g.user = user_info
            g.authenticated = True
            
            return f(*args, **kwargs)
        return decorated_function
    return require_auth

def setup_auth_middleware(app: Flask, config_path: str = None) -> AuthMiddleware:
    """Setup authentication middleware for Flask app"""
    auth = AuthMiddleware(config_path) if config_path else AuthMiddleware()
    
    # Create decorator
    require_auth = create_auth_decorator(auth)
    
    # Add to app context
    app.auth_middleware = auth
    app.require_auth = require_auth
    
    # Add token generation endpoint for development
    @app.route('/auth/token', methods=['POST'])
    def generate_token():
        if auth.auth_method != 'api_token':
            return jsonify({'error': 'Token generation not available for current auth method'}), 400
        
        user_id = request.json.get('user_id', 'deployer-ddf-mod-llm-models') if request.is_json else 'deployer-ddf-mod-llm-models'
        token = auth.generate_api_token(user_id)
        
        return jsonify({
            'token': token,
            'expires_in_hours': auth.config['authentication']['api_token']['expiration_hours'],
            'usage': f"Authorization: Bearer {token}"
        })
    
    # Add authentication status endpoint
    @app.route('/auth/status', methods=['GET'])
    @require_auth
    def auth_status():
        return jsonify({
            'authenticated': True,
            'user': g.user,
            'method': auth.auth_method,
            'timestamp': datetime.utcnow().isoformat()
        })
    
    logger.info("Authentication middleware setup complete")
    return auth

# Example usage
if __name__ == "__main__":
    # Test the authentication middleware
    app = Flask(__name__)
    auth = setup_auth_middleware(app)
    
    @app.route('/api/generate', methods=['POST'])
    @app.require_auth
    def generate_test():
        return jsonify({
            'message': 'Test generation endpoint',
            'user': g.user,
            'authenticated': g.authenticated
        })
    
    app.run(debug=True, port=5000) 