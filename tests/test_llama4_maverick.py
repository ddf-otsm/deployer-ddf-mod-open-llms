#!/usr/bin/env python3
"""
Llama 4 Maverick Testing Script
Accelerated implementation for meta-llama/Llama-4-Maverick-17B-128E-Instruct
"""

import asyncio
import json
import time
import sys
import os
from typing import Dict, Any

# Add the scripts directory to the path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from providers.huggingface_provider import HuggingFaceProvider, HuggingFaceConfig

class Llama4MaverickTester:
    def __init__(self):
        self.model_name = "meta-llama/Llama-4-Maverick-17B-128E-Instruct"
        self.provider = None
        
        # Enhanced prompts for Llama 4 Maverick testing
        self.test_prompts = {
            "enterprise_test_generation": """
            You are an expert software testing engineer. Analyze this React TypeScript component and generate a comprehensive test suite.

            REQUIREMENTS:
            1. Unit tests for all functions and methods
            2. Integration tests for component interactions  
            3. Edge cases and error scenarios
            4. Performance tests for rendering optimization
            5. Accessibility tests for WCAG compliance
            6. Mock strategies for external dependencies

            COMPONENT CODE:
            ```typescript
            import React, { useState, useEffect, useCallback } from 'react';
            import { User, ApiError } from '../types';
            import { fetchUser, updateUser } from '../api/userService';

            interface UserProfileProps {
              userId: number;
              onUserUpdate?: (user: User) => void;
              readOnly?: boolean;
            }

            const UserProfile: React.FC<UserProfileProps> = ({ 
              userId, 
              onUserUpdate, 
              readOnly = false 
            }) => {
              const [user, setUser] = useState<User | null>(null);
              const [loading, setLoading] = useState(true);
              const [error, setError] = useState<string | null>(null);
              const [editing, setEditing] = useState(false);

              const loadUser = useCallback(async () => {
                try {
                  setLoading(true);
                  setError(null);
                  const userData = await fetchUser(userId);
                  setUser(userData);
                } catch (err) {
                  const apiError = err as ApiError;
                  setError(apiError.message || 'Failed to load user');
                } finally {
                  setLoading(false);
                }
              }, [userId]);

              useEffect(() => {
                loadUser();
              }, [loadUser]);

              const handleSave = async (updatedUser: Partial<User>) => {
                try {
                  setLoading(true);
                  const savedUser = await updateUser(userId, updatedUser);
                  setUser(savedUser);
                  setEditing(false);
                  onUserUpdate?.(savedUser);
                } catch (err) {
                  const apiError = err as ApiError;
                  setError(apiError.message || 'Failed to update user');
                } finally {
                  setLoading(false);
                }
              };

              if (loading) return <div role="status">Loading user...</div>;
              if (error) return <div role="alert">Error: {error}</div>;
              if (!user) return <div>User not found</div>;

              return (
                <div className="user-profile" data-testid="user-profile">
                  <h2>{user.name}</h2>
                  <p>{user.email}</p>
                  <p>Role: {user.role}</p>
                  {!readOnly && (
                    <button 
                      onClick={() => setEditing(!editing)}
                      disabled={loading}
                    >
                      {editing ? 'Cancel' : 'Edit'}
                    </button>
                  )}
                  {editing && (
                    <UserEditForm 
                      user={user} 
                      onSave={handleSave}
                      onCancel={() => setEditing(false)}
                    />
                  )}
                </div>
              );
            };

            export default UserProfile;
            ```

            Generate a complete, production-ready test suite with detailed explanations for each test case.
            """,
            
            "architectural_analysis": """
            You are a senior software architect. Analyze this codebase structure and provide comprehensive recommendations.

            ANALYSIS REQUIREMENTS:
            1. Architecture assessment and design patterns evaluation
            2. Test strategy for the entire application
            3. Risk analysis and priority testing areas
            4. Performance optimization opportunities
            5. Maintainability and scalability improvements
            6. Security considerations and testing approaches

            CODEBASE STRUCTURE:
            ```
            src/
            ├── components/
            │   ├── ui/
            │   │   ├── Button.tsx
            │   │   ├── Input.tsx
            │   │   └── Modal.tsx
            │   ├── forms/
            │   │   ├── UserForm.tsx
            │   │   └── LoginForm.tsx
            │   └── layouts/
            │       ├── Header.tsx
            │       └── Sidebar.tsx
            ├── hooks/
            │   ├── useAuth.ts
            │   ├── useApi.ts
            │   └── useLocalStorage.ts
            ├── services/
            │   ├── api.ts
            │   ├── auth.ts
            │   └── storage.ts
            ├── types/
            │   ├── user.ts
            │   ├── api.ts
            │   └── auth.ts
            ├── utils/
            │   ├── validation.ts
            │   ├── formatting.ts
            │   └── constants.ts
            └── pages/
                ├── Dashboard.tsx
                ├── Profile.tsx
                └── Settings.tsx
            ```

            Provide a comprehensive architectural analysis with actionable recommendations.
            """,
            
            "complex_debugging": """
            You are an expert debugging specialist. Analyze this complex React application issue and provide a systematic debugging approach.

            PROBLEM DESCRIPTION:
            Users report that the application becomes unresponsive after performing multiple rapid actions. The issue seems to be related to state management and memory leaks.

            SYMPTOMS:
            - UI freezes after 10-15 rapid clicks
            - Memory usage continuously increases
            - Console shows warnings about memory leaks
            - Performance degrades over time

            CODE SAMPLE:
            ```typescript
            const Dashboard: React.FC = () => {
              const [data, setData] = useState<any[]>([]);
              const [filters, setFilters] = useState<FilterState>({});
              const [loading, setLoading] = useState(false);

              useEffect(() => {
                const interval = setInterval(() => {
                  fetchData().then(setData);
                }, 1000);
                return () => clearInterval(interval);
              }, []);

              useEffect(() => {
                const subscription = eventBus.subscribe('dataUpdate', (newData) => {
                  setData(prev => [...prev, ...newData]);
                });
                return () => subscription.unsubscribe();
              }, []);

              const handleFilterChange = useCallback((newFilters: FilterState) => {
                setFilters(newFilters);
                fetchFilteredData(newFilters).then(setData);
              }, []);

              return (
                <div>
                  <FilterPanel onFilterChange={handleFilterChange} />
                  <DataGrid data={data} loading={loading} />
                </div>
              );
            };
            ```

            Provide a systematic debugging approach, identify potential issues, and suggest comprehensive testing strategies.
            """
        }
    
    async def initialize_provider(self) -> bool:
        """Initialize Hugging Face provider for Llama 4 Maverick"""
        try:
            config = HuggingFaceConfig(
                hf_token=os.getenv('HF_TOKEN'),
                cache_dir='./models/huggingface',
                device_map='auto',
                torch_dtype='float16'
            )
            
            self.provider = HuggingFaceProvider(config)
            
            # Check if provider is available
            if not await self.provider.is_available():
                print("❌ Hugging Face provider not available. Check HF_TOKEN environment variable.")
                return False
            
            print("✅ Hugging Face provider initialized")
            return True
            
        except Exception as e:
            print(f"❌ Failed to initialize provider: {e}")
            return False
    
    async def load_maverick_model(self) -> bool:
        """Load Llama 4 Maverick model"""
        if not self.provider:
            print("❌ Provider not initialized")
            return False
        
        print(f"🚀 Loading {self.model_name}...")
        print("⚠️  This may take several minutes for first-time download...")
        
        success = await self.provider.load_model(self.model_name)
        if success:
            print("✅ Llama 4 Maverick loaded successfully")
            
            # Display memory usage
            memory_info = self.provider.get_memory_usage()
            if memory_info.get("gpu_available"):
                print(f"📊 GPU Memory: {memory_info['allocated_memory']:.2f}GB allocated")
        
        return success
    
    async def test_prompt(self, prompt_type: str, max_tokens: int = 500) -> Dict[str, Any]:
        """Test Llama 4 Maverick with a specific prompt type"""
        if not self.provider or not self.provider.is_loaded:
            raise RuntimeError("Model not loaded")
        
        prompt = self.test_prompts.get(prompt_type)
        if not prompt:
            raise ValueError(f"Unknown prompt type: {prompt_type}")
        
        print(f"🧪 Testing {prompt_type} with Llama 4 Maverick...")
        
        start_time = time.time()
        
        try:
            response = await self.provider.generate(
                prompt,
                options={
                    "max_tokens": max_tokens,
                    "temperature": 0.1,
                    "top_p": 0.9,
                    "repetition_penalty": 1.1
                }
            )
            
            # Validate response quality
            is_valid = self._validate_response(response.text, prompt_type)
            
            return {
                "prompt_type": prompt_type,
                "model": self.model_name,
                "status": "success",
                "duration": response.duration,
                "response": response.text,
                "is_valid": is_valid,
                "response_length": len(response.text),
                "token_usage": {
                    "prompt_tokens": response.usage.prompt_tokens,
                    "completion_tokens": response.usage.completion_tokens,
                    "total_tokens": response.usage.total_tokens
                },
                "metadata": response.metadata
            }
            
        except Exception as e:
            return {
                "prompt_type": prompt_type,
                "model": self.model_name,
                "status": "error",
                "error": str(e),
                "duration": time.time() - start_time
            }
    
    def _validate_response(self, response: str, prompt_type: str) -> bool:
        """Validate response quality based on prompt type"""
        response_lower = response.lower()
        
        if prompt_type == "enterprise_test_generation":
            keywords = ['test', 'describe', 'it', 'expect', 'mock', 'render', 'component', 'async']
            min_keywords = 5
            min_length = 500
        elif prompt_type == "architectural_analysis":
            keywords = ['architecture', 'pattern', 'component', 'structure', 'recommendation', 'scalability']
            min_keywords = 4
            min_length = 300
        elif prompt_type == "complex_debugging":
            keywords = ['debug', 'issue', 'memory', 'leak', 'performance', 'useeffect', 'state']
            min_keywords = 4
            min_length = 300
        else:
            return len(response) > 100
        
        found_keywords = sum(1 for keyword in keywords if keyword in response_lower)
        return len(response) >= min_length and found_keywords >= min_keywords
    
    async def run_comprehensive_test(self) -> Dict[str, Any]:
        """Run comprehensive test suite for Llama 4 Maverick"""
        print("🚀 Starting Llama 4 Maverick Comprehensive Test Suite")
        print("=" * 70)
        
        results = {
            "model": self.model_name,
            "test_timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
            "tests": {},
            "summary": {}
        }
        
        # Test all prompt types
        for prompt_type in self.test_prompts.keys():
            print(f"\n📝 Testing: {prompt_type}")
            result = await self.test_prompt(prompt_type, max_tokens=800)
            results["tests"][prompt_type] = result
            
            if result["status"] == "success":
                status_icon = "✅" if result["is_valid"] else "⚠️"
                print(f"{status_icon} {prompt_type}: {result['duration']:.2f}s - {'Valid' if result['is_valid'] else 'Invalid'}")
                print(f"   Tokens: {result['token_usage']['total_tokens']} | Length: {result['response_length']} chars")
            else:
                print(f"❌ {prompt_type}: {result['error']}")
        
        # Generate summary
        successful_tests = [r for r in results["tests"].values() if r["status"] == "success"]
        valid_tests = [r for r in successful_tests if r["is_valid"]]
        
        results["summary"] = {
            "total_tests": len(results["tests"]),
            "successful_tests": len(successful_tests),
            "valid_tests": len(valid_tests),
            "success_rate": len(successful_tests) / len(results["tests"]) * 100,
            "validity_rate": len(valid_tests) / len(successful_tests) * 100 if successful_tests else 0,
            "average_duration": sum(r["duration"] for r in successful_tests) / len(successful_tests) if successful_tests else 0,
            "total_tokens": sum(r["token_usage"]["total_tokens"] for r in successful_tests)
        }
        
        return results
    
    async def cleanup(self):
        """Clean up resources"""
        if self.provider:
            await self.provider.unload_model()

async def main():
    """Main test execution"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Llama 4 Maverick Testing")
    parser.add_argument("--prompt", choices=["enterprise_test_generation", "architectural_analysis", "complex_debugging"], 
                       help="Test specific prompt type")
    parser.add_argument("--comprehensive", action="store_true", help="Run comprehensive test suite")
    
    args = parser.parse_args()
    
    tester = Llama4MaverickTester()
    
    try:
        # Initialize provider
        if not await tester.initialize_provider():
            sys.exit(1)
        
        # Load model
        if not await tester.load_maverick_model():
            sys.exit(1)
        
        # Run tests
        if args.prompt:
            result = await tester.test_prompt(args.prompt)
            print(json.dumps(result, indent=2))
        elif args.comprehensive:
            results = await tester.run_comprehensive_test()
            
            print("\n" + "=" * 70)
            print("📊 COMPREHENSIVE TEST RESULTS")
            print("=" * 70)
            print(f"Success Rate: {results['summary']['success_rate']:.1f}%")
            print(f"Validity Rate: {results['summary']['validity_rate']:.1f}%")
            print(f"Average Duration: {results['summary']['average_duration']:.2f}s")
            print(f"Total Tokens: {results['summary']['total_tokens']}")
            
            # Save results
            with open(f"llama4_maverick_test_results_{int(time.time())}.json", "w") as f:
                json.dump(results, f, indent=2)
            print("\n💾 Results saved to file")
        else:
            # Default: run enterprise test generation
            result = await tester.test_prompt("enterprise_test_generation")
            print(json.dumps(result, indent=2))
    
    except KeyboardInterrupt:
        print("\n⚠️  Test interrupted by user")
    except Exception as e:
        print(f"❌ Test failed: {e}")
    finally:
        await tester.cleanup()

if __name__ == "__main__":
    asyncio.run(main()) 