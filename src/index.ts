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
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'"], // Allow inline scripts for chat interface
      scriptSrcAttr: ["'unsafe-inline'"], // Allow inline event handlers
      styleSrc: ["'self'", "'unsafe-inline'"], // Allow inline styles
      imgSrc: ["'self'", "data:"],
      connectSrc: ["'self'"]
    }
  }
}));
app.use(cors());
app.use(compression());
app.use(express.json());

// Swagger UI
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(null, {
  customCss: '.swagger-ui .topbar { display: none }',
  customSiteTitle: 'AI Testing Agent API',
  swaggerUrl: '/api-docs.json'
}));

// Serve the Swagger specification JSON
app.get('/api-docs.json', (req, res) => {
  res.json(swaggerSpec);
});

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
    models: [
      'deepseek-coder:6.7b', 
      'deepseek-coder:1.3b',
      'deepseek-coder:33b',
      'llama3.2:1b',
      'llama3.2:3b',
      'llama3.1:8b',
      'custom-model:1.0'
    ],
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

/**
 * @swagger
 * /api/llama4-maverick:
 *   post:
 *     summary: Generate response using Llama 4 Maverick
 *     description: Generate AI responses using Meta's Llama 4 Maverick 17B MoE model with 400B total parameters
 *     tags: [Llama 4 Maverick]
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
 *               - prompt
 *             properties:
 *               prompt:
 *                 type: string
 *                 description: The input prompt for Llama 4 Maverick
 *                 example: "Generate a comprehensive test suite for a React component"
 *               max_tokens:
 *                 type: integer
 *                 description: Maximum number of tokens to generate
 *                 default: 500
 *                 minimum: 1
 *                 maximum: 2000
 *               temperature:
 *                 type: number
 *                 description: Sampling temperature (0.0 to 1.0)
 *                 default: 0.1
 *                 minimum: 0.0
 *                 maximum: 1.0
 *               top_p:
 *                 type: number
 *                 description: Nucleus sampling parameter
 *                 default: 0.9
 *                 minimum: 0.0
 *                 maximum: 1.0
 *     responses:
 *       200:
 *         description: Response generated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 model:
 *                   type: string
 *                   example: "meta-llama/Llama-4-Maverick-17B-128E-Instruct"
 *                 response:
 *                   type: string
 *                   example: "Here's a comprehensive test suite for your React component..."
 *                 metadata:
 *                   type: object
 *                   properties:
 *                     active_params:
 *                       type: string
 *                       example: "17B"
 *                     total_params:
 *                       type: string
 *                       example: "400B"
 *                     experts:
 *                       type: integer
 *                       example: 128
 *                     architecture:
 *                       type: string
 *                       example: "MoE"
 *                     duration:
 *                       type: number
 *                       example: 2.5
 *                     token_usage:
 *                       type: object
 *                       properties:
 *                         prompt_tokens:
 *                           type: integer
 *                           example: 25
 *                         completion_tokens:
 *                           type: integer
 *                           example: 150
 *                         total_tokens:
 *                           type: integer
 *                           example: 175
 *                 timestamp:
 *                   type: string
 *                   format: date-time
 *       400:
 *         description: Bad request - prompt is required
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Prompt is required
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
 *       500:
 *         description: Internal server error - model unavailable
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Llama 4 Maverick model unavailable
 */
app.post('/api/llama4-maverick', authMiddleware, async (req, res): Promise<void> => {
  const { prompt, max_tokens = 500, temperature = 0.1, top_p = 0.9 } = req.body;
  
  if (!prompt) {
    res.status(400).json({ error: 'Prompt is required' });
    return;
  }
  
  // Validate parameters
  if (max_tokens < 1 || max_tokens > 2000) {
    res.status(400).json({ error: 'max_tokens must be between 1 and 2000' });
    return;
  }
  
  if (temperature < 0 || temperature > 1) {
    res.status(400).json({ error: 'temperature must be between 0.0 and 1.0' });
    return;
  }
  
  if (top_p < 0 || top_p > 1) {
    res.status(400).json({ error: 'top_p must be between 0.0 and 1.0' });
    return;
  }
  
  try {
    const startTime = Date.now();
    
    // In production, this would call the actual Llama 4 Maverick model
    // For now, we'll simulate the response structure
    const simulatedResponse = generateLlama4MaverickResponse(prompt, max_tokens);
    
    const duration = (Date.now() - startTime) / 1000;
    
    res.json({
      success: true,
      model: "meta-llama/Llama-4-Maverick-17B-128E-Instruct",
      response: simulatedResponse.text,
      metadata: {
        active_params: "17B",
        total_params: "400B",
        experts: 128,
        architecture: "MoE",
        duration: duration,
        token_usage: {
          prompt_tokens: Math.ceil(prompt.length / 4), // Rough estimation
          completion_tokens: Math.ceil(simulatedResponse.text.length / 4),
          total_tokens: Math.ceil((prompt.length + simulatedResponse.text.length) / 4)
        }
      },
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('Llama 4 Maverick error:', error);
    res.status(500).json({ 
      error: 'Llama 4 Maverick model unavailable',
      message: 'The model is currently unavailable. Please try again later.'
    });
  }
});

/**
 * @swagger
 * /api/chat:
 *   post:
 *     summary: Chat with AI models
 *     description: Send messages to AI models and receive responses for local testing
 *     tags: [Chat]
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
 *               - message
 *             properties:
 *               message:
 *                 type: string
 *                 description: The message to send to the AI model
 *                 example: "Hello, how can you help me with coding?"
 *               model:
 *                 type: string
 *                 description: The model to use for the chat
 *                 default: deepseek-coder:1.3b
 *                 example: deepseek-coder:1.3b
 *     responses:
 *       200:
 *         description: Chat response received successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 response:
 *                   type: string
 *                   example: "I'm happy to help with your coding questions! What specific problem are you working on?"
 *                 model:
 *                   type: string
 *                   example: deepseek-coder:1.3b
 *                 timestamp:
 *                   type: string
 *                   format: date-time
 *       400:
 *         description: Bad request - message is required
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: Message is required
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
app.post('/api/chat', authMiddleware, (req, res) => {
  const { message, model = 'deepseek-coder:1.3b' } = req.body;
  
  if (!message) {
    res.status(400).json({ error: 'Message is required' });
    return;
  }
  
  // Placeholder response - in production this would call the actual model
  const response = `This is a placeholder response from ${model}. In a full implementation, I would process your message: "${message}" and provide a relevant answer.`;
  
  res.json({
    success: true,
    response,
    model,
    timestamp: new Date().toISOString()
  });
});

// Serve the chat interface
app.get('/chat', (req, res) => {
  res.sendFile('chat.html', { root: '.' });
});

// Helper function to generate Llama 4 Maverick-style responses
function generateLlama4MaverickResponse(prompt: string, maxTokens: number): { text: string } {
  // This is a placeholder implementation
  // In production, this would interface with the actual Llama 4 Maverick model
  
  const responses = {
    test: `// Comprehensive Test Suite Generated by Llama 4 Maverick
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { vi } from 'vitest';
import { UserProfile } from './UserProfile';

describe('UserProfile Component', () => {
  const mockUser = {
    id: 1,
    name: 'John Doe',
    email: 'john@example.com',
    role: 'admin'
  };

  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('Rendering', () => {
    it('should render user information correctly', () => {
      render(<UserProfile userId={1} />);
      
      expect(screen.getByText('John Doe')).toBeInTheDocument();
      expect(screen.getByText('john@example.com')).toBeInTheDocument();
      expect(screen.getByText('Role: admin')).toBeInTheDocument();
    });

    it('should show loading state initially', () => {
      render(<UserProfile userId={1} />);
      expect(screen.getByRole('status')).toHaveTextContent('Loading user...');
    });
  });

  describe('Error Handling', () => {
    it('should display error message when user fetch fails', async () => {
      // Mock API failure
      vi.mocked(fetchUser).mockRejectedValue(new Error('Network error'));
      
      render(<UserProfile userId={1} />);
      
      await waitFor(() => {
        expect(screen.getByRole('alert')).toHaveTextContent('Error: Network error');
      });
    });
  });

  describe('Accessibility', () => {
    it('should have proper ARIA labels', () => {
      render(<UserProfile userId={1} />);
      
      expect(screen.getByTestId('user-profile')).toBeInTheDocument();
      expect(screen.getByRole('status')).toBeInTheDocument();
    });
  });
});`,
    
    architecture: `# Comprehensive Architecture Analysis by Llama 4 Maverick

## Executive Summary
The codebase demonstrates a well-structured React application with clear separation of concerns. However, there are several areas for improvement in testing strategy, performance optimization, and maintainability.

## Architecture Assessment

### Strengths
1. **Component Organization**: Clear separation between UI components, forms, and layouts
2. **Custom Hooks**: Good abstraction of business logic into reusable hooks
3. **Service Layer**: Proper separation of API calls and business logic
4. **Type Safety**: Comprehensive TypeScript usage

### Areas for Improvement
1. **State Management**: Consider implementing Redux or Zustand for complex state
2. **Error Boundaries**: Add React error boundaries for better error handling
3. **Performance**: Implement React.memo and useMemo for optimization
4. **Testing**: Increase test coverage, especially for integration tests

## Recommended Test Strategy

### Unit Testing (70% coverage target)
- All utility functions in \`utils/\`
- Custom hooks with comprehensive scenarios
- Individual component rendering and behavior

### Integration Testing (20% coverage target)
- Form submission workflows
- API integration with mock services
- User authentication flows

### End-to-End Testing (10% coverage target)
- Critical user journeys
- Cross-browser compatibility
- Performance benchmarks

## Security Considerations
1. **Input Validation**: Implement comprehensive validation for all user inputs
2. **Authentication**: Ensure proper token management and refresh logic
3. **Authorization**: Implement role-based access control
4. **XSS Prevention**: Sanitize all user-generated content

## Performance Optimization Opportunities
1. **Code Splitting**: Implement route-based code splitting
2. **Lazy Loading**: Lazy load non-critical components
3. **Caching**: Implement proper caching strategies for API calls
4. **Bundle Analysis**: Regular bundle size monitoring and optimization`,

    debug: `# Complex Debugging Analysis by Llama 4 Maverick

## Problem Analysis
The reported symptoms indicate a classic memory leak combined with inefficient state management patterns. Let me break down the systematic debugging approach:

## Root Cause Analysis

### 1. Memory Leak Sources
\`\`\`typescript
// ISSUE: Interval not properly cleaned up
useEffect(() => {
  const interval = setInterval(() => {
    fetchData().then(setData); // Creates new promises continuously
  }, 1000);
  return () => clearInterval(interval); // ✅ This is correct
}, []); // ✅ Empty dependency array is correct
\`\`\`

### 2. State Accumulation Problem
\`\`\`typescript
// ISSUE: Continuously appending data without cleanup
useEffect(() => {
  const subscription = eventBus.subscribe('dataUpdate', (newData) => {
    setData(prev => [...prev, ...newData]); // ❌ Unbounded growth
  });
  return () => subscription.unsubscribe();
}, []);
\`\`\`

## Debugging Strategy

### Phase 1: Memory Profiling
1. **Chrome DevTools Memory Tab**
   - Take heap snapshots before and after rapid interactions
   - Look for detached DOM nodes and growing object counts
   - Monitor event listener counts

2. **React DevTools Profiler**
   - Record performance during problematic interactions
   - Identify components with excessive re-renders
   - Check for unnecessary effect executions

### Phase 2: Code Analysis
\`\`\`typescript
// Fixed implementation
const Dashboard: React.FC = () => {
  const [data, setData] = useState<any[]>([]);
  const [filters, setFilters] = useState<FilterState>({});
  const [loading, setLoading] = useState(false);
  
  // Fix 1: Add data size limit
  const MAX_DATA_SIZE = 1000;
  
  useEffect(() => {
    const interval = setInterval(async () => {
      try {
        const newData = await fetchData();
        setData(prev => {
          const combined = [...prev, ...newData];
          // Limit data size to prevent memory issues
          return combined.slice(-MAX_DATA_SIZE);
        });
      } catch (error) {
        console.error('Data fetch failed:', error);
      }
    }, 1000);
    
    return () => clearInterval(interval);
  }, []);
  
  // Fix 2: Debounce filter changes
  const debouncedFilterChange = useCallback(
    debounce(async (newFilters: FilterState) => {
      setLoading(true);
      try {
        const filteredData = await fetchFilteredData(newFilters);
        setData(filteredData); // Replace instead of append
      } finally {
        setLoading(false);
      }
    }, 300),
    []
  );
  
  return (
    <div>
      <FilterPanel onFilterChange={debouncedFilterChange} />
      <DataGrid data={data} loading={loading} />
    </div>
  );
};
\`\`\`

## Testing Strategy for Memory Leaks
1. **Automated Memory Tests**: Use Puppeteer to simulate rapid interactions
2. **Performance Budgets**: Set memory usage thresholds in CI/CD
3. **Load Testing**: Test with large datasets to identify breaking points`
  };
  
  // Determine response type based on prompt content
  let responseText = '';
  const promptLower = prompt.toLowerCase();
  
  if (promptLower.includes('test') || promptLower.includes('component')) {
    responseText = responses.test;
  } else if (promptLower.includes('architecture') || promptLower.includes('analysis')) {
    responseText = responses.architecture;
  } else if (promptLower.includes('debug') || promptLower.includes('memory') || promptLower.includes('performance')) {
    responseText = responses.debug;
  } else {
    // Generic response
    responseText = `# Response Generated by Llama 4 Maverick

Based on your prompt: "${prompt}"

I'm Llama 4 Maverick, a 17B active parameter Mixture of Experts model with 400B total parameters. I specialize in:

- **Enterprise-grade code generation**
- **Comprehensive test suite creation**
- **Architectural analysis and recommendations**
- **Complex debugging and optimization**
- **Technical documentation and best practices**

Your request has been processed using my advanced reasoning capabilities. For more specific assistance, please provide additional context about your technical requirements.

## Key Capabilities:
1. **Multi-modal understanding** - Text, code, and architectural patterns
2. **Context-aware responses** - Up to 1M token context window
3. **Expert-level reasoning** - 128 specialized expert networks
4. **Production-ready outputs** - Enterprise-grade code and documentation

How can I assist you further with your development needs?`;
  }
  
  // Truncate response if it exceeds max_tokens (rough estimation)
  const estimatedTokens = responseText.length / 4;
  if (estimatedTokens > maxTokens) {
    const targetLength = maxTokens * 4;
    responseText = responseText.substring(0, targetLength) + '...';
  }
  
  return { text: responseText };
}

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