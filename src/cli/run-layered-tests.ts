#!/usr/bin/env node

import { LayeredTestingFramework } from '../testing/layered-testing-framework.js';
import { program } from 'commander';
import { join } from 'path';

// CLI Configuration
program
  .name('run-layered-tests')
  .description('Run layered testing framework for LLM models')
  .version('1.0.0');

program
  .option('-e, --environment <env>', 'Environment to test (dev, staging, prod)', 'dev')
  .option('-l, --layer <layer>', 'Specific layer to test (1-4)', '')
  .option('-c, --config <path>', 'Path to configuration file', './config/llm-models.json')
  .option('-o, --output <path>', 'Output file for results', '')
  .option('--progressive', 'Run progressive testing from Layer 1 to 4', false)
  .option('--dry-run', 'Show what would be tested without executing', false)
  .option('--verbose', 'Enable verbose logging', false);

async function main() {
  program.parse();
  const options = program.opts();

  console.log('🎯 DeployerDDF Layered Testing Framework');
  console.log('═'.repeat(50));
  console.log(`Environment: ${options.environment}`);
  console.log(`Configuration: ${options.config}`);
  
  if (options.dryRun) {
    console.log('🔍 DRY RUN MODE - No actual tests will be executed\n');
  }

  try {
    // Initialize the testing framework
    const framework = new LayeredTestingFramework(options.config);

    if (options.dryRun) {
      await runDryRun(framework, options);
      return;
    }

    if (options.progressive) {
      // Run progressive testing from Layer 1 to Layer 4 (including Llama 4)
      console.log('🚀 Starting Progressive Testing (Layer 1 → Layer 4)\n');
      await framework.runProgressiveTests(options.environment);
    } else if (options.layer) {
      // Run specific layer
      const layer = parseInt(options.layer);
      if (layer < 1 || layer > 4) {
        console.error('❌ Layer must be between 1 and 4');
        process.exit(1);
      }
      
      console.log(`🚀 Starting Layer ${layer} Testing\n`);
      await framework.runLayerTests(layer, options.environment);
    } else {
      // Default: run all layers
      console.log('🚀 Starting All Layers Testing\n');
      await framework.runProgressiveTests(options.environment);
    }

    // Export results if output path specified
    if (options.output) {
      const outputPath = options.output.startsWith('/') 
        ? options.output 
        : join(process.cwd(), options.output);
      framework.exportResults(outputPath);
    }

    console.log('\n✅ Testing completed successfully!');

  } catch (error) {
    console.error('❌ Error running tests:', error);
    process.exit(1);
  }
}

async function runDryRun(framework: LayeredTestingFramework, options: any) {
  console.log('📋 DRY RUN - Testing Plan:\n');

  // Load configuration to show what would be tested
  const configPath = options.config;
  const { readFileSync } = await import('fs');
  const config = JSON.parse(readFileSync(configPath, 'utf8'));

  if (options.progressive || !options.layer) {
    // Show all layers
    for (let layer = 1; layer <= 4; layer++) {
      showLayerPlan(config, layer, options.environment);
    }
  } else {
    // Show specific layer
    const layer = parseInt(options.layer);
    showLayerPlan(config, layer, options.environment);
  }

  console.log('\n📊 Summary:');
  const totalModels = Object.keys(config.models).length;
  const enabledModels = config.environments[options.environment]?.enabled_models || [];
  console.log(`   Total Models: ${totalModels}`);
  console.log(`   Enabled in ${options.environment}: ${enabledModels.length}`);
  console.log(`   Budget: $${config.environments[options.environment]?.cost_budget || 0}/month`);
  
  console.log('\n🔍 To execute tests, run without --dry-run flag');
}

function showLayerPlan(config: any, layer: number, environment: string) {
  const layerConfig = config.testing_layers[`layer_${layer}`];
  if (!layerConfig) {
    console.log(`⚠️ Layer ${layer}: No configuration found`);
    return;
  }

  console.log(`📊 Layer ${layer}: ${layerConfig.name}`);
  console.log(`   Description: ${layerConfig.description}`);
  console.log(`   Complexity: ${layerConfig.complexity}`);
  
  // Find models for this layer
  const layerModels = Object.entries(config.models)
    .filter(([_, model]: [string, any]) => model.testing.layer === layer)
    .map(([id, model]: [string, any]) => ({ id, ...model }));

  if (layerModels.length === 0) {
    console.log(`   ⚠️ No models configured for this layer`);
  } else {
    console.log(`   Models (${layerModels.length}):`);
    layerModels.forEach((model: any) => {
      const isEnabled = config.environments[environment]?.enabled_models?.includes(model.id);
      const status = isEnabled ? '✅' : '❌';
      console.log(`     ${status} ${model.name} (${model.parameters})`);
      console.log(`        Standard Questions: ${model.testing.standard_questions.length}`);
      console.log(`        Role Tests: ${model.testing.role_tests.length}`);
    });
  }
  console.log('');
}

// Handle uncaught errors
process.on('unhandledRejection', (error) => {
  console.error('❌ Unhandled error:', error);
  process.exit(1);
});

process.on('SIGINT', () => {
  console.log('\n⏹️ Testing interrupted by user');
  process.exit(0);
});

// Run the CLI
if (import.meta.url === `file://${process.argv[1]}`) {
  main();
} 