import { readFileSync } from 'fs';
import { join } from 'path';
import axios from 'axios';

// Types for the testing framework
interface ModelConfig {
  name: string;
  provider: string;
  type: string;
  version: string;
  parameters: string;
  deployment: {
    container_image: string;
    memory_requirements: string;
    cpu_requirements: string;
    gpu_requirements: string;
    storage_requirements: string;
  };
  endpoints: {
    inference: string;
    health: string;
    metrics?: string;
  };
  testing: {
    layer: number;
    standard_questions: string[];
    role_tests: string[];
  };
}

interface TestingLayer {
  name: string;
  description: string;
  models: string[];
  pre_prompt_template: string;
  complexity: string;
  expected_capabilities: string[];
}

interface TestResult {
  model_id: string;
  layer: number;
  test_type: 'standard_question' | 'role_test';
  question: string;
  role?: string | undefined;
  response: string;
  evaluation: {
    accuracy: number;
    relevance: number;
    completeness: number;
    clarity: number;
    overall_score: number;
  };
  execution_time: number;
  timestamp: string;
}

interface LayeredTestConfig {
  version: string;
  metadata: {
    description: string;
    created: string;
    lastModified: string;
    maintainer: string;
  };
  deployer_ddf: any;
  models: Record<string, ModelConfig>;
  testing_layers: Record<string, TestingLayer>;
  environments: Record<string, any>;
}

export class LayeredTestingFramework {
  private config: LayeredTestConfig;
  private prePrompts: Map<string, string> = new Map();
  private testResults: TestResult[] = [];

  constructor(configPath: string = './config/llm-models.json') {
    this.config = JSON.parse(readFileSync(configPath, 'utf8'));
    this.loadPrePrompts();
  }

  /**
   * Load pre-prompt templates for different testing layers
   */
  private loadPrePrompts(): void {
    const prePromptDir = './config/pre-prompts';
    
    try {
      const basicPrompt = readFileSync(join(prePromptDir, 'basic_assistant.md'), 'utf8');
      this.prePrompts.set('basic_assistant', basicPrompt);

      const advancedPrompt = readFileSync(join(prePromptDir, 'advanced_assistant.md'), 'utf8');
      this.prePrompts.set('advanced_assistant', advancedPrompt);

      const enterprisePrompt = readFileSync(join(prePromptDir, 'enterprise_assistant.md'), 'utf8');
      this.prePrompts.set('enterprise_assistant', enterprisePrompt);

      console.log('✅ Pre-prompt templates loaded successfully');
    } catch (error) {
      console.error('❌ Error loading pre-prompt templates:', error);
      throw error;
    }
  }

  /**
   * Get models for a specific testing layer
   */
  private getModelsForLayer(layer: number): ModelConfig[] {
    return Object.entries(this.config.models)
      .filter(([_, model]) => model.testing.layer === layer)
      .map(([_, model]) => model);
  }

  /**
   * Get testing layer configuration
   */
  private getLayerConfig(layer: number): TestingLayer | undefined {
    return this.config.testing_layers[`layer_${layer}`];
  }

  /**
   * Prepare model with pre-prompt for role-based testing
   */
  private async prepareModelWithPrePrompt(
    modelEndpoint: string,
    layerConfig: TestingLayer,
    role: string
  ): Promise<void> {
    const prePrompt = this.prePrompts.get(layerConfig.pre_prompt_template);
    if (!prePrompt) {
      throw new Error(`Pre-prompt template not found: ${layerConfig.pre_prompt_template}`);
    }

    const roleSpecificPrompt = `${prePrompt}\n\n### Current Role: ${role}\n\nYou are now operating in ${role} mode. Apply the guidelines and capabilities specific to this role as outlined in the pre-prompt template.`;

    try {
      await axios.post(`${modelEndpoint}/api/generate`, {
        model: 'current',
        prompt: roleSpecificPrompt,
        stream: false,
        options: {
          temperature: 0.1,
          top_p: 0.9
        }
      });
      console.log(`✅ Model prepared with pre-prompt for role: ${role}`);
    } catch (error) {
      console.error(`❌ Error preparing model with pre-prompt:`, error);
      throw error;
    }
  }

  /**
   * Execute a test question against a model
   */
  private async executeTest(
    modelEndpoint: string,
    modelId: string,
    layer: number,
    question: string,
    testType: 'standard_question' | 'role_test',
    role?: string
  ): Promise<TestResult> {
    const startTime = Date.now();

    try {
      const response = await axios.post(`${modelEndpoint}/api/generate`, {
        model: 'current',
        prompt: question,
        stream: false,
        options: {
          temperature: 0.1,
          top_p: 0.9,
          max_tokens: 2000
        }
      });

      const executionTime = Date.now() - startTime;
      const responseText = response.data.response || '';

             // Basic evaluation (in a real implementation, this would be more sophisticated)
       const evaluation = this.evaluateResponse(question, responseText, layer);

       const testResult: TestResult = {
         model_id: modelId,
         layer,
         test_type: testType,
         question,
         role: role || undefined,
         response: responseText,
         evaluation,
         execution_time: executionTime,
         timestamp: new Date().toISOString()
       };

      this.testResults.push(testResult);
      return testResult;

    } catch (error) {
      console.error(`❌ Error executing test for model ${modelId}:`, error);
      throw error;
    }
  }

     /**
    * Evaluate model response (simplified evaluation)
    */
   private evaluateResponse(question: string, response: string, layer: number): {
     accuracy: number;
     relevance: number;
     completeness: number;
     clarity: number;
     overall_score: number;
   } {
    // This is a simplified evaluation. In a real implementation, 
    // you would use more sophisticated evaluation metrics
    const hasResponse = response.length > 0;
    const firstWord = question.toLowerCase().split(' ')[0];
    const isRelevant = firstWord ? response.toLowerCase().includes(firstWord) : false;
    const hasStructure = response.includes('\n') || response.includes('```');
    const hasDetail = response.length > 100;

    const baseScore = hasResponse ? 0.5 : 0;
    const relevanceScore = isRelevant ? 0.3 : 0;
    const structureScore = hasStructure ? 0.1 : 0;
    const detailScore = hasDetail ? 0.1 : 0;

    const overallScore = Math.min(1.0, baseScore + relevanceScore + structureScore + detailScore);

    return {
      accuracy: overallScore,
      relevance: isRelevant ? 0.8 : 0.4,
      completeness: hasDetail ? 0.8 : 0.5,
      clarity: hasStructure ? 0.8 : 0.6,
      overall_score: overallScore
    };
  }

  /**
   * Check if model is healthy and ready for testing
   */
  private async checkModelHealth(modelEndpoint: string): Promise<boolean> {
    try {
      const response = await axios.get(`${modelEndpoint}/api/tags`, {
        timeout: 5000
      });
      return response.status === 200;
    } catch (error) {
      console.error(`❌ Model health check failed:`, error);
      return false;
    }
  }

  /**
   * Run tests for a specific layer
   */
  public async runLayerTests(layer: number, environment: string = 'dev'): Promise<TestResult[]> {
    console.log(`🚀 Starting Layer ${layer} tests in ${environment} environment`);

    const layerConfig = this.getLayerConfig(layer);
    if (!layerConfig) {
      throw new Error(`Layer ${layer} configuration not found`);
    }

    const models = this.getModelsForLayer(layer);
    if (models.length === 0) {
      console.log(`⚠️ No models found for Layer ${layer}`);
      return [];
    }

    const layerResults: TestResult[] = [];

    for (const model of models) {
      console.log(`\n📊 Testing model: ${model.name} (${model.parameters})`);

      // For this example, we'll assume the model is running locally
      // In a real deployment, you'd get the endpoint from the deployment config
      const modelEndpoint = `http://localhost:11434`;

      // Check model health
      const isHealthy = await this.checkModelHealth(modelEndpoint);
      if (!isHealthy) {
        console.log(`❌ Model ${model.name} is not healthy, skipping tests`);
        continue;
      }

      // Run standard questions
      console.log(`📝 Running standard questions for ${model.name}`);
      for (const question of model.testing.standard_questions) {
        try {
          const result = await this.executeTest(
            modelEndpoint,
            Object.keys(this.config.models).find(key => this.config.models[key] === model) || '',
            layer,
            question,
            'standard_question'
          );
          layerResults.push(result);
          console.log(`✅ Standard question completed: ${question.substring(0, 50)}...`);
        } catch (error) {
          console.error(`❌ Standard question failed: ${question.substring(0, 50)}...`);
        }
      }

      // Run role-based tests
      console.log(`🎭 Running role-based tests for ${model.name}`);
      for (const role of model.testing.role_tests) {
        try {
          // Prepare model with pre-prompt for this role
          await this.prepareModelWithPrePrompt(modelEndpoint, layerConfig, role);

          // Use the first standard question as a role test
          const testQuestion = `As a ${role}, ${model.testing.standard_questions[0]}`;
          
          const result = await this.executeTest(
            modelEndpoint,
            Object.keys(this.config.models).find(key => this.config.models[key] === model) || '',
            layer,
            testQuestion,
            'role_test',
            role
          );
          layerResults.push(result);
          console.log(`✅ Role test completed: ${role}`);
        } catch (error) {
          console.error(`❌ Role test failed: ${role}`);
        }
      }
    }

    console.log(`\n📈 Layer ${layer} testing completed. Results: ${layerResults.length} tests`);
    return layerResults;
  }

  /**
   * Run progressive testing from Layer 1 to Layer 4 (including Llama 4)
   */
  public async runProgressiveTests(environment: string = 'dev'): Promise<void> {
    console.log('🎯 Starting Progressive Layered Testing Framework');
    console.log('Testing models from basic assistants to enterprise-level Llama 4\n');

    const allResults: TestResult[] = [];

    // Test each layer progressively
    for (let layer = 1; layer <= 4; layer++) {
      try {
        const layerResults = await this.runLayerTests(layer, environment);
        allResults.push(...layerResults);

        // Generate layer summary
        this.generateLayerSummary(layer, layerResults);

        // Wait between layers to allow for analysis
        if (layer < 4) {
          console.log(`⏳ Waiting 30 seconds before next layer...\n`);
          await new Promise(resolve => setTimeout(resolve, 30000));
        }
      } catch (error) {
        console.error(`❌ Error in Layer ${layer} testing:`, error);
      }
    }

    // Generate final comprehensive report
    this.generateComprehensiveReport(allResults);
  }

  /**
   * Generate summary for a specific layer
   */
  private generateLayerSummary(layer: number, results: TestResult[]): void {
    if (results.length === 0) {
      console.log(`📊 Layer ${layer} Summary: No tests completed\n`);
      return;
    }

    const avgScore = results.reduce((sum, r) => sum + r.evaluation.overall_score, 0) / results.length;
    const avgTime = results.reduce((sum, r) => sum + r.execution_time, 0) / results.length;

    console.log(`\n📊 Layer ${layer} Summary:`);
    console.log(`   Tests Completed: ${results.length}`);
    console.log(`   Average Score: ${(avgScore * 100).toFixed(1)}%`);
    console.log(`   Average Response Time: ${avgTime.toFixed(0)}ms`);
    console.log(`   Models Tested: ${new Set(results.map(r => r.model_id)).size}`);
    console.log('─'.repeat(50));
  }

  /**
   * Generate comprehensive test report
   */
  private generateComprehensiveReport(results: TestResult[]): void {
    console.log('\n🎯 COMPREHENSIVE LAYERED TESTING REPORT');
    console.log('═'.repeat(60));

    // Overall statistics
    const totalTests = results.length;
    const overallAvgScore = results.reduce((sum, r) => sum + r.evaluation.overall_score, 0) / totalTests;
    const overallAvgTime = results.reduce((sum, r) => sum + r.execution_time, 0) / totalTests;

    console.log(`\n📈 Overall Statistics:`);
    console.log(`   Total Tests: ${totalTests}`);
    console.log(`   Overall Average Score: ${(overallAvgScore * 100).toFixed(1)}%`);
    console.log(`   Overall Average Time: ${overallAvgTime.toFixed(0)}ms`);

    // Layer-by-layer breakdown
    for (let layer = 1; layer <= 4; layer++) {
      const layerResults = results.filter(r => r.layer === layer);
      if (layerResults.length > 0) {
        const layerAvgScore = layerResults.reduce((sum, r) => sum + r.evaluation.overall_score, 0) / layerResults.length;
        console.log(`\n   Layer ${layer}: ${layerResults.length} tests, ${(layerAvgScore * 100).toFixed(1)}% avg score`);
      }
    }

    // Model performance ranking
    const modelPerformance = new Map<string, { score: number; tests: number }>();
    results.forEach(result => {
      const current = modelPerformance.get(result.model_id) || { score: 0, tests: 0 };
      current.score += result.evaluation.overall_score;
      current.tests += 1;
      modelPerformance.set(result.model_id, current);
    });

    console.log(`\n🏆 Model Performance Ranking:`);
    Array.from(modelPerformance.entries())
      .map(([model, data]) => ({ model, avgScore: data.score / data.tests, tests: data.tests }))
      .sort((a, b) => b.avgScore - a.avgScore)
      .forEach((entry, index) => {
        console.log(`   ${index + 1}. ${entry.model}: ${(entry.avgScore * 100).toFixed(1)}% (${entry.tests} tests)`);
      });

    console.log('\n✅ Progressive testing completed successfully!');
    console.log('Results saved for further analysis and model comparison.');
  }

  /**
   * Get test results
   */
  public getTestResults(): TestResult[] {
    return this.testResults;
  }

  /**
   * Export results to JSON
   */
  public exportResults(filePath: string): void {
    const fs = require('fs');
    const exportData = {
      timestamp: new Date().toISOString(),
      framework_version: this.config.version,
      total_tests: this.testResults.length,
      results: this.testResults
    };
    
    fs.writeFileSync(filePath, JSON.stringify(exportData, null, 2));
    console.log(`📁 Results exported to: ${filePath}`);
  }
} 