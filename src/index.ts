import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import { config } from 'dotenv';
import swaggerUi from 'swagger-ui-express';
import swaggerJsdoc from 'swagger-jsdoc';
import configLoader from './config.js';

// Load environment variables
config();

const app = express();
const PORT = configLoader.getPort();
const HOST = configLoader.getHost();

// Development mode - bypass authentication
const DEVELOPMENT_MODE = process.env.NODE_ENV === 'development' || !configLoader.isAuthEnabled();

// Swagger configuration
const swaggerOptions = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'AI Testing Agent API',
      version: '1.0.0',
      description: 'DeployerDDF Module: Open Source LLM Models - AI testing agent using Ollama for intelligent test generation and validation',
      contact: {
        name: 'DeployerDDF Team',
        url: 'https://github.com/ddf-otsm/deployer-ddf-mod-open-llms'
      }
    },
    servers: [
      {
        url: `${process.env.NODE_ENV === 'production' ? 'https' : 'http'}://${HOST}:${PORT}`,
        description: process.env.NODE_ENV === 'production' ? 'Production server' : 'Development server'
      }
    ],
    components: {
      securitySchemes: {
        ApiKeyAuth: {
          type: 'apiKey',
          in: 'header',
          name: 'X-API-Key'
        },
        BearerAuth: {
          type: 'http',
          scheme: 'bearer'
        }
      }
    }
  },
  apis: ['./src/index.ts'], // Path to the API docs
};

const swaggerSpec = swaggerJsdoc(swaggerOptions);

// Security middleware
app.use(helmet());
app.use(cors());
app.use(compression());
app.use(express.json());

// Swagger UI
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec, {
  customCss: '.swagger-ui .topbar { display: none }',
  customSiteTitle: 'AI Testing Agent API'
}));

// Root route - redirect to API documentation
app.get('/', (req, res) => {
  res.redirect('/api-docs');
});

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

/**
 * @swagger
 * /health:
 *   get:
 *     summary: Health check endpoint
 *     description: Returns the health status of the AI Testing Agent service
 *     tags: [Health]
 *     responses:
 *       200:
 *         description: Service is healthy
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 status:
 *                   type: string
 *                   example: healthy
 *                 timestamp:
 *                   type: string
 *                   format: date-time
 *                 service:
 *                   type: string
 *                   example: deployer-ddf-mod-llm-models
 *                 version:
 *                   type: string
 *                   example: 1.0.0
 */
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'deployer-ddf-mod-llm-models',
    version: '1.0.0'
  });
});

/**
 * @swagger
 * /api/status:
 *   get:
 *     summary: Get API status
 *     description: Returns the current status of the AI Testing Agent API
 *     tags: [API]
 *     responses:
 *       200:
 *         description: API status information
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 service:
 *                   type: string
 *                   example: AI Testing Agent
 *                 status:
 *                   type: string
 *                   example: running
 *                 models:
 *                   type: array
 *                   items:
 *                     type: string
 *                   example: ["deepseek-coder:1.3b", "deepseek-coder:6.7b"]
 *                 features:
 *                   type: array
 *                   items:
 *                     type: string
 *                   example: ["test-generation", "mutation-testing", "self-healing"]
 */
app.get('/api/status', (req, res) => {
  res.json({
    service: 'AI Testing Agent',
    status: 'running',
    models: ['deepseek-coder:1.3b', 'deepseek-coder:6.7b'],
    features: ['test-generation', 'mutation-testing', 'self-healing']
  });
});

/**
 * @swagger
 * /api/generate-tests:
 *   post:
 *     summary: Generate tests for code
 *     description: Generate unit tests for the provided code using AI models
 *     tags: [AI Testing]
 *     security:
 *       - ApiKeyAuth: []
 *       - BearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - code
 *             properties:
 *               code:
 *                 type: string
 *                 description: The source code to generate tests for
 *                 example: "function add(a, b) { return a + b; }"
 *               language:
 *                 type: string
 *                 description: Programming language of the code
 *                 default: typescript
 *                 example: typescript
 *     responses:
 *       200:
 *         description: Tests generated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 tests:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       type:
 *                         type: string
 *                         example: unit
 *                       framework:
 *                         type: string
 *                         example: vitest
 *                       code:
 *                         type: string
 *                         example: "describe('Component', () => { it('should render correctly', () => { // Test implementation }); });"
 *                 metadata:
 *                   type: object
 *                   properties:
 *                     language:
 *                       type: string
 *                       example: typescript
 *                     model:
 *                       type: string
 *                       example: deepseek-coder:1.3b
 *                     timestamp:
 *                       type: string
 *                       format: date-time
 *       400:
 *         description: Bad request - code is required
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Code is required
 *       401:
 *         description: Unauthorized - authentication required
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Authentication required
 */
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
app.listen(PORT, HOST, () => {
  const protocol = process.env.NODE_ENV === 'production' ? 'https' : 'http';
  console.log(`🚀 AI Testing Agent running on ${protocol}://${HOST}:${PORT}`);
  console.log(`📊 Health check: ${protocol}://${HOST}:${PORT}/health`);
  console.log(`🔧 API status: ${protocol}://${HOST}:${PORT}/api/status`);
  console.log(`📚 API docs: ${protocol}://${HOST}:${PORT}/api-docs`);
});

export default app; 