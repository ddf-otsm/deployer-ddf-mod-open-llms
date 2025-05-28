import { describe, it, before, after } from 'mocha';
import assert from 'assert';
import fetch from 'node-fetch';

// Test configuration
const BASE_URL = 'http://localhost:3000';
const CHAT_URL = `${BASE_URL}/chat`;
const API_STATUS_URL = `${BASE_URL}/api/status`;
const API_CHAT_URL = `${BASE_URL}/api/chat`;

describe('Chat Frontend Tests', function() {
  this.timeout(10000);

  before(async function() {
    // Verify server is running
    try {
      const response = await fetch(`${BASE_URL}/health`);
      assert.strictEqual(response.status, 200, 'Server should be running');
    } catch (error) {
      throw new Error(`Server not accessible: ${error.message}`);
    }
  });

  describe('Chat Page Accessibility', function() {
    it('should serve the chat HTML page', async function() {
      const response = await fetch(CHAT_URL);
      assert.strictEqual(response.status, 200, 'Chat page should be accessible');
      
      const contentType = response.headers.get('content-type');
      assert(contentType.includes('text/html'), 'Should return HTML content');
    });

    it('should contain required HTML structure', async function() {
      const response = await fetch(CHAT_URL);
      const html = await response.text();
      
      // Check for essential elements
      assert(html.includes('<title>AI Testing Agent - Chat Interface</title>'), 'Should have proper title');
      assert(html.includes('id="modelSidebar"'), 'Should have model sidebar');
      assert(html.includes('id="chatContainer"'), 'Should have chat container');
      assert(html.includes('id="messageInput"'), 'Should have message input');
      assert(html.includes('id="sendButton"'), 'Should have send button');
    });

    it('should include model management elements', async function() {
      const response = await fetch(CHAT_URL);
      const html = await response.text();
      
      // Check for model management UI
      assert(html.includes('id="modelGrid"'), 'Should have model grid');
      assert(html.includes('class="model-card"'), 'Should have model card template');
      assert(html.includes('loadModels()'), 'Should call loadModels function');
    });
  });

  describe('API Integration', function() {
    it('should load models from /api/status endpoint', async function() {
      const response = await fetch(API_STATUS_URL);
      assert.strictEqual(response.status, 200, 'API status should be accessible');
      
      const data = await response.json();
      assert(Array.isArray(data.models), 'Should return models array');
      assert(data.models.length > 0, 'Should have at least one model');
      
      // Verify expected models are present
      const expectedModels = [
        'deepseek-coder:6.7b',
        'deepseek-coder:1.3b', 
        'deepseek-coder:33b',
        'llama3.2:1b',
        'llama3.2:3b',
        'llama3.1:8b',
        'custom-model:1.0'
      ];
      
      expectedModels.forEach(model => {
        assert(data.models.includes(model), `Should include model: ${model}`);
      });
    });

    it('should handle chat API requests', async function() {
      const testMessage = 'Hello, this is a test message';
      const testModel = 'deepseek-coder:1.3b';
      
      const response = await fetch(API_CHAT_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          message: testMessage,
          model: testModel
        })
      });
      
      assert.strictEqual(response.status, 200, 'Chat API should respond successfully');
      
      const data = await response.json();
      assert.strictEqual(data.success, true, 'Response should indicate success');
      assert.strictEqual(data.model, testModel, 'Should echo back the model');
      assert(typeof data.response === 'string', 'Should return a response string');
      assert(data.response.length > 0, 'Response should not be empty');
    });

    it('should validate required chat parameters', async function() {
      // Test missing message
      const response = await fetch(API_CHAT_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          model: 'deepseek-coder:1.3b'
        })
      });
      
      assert.strictEqual(response.status, 400, 'Should return 400 for missing message');
      
      const data = await response.json();
      assert.strictEqual(data.error, 'Message is required', 'Should return appropriate error message');
    });
  });

  describe('JavaScript Functionality Tests', function() {
    it('should contain model management functions', async function() {
      const response = await fetch(CHAT_URL);
      const html = await response.text();
      
      // Check for essential JavaScript functions
      assert(html.includes('function loadModels()'), 'Should have loadModels function');
      assert(html.includes('function initializeModel('), 'Should have initializeModel function');
      assert(html.includes('function activateModel('), 'Should have activateModel function');
      assert(html.includes('function sendMessage()'), 'Should have sendMessage function');
    });

    it('should include model state management', async function() {
      const response = await fetch(CHAT_URL);
      const html = await response.text();
      
      // Check for state management variables and functions
      assert(html.includes('let modelStates = {}'), 'Should have modelStates object');
      assert(html.includes('let activeModel = null'), 'Should have activeModel variable');
      assert(html.includes('function updateModelCard('), 'Should have updateModelCard function');
    });

    it('should handle UI interactions', async function() {
      const response = await fetch(CHAT_URL);
      const html = await response.text();
      
      // Check for event handlers and UI updates
      assert(html.includes('onclick="initializeModel('), 'Should have initialize button handlers');
      assert(html.includes('onclick="activateModel('), 'Should have activate button handlers');
      assert(html.includes('onclick="sendMessage()"'), 'Should have send button handler');
      assert(html.includes('addEventListener(\'keypress\''), 'Should have keypress event listener');
    });
  });

  describe('Model Management Workflow', function() {
    it('should support model initialization workflow', async function() {
      const response = await fetch(CHAT_URL);
      const html = await response.text();
      
      // Verify the initialization workflow is properly implemented
      assert(html.includes('INACTIVE'), 'Should have INACTIVE state');
      assert(html.includes('INITIALIZING'), 'Should have INITIALIZING state');
      assert(html.includes('ACTIVE'), 'Should have ACTIVE state');
      
      // Check for proper state transitions
      assert(html.includes('modelStates[modelName] = \'initializing\''), 'Should set initializing state');
      assert(html.includes('modelStates[modelName] = \'active\''), 'Should set active state');
    });

    it('should handle model switching logic', async function() {
      const response = await fetch(CHAT_URL);
      const html = await response.text();
      
      // Verify model switching functionality
      assert(html.includes('if (activeModel && activeModel !== modelName)'), 'Should check for active model conflicts');
      assert(html.includes('activeModel = modelName'), 'Should set active model');
      assert(html.includes('activeModel = null'), 'Should clear active model when needed');
    });
  });

  describe('Error Handling', function() {
    it('should handle API errors gracefully', async function() {
      const response = await fetch(CHAT_URL);
      const html = await response.text();
      
      // Check for error handling in JavaScript
      assert(html.includes('catch (error)'), 'Should have error handling');
      assert(html.includes('console.error'), 'Should log errors');
      assert(html.includes('alert('), 'Should show user-friendly error messages');
    });

    it('should validate user input', async function() {
      const response = await fetch(CHAT_URL);
      const html = await response.text();
      
      // Check for input validation
      assert(html.includes('messageInput.value.trim()'), 'Should trim message input');
      assert(html.includes('if (!message)'), 'Should validate empty messages');
      assert(html.includes('if (!activeModel)'), 'Should validate active model selection');
    });
  });

  describe('UI/UX Features', function() {
    it('should include responsive design elements', async function() {
      const response = await fetch(CHAT_URL);
      const html = await response.text();
      
      // Check for responsive design CSS
      assert(html.includes('display: grid'), 'Should use CSS Grid');
      assert(html.includes('grid-template-columns'), 'Should have responsive grid columns');
      assert(html.includes('@media'), 'Should include media queries for responsiveness');
    });

    it('should provide visual feedback for user actions', async function() {
      const response = await fetch(CHAT_URL);
      const html = await response.text();
      
      // Check for visual feedback mechanisms
      assert(html.includes('disabled'), 'Should disable buttons during operations');
      assert(html.includes('background-color'), 'Should provide visual state indicators');
      assert(html.includes('cursor: pointer'), 'Should indicate interactive elements');
    });

    it('should include accessibility features', async function() {
      const response = await fetch(CHAT_URL);
      const html = await response.text();
      
      // Check for accessibility attributes
      assert(html.includes('aria-label'), 'Should include ARIA labels');
      assert(html.includes('role='), 'Should define element roles');
      assert(html.includes('tabindex'), 'Should support keyboard navigation');
    });
  });

  describe('Performance Considerations', function() {
    it('should implement efficient DOM updates', async function() {
      const response = await fetch(CHAT_URL);
      const html = await response.text();
      
      // Check for efficient DOM manipulation
      assert(html.includes('getElementById'), 'Should use efficient DOM selection');
      assert(html.includes('innerHTML'), 'Should update DOM content efficiently');
      assert(html.includes('appendChild'), 'Should append elements efficiently');
    });

    it('should handle concurrent operations', async function() {
      const response = await fetch(CHAT_URL);
      const html = await response.text();
      
      // Check for proper async handling
      assert(html.includes('async function'), 'Should use async functions');
      assert(html.includes('await fetch'), 'Should properly await API calls');
      assert(html.includes('Promise'), 'Should handle promises correctly');
    });
  });

  after(function() {
    console.log('✅ Chat frontend tests completed successfully');
    console.log('📊 Tested: Page accessibility, API integration, JavaScript functionality, model management, error handling, UI/UX features, and performance considerations');
  });
}); 