#!/usr/bin/env python3
"""
AI Test Generation Script - Phase 2 Enhanced
Generates intelligent tests using local LLM with pattern analysis and mutation testing integration.
"""

import os
import sys
import json
import glob
import subprocess
import requests
import time
import re
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass

@dataclass
class TestPattern:
    """Represents a discovered test pattern from existing tests"""
    pattern_type: str
    file_path: str
    imports: List[str]
    setup_code: str
    test_structure: str
    mocking_patterns: List[str]

@dataclass
class MutationResult:
    """Represents mutation testing results for quality analysis"""
    file_path: str
    mutation_score: float
    killed_mutants: int
    survived_mutants: int
    weak_spots: List[str]

class SmartTestGenerator:
    def __init__(self, ollama_url: str = "http://localhost:11434", model_tier: str = "default"):
        self.ollama_url = ollama_url
        self.model_tiers = {
            "fast": "deepseek-coder:1.3b",
            "default": "deepseek-coder:6.7b",  # Current default
            "quality": "deepseek-coder:33b",
            "context": "llama3.1:70b",
            "behemoth": "llama4-behemoth:288b",  # Future: When available
            "scout": "llama4-scout:17b",         # Future: 10M context
            "maverick": "llama4-maverick:17b"    # Future: High quality
        }
        self.model = self.model_tiers.get(model_tier, "deepseek-coder:6.7b")
        self.project_root = Path(__file__).parent.parent
        self.test_patterns = []
        self.mutation_results = []
        
    def analyze_existing_patterns(self) -> List[TestPattern]:
        """Analyze existing test files to discover patterns"""
        print("🔍 Analyzing existing test patterns...")
        
        test_files = glob.glob(str(self.project_root / "tests/**/*.test.{ts,tsx}"), recursive=True)
        patterns = []
        
        for test_file in test_files:
            try:
                with open(test_file, 'r') as f:
                    content = f.read()
                
                pattern = self._extract_pattern(test_file, content)
                if pattern:
                    patterns.append(pattern)
                    
            except Exception as e:
                print(f"⚠️  Error analyzing {test_file}: {e}")
                
        self.test_patterns = patterns
        print(f"✅ Found {len(patterns)} test patterns")
        return patterns
    
    def _extract_pattern(self, file_path: str, content: str) -> Optional[TestPattern]:
        """Extract test patterns from a file"""
        # Extract imports
        import_lines = re.findall(r'^import.*?;$', content, re.MULTILINE)
        
        # Extract setup patterns (beforeEach, beforeAll, etc.)
        setup_patterns = re.findall(r'(beforeEach|beforeAll|afterEach|afterAll)\([^}]+\}', content, re.DOTALL)
        
        # Extract mocking patterns
        mock_patterns = re.findall(r'(vi\.mock|jest\.mock|mockImplementation|mockReturnValue)[^;]+;', content)
        
        # Determine pattern type based on file content
        if 'render(' in content and '@testing-library/react' in content:
            pattern_type = 'react_component'
        elif 'describe(' in content and 'it(' in content:
            pattern_type = 'unit_test'
        elif 'test(' in content:
            pattern_type = 'simple_test'
        else:
            pattern_type = 'unknown'
            
        return TestPattern(
            pattern_type=pattern_type,
            file_path=file_path,
            imports=import_lines,
            setup_code='\n'.join(setup_patterns),
            test_structure=self._extract_test_structure(content),
            mocking_patterns=mock_patterns
        )
    
    def _extract_test_structure(self, content: str) -> str:
        """Extract the general structure of tests"""
        # Find describe blocks
        describe_blocks = re.findall(r'describe\([^{]+\{[^}]+\}', content, re.DOTALL)
        if describe_blocks:
            return describe_blocks[0][:200] + "..."
        
        # Find test blocks
        test_blocks = re.findall(r'(it|test)\([^{]+\{[^}]+\}', content, re.DOTALL)
        if test_blocks:
            return test_blocks[0][:200] + "..."
            
        return ""
    
    def run_mutation_testing(self, target_file: str) -> Optional[MutationResult]:
        """Run mutation testing on a specific file to identify weak spots"""
        print(f"🧬 Running mutation testing on {target_file}...")
        
        try:
            # Run Stryker on specific file
            cmd = [
                "npx", "stryker", "run",
                "--mutate", target_file,
                "--reporters", "json",
                "--logLevel", "error"
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, cwd=self.project_root)
            
            if result.returncode == 0:
                # Parse mutation results
                mutation_file = self.project_root / "coverage/mutation/mutation-report.json"
                if mutation_file.exists():
                    with open(mutation_file, 'r') as f:
                        data = json.load(f)
                    
                    return self._parse_mutation_results(target_file, data)
            else:
                print(f"⚠️  Mutation testing failed: {result.stderr}")
                
        except Exception as e:
            print(f"⚠️  Error running mutation testing: {e}")
            
        return None
    
    def _parse_mutation_results(self, file_path: str, data: Dict) -> MutationResult:
        """Parse mutation testing results"""
        files = data.get('files', {})
        file_data = files.get(file_path, {})
        
        mutation_score = file_data.get('mutationScore', 0)
        killed = len([m for m in file_data.get('mutants', []) if m.get('status') == 'Killed'])
        survived = len([m for m in file_data.get('mutants', []) if m.get('status') == 'Survived'])
        
        # Identify weak spots (survived mutants)
        weak_spots = []
        for mutant in file_data.get('mutants', []):
            if mutant.get('status') == 'Survived':
                weak_spots.append(f"Line {mutant.get('location', {}).get('start', {}).get('line', 'unknown')}: {mutant.get('mutatorName', 'unknown')}")
        
        return MutationResult(
            file_path=file_path,
            mutation_score=mutation_score,
            killed_mutants=killed,
            survived_mutants=survived,
            weak_spots=weak_spots
        )
    
    def generate_smart_prompt(self, file_path: str, file_content: str, mutation_result: Optional[MutationResult] = None) -> str:
        """Generate an intelligent prompt based on patterns and mutation results"""
        
        # Find the most relevant pattern
        relevant_pattern = self._find_relevant_pattern(file_path, file_content)
        
        base_prompt = f"""
Generate comprehensive Vitest tests for this TypeScript/React file following the project's established patterns.

FILE TO TEST: {file_path}
```typescript
{file_content[:2000]}...
```

PROJECT PATTERNS TO FOLLOW:
"""

        if relevant_pattern:
            base_prompt += f"""
- Pattern Type: {relevant_pattern.pattern_type}
- Common Imports: {', '.join(relevant_pattern.imports[:3])}
- Setup Pattern: {relevant_pattern.setup_code[:200]}
- Test Structure: {relevant_pattern.test_structure[:200]}
- Mocking Patterns: {', '.join(relevant_pattern.mocking_patterns[:2])}
"""

        if mutation_result:
            base_prompt += f"""

MUTATION TESTING INSIGHTS:
- Current Mutation Score: {mutation_result.mutation_score}%
- Weak Spots to Target: {', '.join(mutation_result.weak_spots[:3])}
- Focus on improving test coverage for survived mutants
"""

        base_prompt += """

REQUIREMENTS:
1. Follow the existing project patterns shown above
2. Use Vitest syntax (describe, it, expect, vi.mock)
3. Include proper TypeScript types
4. Mock external dependencies appropriately
5. Test edge cases and error conditions
6. Ensure tests are deterministic and reliable
7. Focus on areas identified by mutation testing (if provided)

GENERATE: Complete test file with imports, setup, and comprehensive test cases.
"""

        return base_prompt
    
    def _find_relevant_pattern(self, file_path: str, content: str) -> Optional[TestPattern]:
        """Find the most relevant test pattern for the given file"""
        if not self.test_patterns:
            return None
            
        # Determine file type
        if '.tsx' in file_path and ('export default' in content or 'function' in content):
            # React component
            react_patterns = [p for p in self.test_patterns if p.pattern_type == 'react_component']
            return react_patterns[0] if react_patterns else None
        elif '.ts' in file_path and 'export' in content:
            # Utility/service file
            unit_patterns = [p for p in self.test_patterns if p.pattern_type == 'unit_test']
            return unit_patterns[0] if unit_patterns else None
            
        # Default to first available pattern
        return self.test_patterns[0] if self.test_patterns else None
    
    def generate_test_with_ai(self, file_path: str, output_path: str) -> bool:
        """Generate test using AI with smart prompting"""
        print(f"🤖 Generating smart test for {file_path}...")
        
        try:
            # Read the source file
            with open(file_path, 'r') as f:
                content = f.read()
            
            # Run mutation testing if test already exists
            existing_test = output_path.replace('.test.', '.test.')
            mutation_result = None
            if os.path.exists(existing_test):
                mutation_result = self.run_mutation_testing(file_path)
            
            # Generate smart prompt
            prompt = self.generate_smart_prompt(file_path, content, mutation_result)
            
            # Call Ollama API
            response = requests.post(
                f"{self.ollama_url}/api/generate",
                json={
                    "model": self.model,
                    "prompt": prompt,
                    "stream": False,
                    "options": {
                        "temperature": 0.1,
                        "top_p": 0.9,
                        "num_predict": 2048
                    }
                },
                timeout=120
            )
            
            if response.status_code == 200:
                result = response.json()
                generated_test = result.get('response', '')
                
                # Clean up the generated test
                cleaned_test = self._clean_generated_test(generated_test)
                
                # Write to output file
                os.makedirs(os.path.dirname(output_path), exist_ok=True)
                with open(output_path, 'w') as f:
                    f.write(cleaned_test)
                
                print(f"✅ Generated test: {output_path}")
                return True
            else:
                print(f"❌ API error: {response.status_code}")
                return False
                
        except Exception as e:
            print(f"❌ Error generating test: {e}")
            return False
    
    def _clean_generated_test(self, test_content: str) -> str:
        """Clean up AI-generated test content"""
        # Remove markdown code blocks
        test_content = re.sub(r'```typescript\n?', '', test_content)
        test_content = re.sub(r'```\n?', '', test_content)
        
        # Ensure proper imports
        if 'import { describe, it, expect' not in test_content:
            test_content = "import { describe, it, expect, vi } from 'vitest';\n" + test_content
        
        return test_content.strip()
    
    def validate_generated_test(self, test_file: str) -> bool:
        """Validate that the generated test compiles and runs"""
        print(f"🔍 Validating {test_file}...")
        
        try:
            # Run TypeScript check
            result = subprocess.run(
                ["npx", "tsc", "--noEmit", test_file],
                capture_output=True,
                text=True,
                cwd=self.project_root
            )
            
            if result.returncode != 0:
                print(f"❌ TypeScript errors: {result.stderr}")
                return False
            
            # Run the test
            result = subprocess.run(
                ["npm", "run", "test", test_file],
                capture_output=True,
                text=True,
                cwd=self.project_root
            )
            
            if result.returncode == 0:
                print(f"✅ Test validation passed")
                return True
            else:
                print(f"❌ Test execution failed: {result.stderr}")
                return False
                
        except Exception as e:
            print(f"❌ Validation error: {e}")
            return False

def main():
    # Check for help first
    if len(sys.argv) < 2 or '--help' in sys.argv or '-h' in sys.argv:
        print("""
🚀 AI Testing Agent - Phase 2: Smart Test Generation

USAGE:
    python local_llm_testgen.py [--model=<tier>] <source_file> [output_file]

EXAMPLES:
    # Generate test for a React component (default model)
    python local_llm_testgen.py client/src/components/ui/Button.tsx
    
    # Use higher quality model
    python local_llm_testgen.py --model=quality client/src/components/ui/Button.tsx
    
    # Generate test with custom output path
    python local_llm_testgen.py client/src/utils/helpers.ts tests/unit/helpers.test.ts
    
    # Test a chart component (will analyze existing patterns)
    python local_llm_testgen.py client/src/components/dashboards/PredictiveRevenueChart/index.tsx

MODEL TIERS:
    fast     - deepseek-coder:1.3b (1.3GB) - Ultra-fast iteration
    default  - deepseek-coder:6.7b (3.8GB) - Balanced speed/quality ⭐
    quality  - deepseek-coder:33b (18GB)   - Higher quality analysis
    context  - llama3.1:70b (40GB)         - Million+ token context
    
    ✅ AVAILABLE NOW (Llama 4 Series):
    scout    - llama4-scout:17b (~10GB)      - 10M context, multimodal
    maverick - llama4-maverick:17b (~25GB)   - High-throughput, creative tasks
    
    🚀 COMING SOON:
    behemoth - llama4-behemoth:288b (~150GB) - Maximum quality (in training)

FEATURES:
    ✅ Smart pattern analysis from existing tests
    ✅ Mutation testing integration for quality insights
    ✅ TypeScript and React component support
    ✅ Automatic test validation
    ✅ Local LLM inference (DeepSeek-Coder)

REQUIREMENTS:
    - Ollama running with deepseek-coder:6.7b model
    - Source file must exist and be .ts or .tsx
        """)
        sys.exit(0)
    
    # Parse arguments
    model_tier = "default"
    source_file = None
    output_file = None
    
    for arg in sys.argv[1:]:
        if arg.startswith('--model='):
            model_tier = arg.split('=')[1]
        elif arg in ['--help', '-h']:
            continue  # Already handled above
        elif source_file is None:
            source_file = arg
        elif output_file is None:
            output_file = arg
    
    if not source_file:
        print("❌ Source file required")
        sys.exit(1)
    
    # Validate source file exists
    if not os.path.exists(source_file):
        print(f"❌ Source file not found: {source_file}")
        sys.exit(1)
    
    if not output_file:
        output_file = source_file.replace('.tsx', '.test.tsx').replace('.ts', '.test.ts')
    
    generator = SmartTestGenerator(model_tier=model_tier)
    print(f"🤖 Using model: {generator.model}")
    
    # Phase 2: Smart test generation
    print("🚀 AI Testing Agent - Phase 2: Smart Test Generation")
    
    # Analyze existing patterns
    generator.analyze_existing_patterns()
    
    # Generate test with AI
    success = generator.generate_test_with_ai(source_file, output_file)
    
    if success:
        # Validate the generated test
        if generator.validate_generated_test(output_file):
            print("🎉 Smart test generation completed successfully!")
        else:
            print("⚠️  Test generated but validation failed")
    else:
        print("❌ Test generation failed")
        sys.exit(1)

if __name__ == "__main__":
    main() 