# AI Testing Agent - Test Suite

This directory contains tests for the AI Testing Agent infrastructure itself.

## Test Categories

### 1. Model Connectivity Tests
- **Purpose**: Verify LLM models are accessible and responding
- **Files**: `model-connectivity.test.py`
- **Tests**: Ollama API connectivity, model availability, response validation

### 2. Test Generation Quality Tests  
- **Purpose**: Validate the quality of AI-generated tests
- **Files**: `test-generation-quality.test.py`
- **Tests**: Generated test syntax, coverage patterns, mutation test effectiveness

### 3. Script Integration Tests
- **Purpose**: Test the AI testing scripts work correctly
- **Files**: `script-integration.test.py`
- **Tests**: local_ai_test.sh, lightweight-ai-test.sh, deployment scripts

### 4. Performance Tests
- **Purpose**: Monitor AI testing agent performance
- **Files**: `performance.test.py`
- **Tests**: Response times, memory usage, resource consumption

## Running Tests

```bash
# Run all AI testing agent self-tests
cd deployer-ddf-mod-llm-models
python -m pytest tests/

# Run specific test category
python -m pytest tests/model-connectivity.test.py
python -m pytest tests/test-generation-quality.test.py
```

## Test Data

- **Mock components**: `tests/fixtures/mock-components/`
- **Sample outputs**: `tests/fixtures/sample-outputs/`
- **Test configurations**: `tests/fixtures/configs/`

## Notes

These tests validate the AI Testing Agent infrastructure itself, not the main application. 
Main application tests remain in the project root `tests/` directory. 