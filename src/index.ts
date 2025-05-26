import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import { config } from 'dotenv';

// Load environment variables
config();

const app = express();
const PORT = process.env.PORT || 3000;

// Security middleware
app.use(helmet());
app.use(cors());
app.use(compression());
app.use(express.json());

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

// Test generation endpoint (placeholder)
app.post('/api/generate-tests', (req, res): void => {
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
app.use((err: Error, req: express.Request, res: express.Response, next: express.NextFunction): void => {
  console.error('Error:', err);
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