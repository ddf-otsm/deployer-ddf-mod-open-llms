import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import { config } from 'dotenv';

// Load environment variables
config();

const app = express();
const PORT = process.env.PORT || 3000;

// Development mode - bypass authentication
const DEVELOPMENT_MODE = process.env.NODE_ENV === 'development' || process.env.AUTH_DISABLED === 'true';

// Security middleware
app.use(helmet());
app.use(cors());
app.use(compression());
app.use(express.json());

// Simple authentication middleware (can be bypassed in development)
const authMiddleware = (req: express.Request, res: express.Response, next: express.NextFunction) => {
  if (DEVELOPMENT_MODE) {
    // In development mode, bypass authentication
    console.log('🔓 Development mode: Authentication bypassed');
    return next();
  }
  
  // In production, check for API key or token
  const apiKey = req.headers['x-api-key'] || req.query.api_key;
  const authHeader = req.headers.authorization;
  
  if (!apiKey && !authHeader) {
    return res.status(401).json({ 
      error: 'Authentication required',
      message: 'Please provide an API key or authorization token'
    });
  }
  
  // Simple API key validation (replace with proper validation)
  if (apiKey && apiKey === process.env.API_KEY) {
    return next();
  }
  
  // Bearer token validation (placeholder)
  if (authHeader && authHeader.startsWith('Bearer ')) {
    // In a real implementation, validate the JWT token here
    console.log('🔑 Token authentication (placeholder)');
    return next();
  }
  
  return res.status(401).json({ 
    error: 'Invalid authentication',
    message: 'Invalid API key or token'
  });
};

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'deployer-ddf-mod-llm-models',
    version: '1.0.0'
  });
});

// API routes
app.get('/api/status', (req, res) => {
  res.json({
    service: 'AI Testing Agent',
    status: 'running',
    models: ['deepseek-coder:1.3b', 'deepseek-coder:6.7b'],
    features: ['test-generation', 'mutation-testing', 'self-healing']
  });
});

// Test generation endpoint (placeholder) - protected by auth
app.post('/api/generate-tests', authMiddleware, (req, res): void => {
  const { code, language = 'typescript' } = req.body;
  
  if (!code) {
    res.status(400).json({ error: 'Code is required' });
    return;
  }
  
  // Placeholder response - in production this would call Ollama
  res.json({
    success: true,
    tests: [
      {
        type: 'unit',
        framework: 'vitest',
        code: `// Generated test for ${language} code\ndescribe('Component', () => {\n  it('should render correctly', () => {\n    // Test implementation\n  });\n});`
      }
    ],
    metadata: {
      language,
      model: 'deepseek-coder:1.3b',
      timestamp: new Date().toISOString()
    }
  });
});

// Error handling middleware
app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error('Error:', err);
  
  // Handle JSON parsing errors
  if (err.type === 'entity.parse.failed') {
    res.status(400).json({
      error: 'Invalid JSON',
      message: 'Request body contains invalid JSON'
    });
    return;
  }
  
  // Handle other client errors
  if (err.status && err.status >= 400 && err.status < 500) {
    res.status(err.status).json({
      error: 'Client error',
      message: err.message || 'Bad request'
    });
    return;
  }
  
  // Handle server errors
  res.status(500).json({
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong'
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Not found',
    path: req.path
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 AI Testing Agent running on port ${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/health`);
  console.log(`🔧 API status: http://localhost:${PORT}/api/status`);
});

export default app; 