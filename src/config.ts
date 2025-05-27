import { readFileSync } from 'fs';
import { join } from 'path';
import yaml from 'js-yaml';

interface PortConfig {
  environments: {
    [env: string]: {
      api_port: number;
      frontend_port: number;
      test_port: number;
      debug_port: number;
    };
  };
  platforms: {
    [platform: string]: {
      [env: string]: {
        api_port?: number;
        host?: string;
      };
    };
  };
  external_services: {
    [service: string]: number;
  };
  security: {
    localhost_only: string[];
    external_access_allowed: string[];
  };
}

interface AppConfig {
  name: string;
  version: string;
  port: number;
  host: string;
}

interface Config {
  environment: string;
  platform: string;
  app: AppConfig;
  auth: {
    enabled: boolean;
    method: string;
  };
  logging: {
    level: string;
    console: boolean;
    file: boolean;
    structured: boolean;
  };
}

class ConfigLoader {
  private config: Config | null = null;
  private portConfig: PortConfig | null = null;

  constructor() {
    this.loadPortConfig();
    this.loadConfig();
  }

  private loadPortConfig(): void {
    try {
      const portConfigPath = join(process.cwd(), 'config', 'ports.yml');
      
      if (this.fileExists(portConfigPath)) {
        const fileContents = readFileSync(portConfigPath, 'utf8');
        this.portConfig = yaml.load(fileContents) as PortConfig;
        console.log(`✅ Loaded port config from: ${portConfigPath}`);
      } else {
        console.warn(`Port config not found: ${portConfigPath}, using defaults`);
        this.portConfig = this.getDefaultPortConfig();
      }
    } catch (error) {
      console.error('Failed to load port config:', error);
      this.portConfig = this.getDefaultPortConfig();
    }
  }

  private getDefaultPortConfig(): PortConfig {
    return {
      environments: {
        development: { api_port: 7001, frontend_port: 7002, test_port: 7003, debug_port: 7004 }
      },
      platforms: {
        cursor: { development: { api_port: 7001, host: 'localhost' } }
      },
      external_services: { ollama: 11434 },
      security: { localhost_only: ['cursor'], external_access_allowed: ['replit', 'docker', 'aws'] }
    };
  }

  private loadConfig(): void {
    try {
      const env = process.env.NODE_ENV === 'development' ? 'dev' : process.env.NODE_ENV || 'dev';
      const platform = process.env.PLATFORM || 'cursor';
      
      // Try platform-specific config first
      let configPath = join(process.cwd(), 'config', `${env}.${platform}.yml`);
      
      // Fallback to environment-only config
      if (!this.fileExists(configPath)) {
        configPath = join(process.cwd(), 'config', `${env}.yml`);
      }
      
      if (!this.fileExists(configPath)) {
        console.warn(`Config file not found: ${configPath}, using defaults`);
        this.config = this.getDefaultConfig();
        return;
      }

      const fileContents = readFileSync(configPath, 'utf8');
      this.config = yaml.load(fileContents) as Config;
      
      console.log(`✅ Loaded config from: ${configPath}`);
      console.log(`🔧 Config port: ${this.config.app.port}`);
    } catch (error) {
      console.error('Failed to load config:', error);
      this.config = this.getDefaultConfig();
    }
  }

  private fileExists(path: string): boolean {
    try {
      readFileSync(path);
      return true;
    } catch {
      return false;
    }
  }

  private getDefaultConfig(): Config {
    return {
      environment: 'development',
      platform: 'cursor',
      app: {
        name: 'deployer-ddf-mod-llm-models',
        version: '1.0.0',
        port: 5001,
        host: 'localhost'
      },
      auth: {
        enabled: false,
        method: 'none'
      },
      logging: {
        level: 'DEBUG',
        console: true,
        file: true,
        structured: true
      }
    };
  }

  public get(): Config {
    if (!this.config) {
      this.loadConfig();
    }
    return this.config!;
  }

  public getPort(): number {
    // Environment variable takes precedence
    const envPort = process.env.PORT;
    if (envPort) {
      console.log(`🌍 Using PORT from environment: ${envPort}`);
      return parseInt(envPort, 10);
    }
    
    // Use port config if available
    if (this.portConfig) {
      const env = process.env.NODE_ENV === 'development' ? 'development' : process.env.NODE_ENV || 'development';
      const platform = process.env.PLATFORM || 'cursor';
      
      // Check platform-specific override first
      const platformConfig = this.portConfig.platforms[platform]?.[env];
      if (platformConfig?.api_port) {
        console.log(`🔧 Using port from port config (${platform}/${env}): ${platformConfig.api_port}`);
        return platformConfig.api_port;
      }
      
      // Fall back to environment default
      const envConfig = this.portConfig.environments[env];
      if (envConfig?.api_port) {
        console.log(`📋 Using port from port config (${env}): ${envConfig.api_port}`);
        return envConfig.api_port;
      }
    }
    
    // Final fallback to app config
    const configPort = this.get().app.port;
    console.log(`📋 Using port from app config: ${configPort}`);
    return configPort;
  }

  public getHost(): string {
    // Environment variable takes precedence
    const envHost = process.env.HOST;
    if (envHost) {
      console.log(`🌍 Using HOST from environment: ${envHost}`);
      return envHost;
    }
    
    // Use port config if available
    if (this.portConfig) {
      const env = process.env.NODE_ENV === 'development' ? 'development' : process.env.NODE_ENV || 'development';
      const platform = process.env.PLATFORM || 'cursor';
      
      // Check platform-specific override first
      const platformConfig = this.portConfig.platforms[platform]?.[env];
      if (platformConfig?.host) {
        console.log(`🔧 Using host from port config (${platform}/${env}): ${platformConfig.host}`);
        return platformConfig.host;
      }
      
      // Check security settings
      if (this.portConfig.security.localhost_only.includes(platform)) {
        console.log(`🔒 Using localhost for secure platform: ${platform}`);
        return 'localhost';
      }
      
      if (this.portConfig.security.external_access_allowed.includes(platform)) {
        console.log(`🌍 Using 0.0.0.0 for external access platform: ${platform}`);
        return '0.0.0.0';
      }
    }
    
    // Final fallback to app config
    const configHost = this.get().app.host;
    console.log(`📋 Using host from app config: ${configHost}`);
    return configHost || 'localhost';
  }

  public isAuthEnabled(): boolean {
    return process.env.AUTH_DISABLED !== 'true' && this.get().auth.enabled;
  }
}

export const configLoader = new ConfigLoader();
export default configLoader; 