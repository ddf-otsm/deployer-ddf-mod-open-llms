#!/usr/bin/env python3
"""
Phase 1: Basic Model Functionality Test
Tests models with deterministic prompts to verify basic functionality.
"""

import requests
import json
import time
import sys
from typing import Dict, Any

class BasicModelTester:
    def __init__(self, ollama_url: str = "http://localhost:11434"):
        self.ollama_url = ollama_url
        self.test_prompts = {
            "general": "Tell me who was the president of USA in 2000",
            "programming": "Write a simple JavaScript function that adds two numbers and returns the result",
            "code_reasoning": "Explain what this code does: const arr = [1,2,3]; const doubled = arr.map(x => x * 2); console.log(doubled);",
            "debugging": "Find the bug in this code: function factorial(n) { if (n <= 1) return 1; return n * factorial(n); }",
            "algorithm": "Write a function to find the maximum number in an array without using Math.max",
            "typescript": "Create a TypeScript interface for a User with name (string), age (number), and optional email (string)"
        }
        
    def test_model(self, model_name: str) -> Dict[str, Any]:
        """Test a model with the appropriate prompt based on model type"""
        print(f"🧪 Testing model: {model_name}")
        
        # Choose prompt based on model type and add variety
        if "deepseek-coder" in model_name.lower():
            # Rotate through different programming prompts for variety
            programming_prompts = ["programming", "code_reasoning", "debugging", "algorithm", "typescript"]
            import random
            random.seed(hash(model_name))  # Deterministic but varied
            prompt_type = random.choice(programming_prompts)
            prompt = self.test_prompts[prompt_type]
        else:
            prompt = self.test_prompts["general"]
            prompt_type = "general"
        
        print(f"📝 Using {prompt_type} prompt")
        
        start_time = time.time()
        
        try:
            response = requests.post(
                f"{self.ollama_url}/api/generate",
                json={
                    "model": model_name,
                    "prompt": prompt,
                    "stream": False,
                    "options": {
                        "temperature": 0.1,  # Deterministic
                        "num_predict": 200
                    }
                },
                timeout=60
            )
            
            end_time = time.time()
            duration = end_time - start_time
            
            if response.status_code == 200:
                data = response.json()
                response_text = data.get('response', '')
                
                # Validate response
                is_valid = self._validate_response(response_text, prompt_type)
                
                return {
                    "model": model_name,
                    "status": "success",
                    "duration": duration,
                    "response": response_text,
                    "is_valid": is_valid,
                    "response_length": len(response_text),
                    "prompt_type": prompt_type
                }
            else:
                return {
                    "model": model_name,
                    "status": "error",
                    "error": f"HTTP {response.status_code}",
                    "duration": duration
                }
                
        except Exception as e:
            return {
                "model": model_name,
                "status": "error",
                "error": str(e),
                "duration": time.time() - start_time
            }
    
    def _validate_response(self, response: str, prompt_type: str) -> bool:
        """Validate if response contains expected information based on prompt type"""
        response_lower = response.lower()
        
        if prompt_type in ["programming", "code_reasoning", "debugging", "algorithm", "typescript"]:
            # Check for programming-related keywords based on prompt type
            if prompt_type == "programming":
                keywords = ['function', 'return', 'add', 'number', 'javascript', '{', '}']
                min_keywords = 3
            elif prompt_type == "code_reasoning":
                keywords = ['array', 'map', 'function', 'doubled', 'console', 'log', 'multiply']
                min_keywords = 2
            elif prompt_type == "debugging":
                keywords = ['bug', 'error', 'factorial', 'infinite', 'recursion', 'missing', 'n-1']
                min_keywords = 2
            elif prompt_type == "algorithm":
                keywords = ['function', 'array', 'maximum', 'loop', 'for', 'if', 'return']
                min_keywords = 3
            elif prompt_type == "typescript":
                keywords = ['interface', 'user', 'string', 'number', 'optional', 'type']
                min_keywords = 3
            
            found_keywords = sum(1 for keyword in keywords if keyword in response_lower)
            # Should contain relevant keywords and be substantial
            return len(response) > 30 and found_keywords >= min_keywords
        else:
            # Check for historical keywords
            keywords = ['bush', 'clinton', 'president', '2000', 'george', 'bill']
            found_keywords = sum(1 for keyword in keywords if keyword in response_lower)
            # Response should be substantial and contain relevant information
            return len(response) > 50 and found_keywords >= 2
    
    def run_test_suite(self, models: list) -> Dict[str, Any]:
        """Run tests on multiple models"""
        results = {}
        
        print("🚀 Starting Phase 1: Basic Model Functionality Tests")
        print("📝 Using model-specific prompts:")
        print(f"   General: '{self.test_prompts['general']}'")
        print(f"   Programming: '{self.test_prompts['programming']}'")
        print("=" * 60)
        
        for model in models:
            result = self.test_model(model)
            results[model] = result
            
            # Print immediate results
            if result["status"] == "success":
                status_icon = "✅" if result["is_valid"] else "⚠️"
                print(f"{status_icon} {model}: {result['duration']:.2f}s - {'Valid' if result['is_valid'] else 'Invalid'}")
            else:
                print(f"❌ {model}: {result['error']}")
        
        return results

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Phase 1: Basic Model Functionality Test")
    parser.add_argument("--model", help="Specific model to test")
    parser.add_argument("--all", action="store_true", help="Test all available models")
    
    args = parser.parse_args()
    
    tester = BasicModelTester()
    
    if args.model:
        result = tester.test_model(args.model)
        print(json.dumps(result, indent=2))
    elif args.all:
        # Get available models
        try:
            response = requests.get(f"{tester.ollama_url}/api/tags")
            if response.status_code == 200:
                models = [model["name"] for model in response.json()["models"]]
                results = tester.run_test_suite(models)
                print("\n📊 Final Results:")
                print(json.dumps(results, indent=2))
            else:
                print("❌ Could not fetch available models")
        except Exception as e:
            print(f"❌ Error: {e}")
    else:
        # Default test with known models
        default_models = ["deepseek-coder:6.7b", "llama3.2:1b"]
        results = tester.run_test_suite(default_models) 