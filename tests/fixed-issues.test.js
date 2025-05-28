import fetch from 'node-fetch';
import assert from 'assert';

// Test suite for fixed issues in DeployerDDF Module: Open Source LLM Models
describe('Fixed Issues Validation', () => {
  const BASE_URL = 'http://localhost:3000';

  // Test for API Docs page not being blank
  it('should load API docs page with content', async () => {
    const response = await fetch(`${BASE_URL}/api-docs/`);
    assert.strictEqual(response.status, 200, 'API docs page should return 200 OK');
    const text = await response.text();
    assert(text.length > 100, 'API docs page should contain significant content');
  });

  // Test for API Docs JSON availability
  it('should serve API docs JSON specification', async () => {
    const response = await fetch(`${BASE_URL}/api-docs.json`);
    assert.strictEqual(response.status, 200, 'API docs JSON should return 200 OK');
    const json = await response.json();
    assert(json.openapi, 'API docs JSON should contain OpenAPI specification');
    assert.strictEqual(json.info.title, 'AI Testing Agent API', 'API docs JSON should have correct title');
  });
}); 