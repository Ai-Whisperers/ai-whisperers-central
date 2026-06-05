# Building an MCP Server for Automated App Deployment

A comprehensive guide to creating a Model Context Protocol (MCP) server that enables Claude to read, understand, and deploy application codebases while teaching users the deployment process.

## Table of Contents
- [Understanding MCP](#understanding-mcp)
- [Architecture Overview](#architecture-overview)
- [Building Your Deployment MCP Server](#building-your-deployment-mcp-server)
- [Implementation Options](#implementation-options)
- [Deployment Tools Integration](#deployment-tools-integration)
- [Configuration and Setup](#configuration-and-setup)
- [Educational Features](#educational-features)
- [Security Considerations](#security-considerations)
- [Production Deployment](#production-deployment)

---

## Understanding MCP

### What is MCP?

The Model Context Protocol (MCP) is an open standard that enables AI applications to connect to external systems. Think of it as a "USB-C port for AI" - it provides a standardized way for AI models to:

- Access data sources (files, databases, APIs)
- Use tools (deployment systems, cloud platforms)
- Execute workflows (build, test, deploy pipelines)

### Key Concepts

**MCP Components:**

1. **MCP Host** - The AI application (e.g., Claude Desktop, Cursor)
2. **MCP Client** - Bridge inside the host that connects to servers
3. **MCP Server** - What you build - exposes tools, resources, and prompts
4. **Transport Layer** - How messages flow (stdio, HTTP/SSE, Streamable HTTP)

**MCP Primitives:**

- **Tools**: Functions Claude can call (e.g., `deploy_app`, `analyze_codebase`)
- **Resources**: Data Claude can read (e.g., deployment logs, config files)
- **Prompts**: Pre-written templates for common tasks

---

## Architecture Overview

### Your Deployment Server Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Claude Desktop                          │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                    MCP Client                         │  │
│  └────────────────────┬─────────────────────────────────┘  │
└───────────────────────┼─────────────────────────────────────┘
                        │ Transport (stdio/HTTP)
┌───────────────────────┼─────────────────────────────────────┐
│                       ▼                                      │
│           Your Deployment MCP Server                         │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Tools:                                              │   │
│  │  • analyze_codebase()                                │   │
│  │  • detect_framework()                                │   │
│  │  • generate_deployment_config()                      │   │
│  │  • deploy_to_platform()                              │   │
│  │  • check_deployment_status()                         │   │
│  │  • explain_deployment_steps()                        │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Resources:                                          │   │
│  │  • deployment_logs://                                │   │
│  │  • deployment_configs://                             │   │
│  │  • tutorial_content://                               │   │
│  └─────────────────────────────────────────────────────┘   │
└──────────────────────┬───────────────────────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        ▼              ▼              ▼
    ┌────────┐    ┌────────┐    ┌────────┐
    │ Docker │    │   K8s  │    │ Cloud  │
    │        │    │        │    │ APIs   │
    └────────┘    └────────┘    └────────┘
```

---

## Building Your Deployment MCP Server

### Option 1: Python with FastMCP (Recommended for Rapid Development)

FastMCP is now part of the official MCP Python SDK and provides the simplest way to build MCP servers.

#### Installation

```bash
# Install the MCP Python SDK with FastMCP
pip install mcp --break-system-packages

# Additional dependencies for deployment
pip install docker kubernetes pyyaml gitpython --break-system-packages
```

#### Basic Server Structure

```python
from mcp import FastMCP
from mcp.server import Context
import os
import subprocess
import json
from pathlib import Path

# Initialize the MCP server
mcp = FastMCP(
    name="Deployment Assistant",
    instructions="""
    This MCP server helps analyze, understand, and deploy applications.
    It can:
    - Analyze codebases to detect frameworks and dependencies
    - Generate deployment configurations (Dockerfile, docker-compose, k8s manifests)
    - Deploy applications to various platforms
    - Provide educational explanations of the deployment process
    """
)

# Tool 1: Analyze Codebase
@mcp.tool()
async def analyze_codebase(path: str) -> dict:
    """
    Analyze a codebase to detect framework, dependencies, and structure.
    
    Args:
        path: Path to the application directory
        
    Returns:
        Dictionary with framework type, dependencies, and recommendations
    """
    result = {
        "framework": None,
        "language": None,
        "dependencies": [],
        "build_system": None,
        "entry_point": None,
        "recommendations": []
    }
    
    path_obj = Path(path)
    
    # Detect package.json (Node.js)
    if (path_obj / "package.json").exists():
        result["language"] = "JavaScript/TypeScript"
        result["framework"] = detect_js_framework(path)
        result["build_system"] = "npm" if (path_obj / "package-lock.json").exists() else "yarn"
        result["dependencies"] = parse_package_json(path_obj / "package.json")
    
    # Detect requirements.txt or pyproject.toml (Python)
    elif (path_obj / "requirements.txt").exists() or (path_obj / "pyproject.toml").exists():
        result["language"] = "Python"
        result["framework"] = detect_python_framework(path)
        result["build_system"] = "pip" if (path_obj / "requirements.txt").exists() else "poetry"
        result["dependencies"] = parse_python_deps(path)
    
    # Detect pom.xml or build.gradle (Java)
    elif (path_obj / "pom.xml").exists() or (path_obj / "build.gradle").exists():
        result["language"] = "Java"
        result["build_system"] = "maven" if (path_obj / "pom.xml").exists() else "gradle"
    
    # Detect go.mod (Go)
    elif (path_obj / "go.mod").exists():
        result["language"] = "Go"
        result["framework"] = detect_go_framework(path)
        result["build_system"] = "go"
    
    # Add deployment recommendations
    result["recommendations"] = generate_recommendations(result)
    
    return result

# Tool 2: Generate Deployment Configuration
@mcp.tool()
async def generate_deployment_config(
    app_path: str,
    config_type: str,
    framework: str = None
) -> dict:
    """
    Generate deployment configuration files (Dockerfile, docker-compose, K8s manifests).
    
    Args:
        app_path: Path to the application
        config_type: Type of config to generate (dockerfile, docker-compose, kubernetes)
        framework: Framework detected (optional, will auto-detect if not provided)
        
    Returns:
        Dictionary with generated configuration content and file paths
    """
    if not framework:
        analysis = await analyze_codebase(app_path)
        framework = analysis["framework"]
        language = analysis["language"]
    
    configs = {}
    
    if config_type == "dockerfile":
        configs["Dockerfile"] = generate_dockerfile(language, framework, app_path)
        configs[".dockerignore"] = generate_dockerignore(language)
    
    elif config_type == "docker-compose":
        configs["docker-compose.yml"] = generate_docker_compose(framework, app_path)
        configs["Dockerfile"] = generate_dockerfile(language, framework, app_path)
    
    elif config_type == "kubernetes":
        configs["deployment.yaml"] = generate_k8s_deployment(framework, app_path)
        configs["service.yaml"] = generate_k8s_service(framework)
        configs["ingress.yaml"] = generate_k8s_ingress(framework)
    
    return {
        "configs": configs,
        "next_steps": get_deployment_next_steps(config_type)
    }

# Tool 3: Deploy Application
@mcp.tool()
async def deploy_application(
    app_path: str,
    platform: str,
    config: dict = None
) -> dict:
    """
    Deploy application to specified platform.
    
    Args:
        app_path: Path to the application
        platform: Target platform (docker, kubernetes, vercel, railway, etc.)
        config: Optional deployment configuration
        
    Returns:
        Deployment status, URL, and logs
    """
    result = {
        "status": "pending",
        "platform": platform,
        "url": None,
        "logs": [],
        "commands_executed": []
    }
    
    try:
        if platform == "docker":
            result = await deploy_to_docker(app_path, config)
        elif platform == "kubernetes":
            result = await deploy_to_kubernetes(app_path, config)
        elif platform == "vercel":
            result = await deploy_to_vercel(app_path, config)
        elif platform == "railway":
            result = await deploy_to_railway(app_path, config)
        else:
            result["status"] = "error"
            result["logs"].append(f"Unsupported platform: {platform}")
    
    except Exception as e:
        result["status"] = "error"
        result["logs"].append(f"Deployment failed: {str(e)}")
    
    return result

# Tool 4: Explain Deployment Process (Educational)
@mcp.tool()
async def explain_deployment_process(
    framework: str,
    platform: str,
    detail_level: str = "beginner"
) -> dict:
    """
    Provide educational explanation of the deployment process.
    
    Args:
        framework: Application framework (react, express, django, etc.)
        platform: Deployment platform (docker, kubernetes, cloud)
        detail_level: Level of detail (beginner, intermediate, advanced)
        
    Returns:
        Step-by-step explanation with commands and best practices
    """
    explanation = {
        "overview": "",
        "prerequisites": [],
        "steps": [],
        "commands": [],
        "best_practices": [],
        "common_issues": []
    }
    
    # Generate appropriate explanation based on framework and platform
    explanation = generate_deployment_explanation(framework, platform, detail_level)
    
    return explanation

# Tool 5: Monitor Deployment
@mcp.tool()
async def check_deployment_status(deployment_id: str, platform: str) -> dict:
    """
    Check the status of a deployment.
    
    Args:
        deployment_id: Unique identifier for the deployment
        platform: Platform where app is deployed
        
    Returns:
        Current status, health checks, and logs
    """
    status = {
        "deployment_id": deployment_id,
        "status": "unknown",
        "health": None,
        "logs": [],
        "metrics": {}
    }
    
    # Check status based on platform
    if platform == "docker":
        status = check_docker_status(deployment_id)
    elif platform == "kubernetes":
        status = check_k8s_status(deployment_id)
    
    return status

# Resource: Deployment Templates
@mcp.resource("deployment://templates/{framework}")
async def get_deployment_template(uri: str) -> str:
    """
    Provide deployment templates for different frameworks.
    """
    framework = uri.split("/")[-1]
    templates = load_deployment_templates()
    return templates.get(framework, "Template not found")

# Resource: Tutorial Content
@mcp.resource("tutorial://deployment/{topic}")
async def get_tutorial_content(uri: str) -> str:
    """
    Provide tutorial content on deployment topics.
    """
    topic = uri.split("/")[-1]
    tutorials = load_tutorial_content()
    return tutorials.get(topic, "Tutorial not found")

# Helper functions (implement these based on your needs)
def detect_js_framework(path):
    """Detect JavaScript framework from package.json"""
    # Implementation for React, Vue, Angular, Express, etc.
    pass

def detect_python_framework(path):
    """Detect Python framework from dependencies"""
    # Implementation for Django, Flask, FastAPI, etc.
    pass

def generate_dockerfile(language, framework, app_path):
    """Generate appropriate Dockerfile"""
    # Implementation for different languages/frameworks
    pass

def generate_k8s_deployment(framework, app_path):
    """Generate Kubernetes deployment manifest"""
    # Implementation
    pass

async def deploy_to_docker(app_path, config):
    """Deploy to Docker"""
    # Implementation using Docker SDK
    pass

async def deploy_to_kubernetes(app_path, config):
    """Deploy to Kubernetes"""
    # Implementation using kubernetes-python client
    pass

def generate_deployment_explanation(framework, platform, detail_level):
    """Generate educational content"""
    # Implementation with step-by-step guides
    pass

if __name__ == "__main__":
    # Start the MCP server
    mcp.run()
```

#### Running the Python Server

```bash
# Development mode
python deployment_server.py

# With MCP Inspector (for testing)
mcp dev deployment_server.py
```

---

### Option 2: TypeScript (Production-Ready)

TypeScript offers better type safety and integrates well with Node.js ecosystem.

#### Installation

```bash
npm init -y
npm install @modelcontextprotocol/sdk zod
npm install @types/node typescript tsx --save-dev
npm install dockerode @kubernetes/client-node
```

#### TypeScript Server Structure

```typescript
#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import * as fs from "fs/promises";
import * as path from "path";

// Initialize MCP server
const server = new McpServer({
  name: "deployment-assistant",
  version: "1.0.0",
});

// Tool 1: Analyze Codebase
server.tool(
  "analyze_codebase",
  {
    path: z.string().describe("Path to the application directory"),
  },
  async ({ path: appPath }) => {
    const analysis = {
      framework: null as string | null,
      language: null as string | null,
      dependencies: [] as string[],
      buildSystem: null as string | null,
      recommendations: [] as string[],
    };

    // Check for package.json (Node.js)
    try {
      const packageJson = await fs.readFile(
        path.join(appPath, "package.json"),
        "utf-8"
      );
      const pkg = JSON.parse(packageJson);
      analysis.language = "JavaScript/TypeScript";
      analysis.framework = detectJsFramework(pkg);
      analysis.dependencies = Object.keys(pkg.dependencies || {});
      analysis.buildSystem = await detectNodeBuildSystem(appPath);
    } catch (e) {
      // Not a Node.js project
    }

    // Check for Python projects
    try {
      await fs.access(path.join(appPath, "requirements.txt"));
      analysis.language = "Python";
      analysis.framework = await detectPythonFramework(appPath);
    } catch (e) {
      // Not a Python project
    }

    analysis.recommendations = generateRecommendations(analysis);

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(analysis, null, 2),
        },
      ],
    };
  }
);

// Tool 2: Generate Deployment Config
server.tool(
  "generate_deployment_config",
  {
    appPath: z.string(),
    configType: z.enum(["dockerfile", "docker-compose", "kubernetes"]),
    framework: z.string().optional(),
  },
  async ({ appPath, configType, framework }) => {
    let detectedFramework = framework;
    
    if (!detectedFramework) {
      // Auto-detect framework
      const analysis = await analyzeCodebase(appPath);
      detectedFramework = analysis.framework;
    }

    const configs: Record<string, string> = {};

    switch (configType) {
      case "dockerfile":
        configs["Dockerfile"] = generateDockerfile(detectedFramework, appPath);
        configs[".dockerignore"] = generateDockerignore();
        break;

      case "docker-compose":
        configs["docker-compose.yml"] = generateDockerCompose(
          detectedFramework,
          appPath
        );
        configs["Dockerfile"] = generateDockerfile(detectedFramework, appPath);
        break;

      case "kubernetes":
        configs["deployment.yaml"] = generateK8sDeployment(
          detectedFramework,
          appPath
        );
        configs["service.yaml"] = generateK8sService(detectedFramework);
        configs["ingress.yaml"] = generateK8sIngress(detectedFramework);
        break;
    }

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify({
            configs,
            nextSteps: getDeploymentNextSteps(configType),
          }, null, 2),
        },
      ],
    };
  }
);

// Tool 3: Deploy Application
server.tool(
  "deploy_application",
  {
    appPath: z.string(),
    platform: z.enum(["docker", "kubernetes", "vercel", "railway"]),
    config: z.record(z.any()).optional(),
  },
  async ({ appPath, platform, config }) => {
    const result = {
      status: "pending",
      platform,
      url: null as string | null,
      logs: [] as string[],
      commandsExecuted: [] as string[],
    };

    try {
      switch (platform) {
        case "docker":
          Object.assign(result, await deployToDocker(appPath, config));
          break;
        case "kubernetes":
          Object.assign(result, await deployToKubernetes(appPath, config));
          break;
        case "vercel":
          Object.assign(result, await deployToVercel(appPath, config));
          break;
        case "railway":
          Object.assign(result, await deployToRailway(appPath, config));
          break;
      }
    } catch (error) {
      result.status = "error";
      result.logs.push(`Deployment failed: ${error}`);
    }

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(result, null, 2),
        },
      ],
    };
  }
);

// Tool 4: Explain Deployment (Educational)
server.tool(
  "explain_deployment_process",
  {
    framework: z.string(),
    platform: z.string(),
    detailLevel: z.enum(["beginner", "intermediate", "advanced"]).default("beginner"),
  },
  async ({ framework, platform, detailLevel }) => {
    const explanation = generateDeploymentExplanation(
      framework,
      platform,
      detailLevel
    );

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(explanation, null, 2),
        },
      ],
    };
  }
);

// Resource: Deployment Templates
server.resource(
  "deployment://templates/{framework}",
  async (uri) => {
    const framework = uri.split("/").pop();
    const template = await loadDeploymentTemplate(framework!);
    
    return {
      contents: [
        {
          uri,
          mimeType: "text/yaml",
          text: template,
        },
      ],
    };
  }
);

// Helper functions
function detectJsFramework(packageJson: any): string {
  const deps = { ...packageJson.dependencies, ...packageJson.devDependencies };
  
  if (deps.react) return "React";
  if (deps.vue) return "Vue";
  if (deps["@angular/core"]) return "Angular";
  if (deps.next) return "Next.js";
  if (deps.express) return "Express";
  if (deps.fastify) return "Fastify";
  
  return "Node.js";
}

async function detectPythonFramework(appPath: string): Promise<string> {
  // Read requirements.txt or pyproject.toml
  // Check for Django, Flask, FastAPI, etc.
  return "Python";
}

function generateDockerfile(framework: string, appPath: string): string {
  // Generate appropriate Dockerfile based on framework
  return `# Generated Dockerfile for ${framework}
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3000
CMD ["npm", "start"]`;
}

function generateDockerCompose(framework: string, appPath: string): string {
  return `version: '3.8'
services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production`;
}

function generateK8sDeployment(framework: string, appPath: string): string {
  return `apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: app
  template:
    metadata:
      labels:
        app: app
    spec:
      containers:
      - name: app
        image: your-app:latest
        ports:
        - containerPort: 3000`;
}

function generateK8sService(framework: string): string {
  return `apiVersion: v1
kind: Service
metadata:
  name: app-service
spec:
  selector:
    app: app
  ports:
  - port: 80
    targetPort: 3000
  type: LoadBalancer`;
}

function generateK8sIngress(framework: string): string {
  return `apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
spec:
  rules:
  - host: your-app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-service
            port:
              number: 80`;
}

async function deployToDocker(appPath: string, config?: any) {
  // Use dockerode to build and run containers
  return {
    status: "success",
    url: "http://localhost:3000",
    logs: ["Docker container started successfully"],
  };
}

async function deployToKubernetes(appPath: string, config?: any) {
  // Use @kubernetes/client-node to deploy
  return {
    status: "success",
    logs: ["Deployed to Kubernetes cluster"],
  };
}

async function deployToVercel(appPath: string, config?: any) {
  // Use Vercel CLI or API
  return {
    status: "success",
    url: "https://your-app.vercel.app",
  };
}

async function deployToRailway(appPath: string, config?: any) {
  // Use Railway CLI or API
  return {
    status: "success",
    url: "https://your-app.up.railway.app",
  };
}

function generateDeploymentExplanation(
  framework: string,
  platform: string,
  detailLevel: string
) {
  return {
    overview: `Deploying a ${framework} application to ${platform}`,
    prerequisites: [
      "Docker installed",
      "Platform CLI installed",
      "Application code ready",
    ],
    steps: [
      {
        step: 1,
        title: "Prepare application",
        description: "Ensure your application is production-ready",
        commands: ["npm run build", "npm test"],
      },
      {
        step: 2,
        title: "Create deployment configuration",
        description: "Generate necessary config files",
        commands: ["# Configuration files will be generated"],
      },
      {
        step: 3,
        title: "Deploy application",
        description: "Execute deployment",
        commands: [`# Deploy to ${platform}`],
      },
    ],
    bestPractices: [
      "Use environment variables for secrets",
      "Implement health checks",
      "Set up monitoring and logging",
    ],
    commonIssues: [
      {
        issue: "Port conflicts",
        solution: "Ensure ports are correctly configured",
      },
    ],
  };
}

function getDeploymentNextSteps(configType: string): string[] {
  return [
    "Review generated configuration files",
    "Customize as needed for your environment",
    "Test locally before deploying",
    "Deploy to target platform",
  ];
}

function generateRecommendations(analysis: any): string[] {
  const recommendations: string[] = [];
  
  if (analysis.framework === "React") {
    recommendations.push("Consider deploying to Vercel or Netlify for static hosting");
  }
  
  if (analysis.language === "Python") {
    recommendations.push("Use gunicorn or uvicorn for production WSGI/ASGI server");
  }
  
  return recommendations;
}

// Start the server
const transport = new StdioServerTransport();
await server.connect(transport);
console.error("Deployment MCP Server running on stdio");
```

#### Build and Run TypeScript Server

```bash
# Add to package.json
{
  "name": "mcp-deployment-server",
  "version": "1.0.0",
  "type": "module",
  "bin": {
    "deployment-server": "./dist/index.js"
  },
  "scripts": {
    "build": "tsc",
    "dev": "tsx src/index.ts",
    "inspector": "npx @modelcontextprotocol/inspector dist/index.js"
  }
}

# Build
npm run build

# Run with MCP Inspector
npm run inspector
```

---

## Configuration and Setup

### Claude Desktop Configuration

Add your MCP server to Claude Desktop's configuration:

**macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
**Windows:** `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "deployment-assistant": {
      "command": "npx",
      "args": ["-y", "deployment-server"],
      "env": {
        "DOCKER_HOST": "unix:///var/run/docker.sock",
        "KUBECONFIG": "/Users/username/.kube/config"
      }
    }
  }
}
```

### For Python Server:

```json
{
  "mcpServers": {
    "deployment-assistant": {
      "command": "uvx",
      "args": ["deployment-server"],
      "env": {
        "DOCKER_HOST": "unix:///var/run/docker.sock"
      }
    }
  }
}
```

---

## Deployment Tools Integration

### Docker Integration

```python
import docker

client = docker.from_env()

def build_docker_image(app_path: str, tag: str):
    """Build Docker image from application"""
    image, logs = client.images.build(
        path=app_path,
        tag=tag,
        rm=True
    )
    return image, logs

def run_docker_container(image_tag: str, ports: dict):
    """Run Docker container"""
    container = client.containers.run(
        image_tag,
        detach=True,
        ports=ports,
        auto_remove=True
    )
    return container
```

### Kubernetes Integration

```python
from kubernetes import client, config

config.load_kube_config()

def deploy_to_k8s(manifest_path: str, namespace: str = "default"):
    """Deploy application to Kubernetes"""
    with open(manifest_path, 'r') as f:
        manifest = yaml.safe_load(f)
    
    api = client.AppsV1Api()
    
    if manifest['kind'] == 'Deployment':
        api.create_namespaced_deployment(
            namespace=namespace,
            body=manifest
        )
```

### Cloud Platform Integration

```python
# Vercel CLI integration
import subprocess

def deploy_to_vercel(app_path: str):
    """Deploy to Vercel"""
    result = subprocess.run(
        ['vercel', '--prod'],
        cwd=app_path,
        capture_output=True,
        text=True
    )
    return result.stdout

# Railway CLI integration
def deploy_to_railway(app_path: str):
    """Deploy to Railway"""
    result = subprocess.run(
        ['railway', 'up'],
        cwd=app_path,
        capture_output=True,
        text=True
    )
    return result.stdout
```

---

## Educational Features

### Interactive Learning Mode

```python
@mcp.tool()
async def interactive_deployment_tutorial(
    framework: str,
    skill_level: str = "beginner"
) -> dict:
    """
    Provide interactive, step-by-step deployment tutorial.
    
    Returns lessons, exercises, and checkpoints.
    """
    tutorial = {
        "lesson_plan": [],
        "exercises": [],
        "checkpoints": [],
        "resources": []
    }
    
    # Beginner: Start with basics
    if skill_level == "beginner":
        tutorial["lesson_plan"] = [
            {
                "topic": "Understanding Containerization",
                "content": "Containers package your app with its dependencies...",
                "practical_example": "docker run -p 3000:3000 my-app"
            },
            {
                "topic": "Creating a Dockerfile",
                "content": "A Dockerfile defines how to build your container...",
                "exercise": "Create a Dockerfile for your {framework} app"
            }
        ]
    
    # Intermediate: Orchestration
    elif skill_level == "intermediate":
        tutorial["lesson_plan"] = [
            {
                "topic": "Container Orchestration with Kubernetes",
                "content": "Kubernetes manages multiple containers...",
                "practical_example": "kubectl apply -f deployment.yaml"
            }
        ]
    
    return tutorial

@mcp.tool()
async def explain_concept(concept: str, context: str = "") -> str:
    """
    Explain deployment concepts in simple terms.
    
    Args:
        concept: Technical concept to explain (e.g., "container", "pod", "ingress")
        context: Additional context for better explanation
    """
    explanations = {
        "container": """
        A container is like a lightweight box that contains everything your app needs to run:
        - Your application code
        - Runtime environment (Node.js, Python, etc.)
        - Dependencies (libraries, packages)
        - System tools
        
        Think of it like a shipping container - it's standardized and can run anywhere!
        """,
        
        "kubernetes": """
        Kubernetes (K8s) is like an orchestra conductor for containers:
        - It decides which containers run on which servers
        - It restarts containers if they crash
        - It scales your app up or down based on traffic
        - It routes network traffic to the right containers
        
        Instead of manually managing servers, you tell Kubernetes what you want,
        and it makes it happen!
        """,
        
        "ingress": """
        An Ingress is like the front door to your application in Kubernetes:
        - It handles incoming web traffic
        - It routes requests to the right service (like a receptionist)
        - It can handle SSL/TLS for HTTPS
        - It can do load balancing
        
        Example: visitor hits your-app.com → Ingress → Your App Pods
        """
    }
    
    return explanations.get(concept.lower(), "Concept not found. Please ask about specific deployment concepts.")
```

### Show Manual Steps

```python
@mcp.tool()
async def show_manual_deployment_steps(
    framework: str,
    platform: str,
    explain_each_step: bool = True
) -> dict:
    """
    Show manual deployment steps with explanations.
    """
    steps = []
    
    if platform == "docker":
        steps = [
            {
                "step": 1,
                "command": "docker build -t my-app .",
                "explanation": "This builds a Docker image from your Dockerfile. The -t flag tags it with a name.",
                "what_it_does": "Creates a runnable container image from your code"
            },
            {
                "step": 2,
                "command": "docker run -d -p 3000:3000 my-app",
                "explanation": "This runs your container. -d runs it in background, -p maps ports.",
                "what_it_does": "Starts your application in a container"
            },
            {
                "step": 3,
                "command": "docker ps",
                "explanation": "Shows all running containers",
                "what_it_does": "Verifies your container is running"
            }
        ]
    
    elif platform == "kubernetes":
        steps = [
            {
                "step": 1,
                "command": "kubectl apply -f deployment.yaml",
                "explanation": "Applies your deployment configuration to the cluster",
                "what_it_does": "Creates pods running your application"
            },
            {
                "step": 2,
                "command": "kubectl apply -f service.yaml",
                "explanation": "Creates a service to expose your pods",
                "what_it_does": "Makes your app accessible within the cluster"
            },
            {
                "step": 3,
                "command": "kubectl get pods",
                "explanation": "Lists all pods in the current namespace",
                "what_it_does": "Shows the status of your application pods"
            }
        ]
    
    return {
        "framework": framework,
        "platform": platform,
        "steps": steps,
        "estimated_time": f"{len(steps) * 2} minutes",
        "difficulty": "beginner" if platform == "docker" else "intermediate"
    }
```

---

## Security Considerations

### 1. Sandboxing and Isolation

```python
import os

# Define allowed directories
ALLOWED_PATHS = [
    os.path.expanduser("~/projects"),
    os.path.expanduser("~/workspace")
]

def validate_path(path: str) -> bool:
    """Ensure path is within allowed directories"""
    abs_path = os.path.abspath(path)
    return any(abs_path.startswith(allowed) for allowed in ALLOWED_PATHS)

@mcp.tool()
async def analyze_codebase(path: str) -> dict:
    if not validate_path(path):
        raise ValueError("Access denied: Path outside allowed directories")
    
    # Proceed with analysis
    ...
```

### 2. Read-Only Mode

```python
READ_ONLY = os.getenv("MCP_READ_ONLY", "false").lower() == "true"

@mcp.tool()
async def deploy_application(app_path: str, platform: str) -> dict:
    if READ_ONLY:
        return {
            "status": "simulated",
            "message": "Server is in read-only mode. Deployment simulated.",
            "would_execute": get_deployment_commands(app_path, platform)
        }
    
    # Actual deployment
    ...
```

### 3. Credential Management

```python
from dotenv import load_dotenv

load_dotenv()

# Never expose these directly
DOCKER_REGISTRY_TOKEN = os.getenv("DOCKER_TOKEN")
K8S_API_TOKEN = os.getenv("K8S_TOKEN")
VERCEL_TOKEN = os.getenv("VERCEL_TOKEN")

# Use secure storage for production
def get_credential(service: str) -> str:
    """Retrieve credentials from secure vault"""
    # Use AWS Secrets Manager, HashiCorp Vault, etc.
    pass
```

### 4. Input Validation

```python
from pydantic import BaseModel, validator

class DeploymentConfig(BaseModel):
    app_path: str
    platform: str
    replicas: int = 1
    
    @validator('replicas')
    def validate_replicas(cls, v):
        if v < 1 or v > 10:
            raise ValueError('Replicas must be between 1 and 10')
        return v
    
    @validator('platform')
    def validate_platform(cls, v):
        allowed = ['docker', 'kubernetes', 'vercel', 'railway']
        if v not in allowed:
            raise ValueError(f'Platform must be one of {allowed}')
        return v
```

---

## Production Deployment

### Containerizing Your MCP Server

```dockerfile
# Dockerfile for MCP Server
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    docker.io \
    kubectl \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy server code
COPY . .

# Run as non-root user
RUN useradd -m -u 1000 mcpuser && \
    chown -R mcpuser:mcpuser /app

USER mcpuser

CMD ["python", "deployment_server.py"]
```

### Kubernetes Deployment

```yaml
# mcp-server-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mcp-deployment-server
  namespace: mcp-system
spec:
  replicas: 2
  selector:
    matchLabels:
      app: mcp-server
  template:
    metadata:
      labels:
        app: mcp-server
    spec:
      serviceAccountName: mcp-server
      containers:
      - name: mcp-server
        image: your-registry/mcp-deployment-server:latest
        ports:
        - containerPort: 8080
          name: http
        env:
        - name: MCP_READ_ONLY
          value: "false"
        - name: ALLOWED_NAMESPACES
          value: "default,production"
        resources:
          requests:
            cpu: "100m"
            memory: "256Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
        securityContext:
          runAsNonRoot: true
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
---
apiVersion: v1
kind: Service
metadata:
  name: mcp-server
  namespace: mcp-system
spec:
  selector:
    app: mcp-server
  ports:
  - port: 8080
    targetPort: 8080
    protocol: TCP
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: mcp-server
  namespace: mcp-system
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - mcp.yourdomain.com
    secretName: mcp-server-tls
  rules:
  - host: mcp.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: mcp-server
            port:
              number: 8080
```

### RBAC Configuration

```yaml
# mcp-server-rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: mcp-server
  namespace: mcp-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: mcp-server
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "create", "update", "delete"]
- apiGroups: [""]
  resources: ["services", "pods", "configmaps"]
  verbs: ["get", "list", "create", "update", "delete"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "create", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: mcp-server
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: mcp-server
subjects:
- kind: ServiceAccount
  name: mcp-server
  namespace: mcp-system
```

### Monitoring and Logging

```python
import logging
import structlog

# Configure structured logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer()
    ],
    wrapper_class=structlog.stdlib.BoundLogger,
    logger_factory=structlog.stdlib.LoggerFactory(),
)

logger = structlog.get_logger()

@mcp.tool()
async def deploy_application(app_path: str, platform: str) -> dict:
    logger.info(
        "deployment_started",
        app_path=app_path,
        platform=platform,
        user_id=get_current_user()
    )
    
    try:
        result = await perform_deployment(app_path, platform)
        
        logger.info(
            "deployment_completed",
            app_path=app_path,
            platform=platform,
            status=result['status']
        )
        
        return result
    
    except Exception as e:
        logger.error(
            "deployment_failed",
            app_path=app_path,
            platform=platform,
            error=str(e),
            exc_info=True
        )
        raise
```

---

## Testing Your MCP Server

### Using MCP Inspector

```bash
# Install MCP Inspector
npm install -g @modelcontextprotocol/inspector

# Test your server
npx @modelcontextprotocol/inspector path/to/your/server.py

# Or for TypeScript
npx @modelcontextprotocol/inspector dist/index.js
```

### Integration Tests

```python
import pytest
from mcp.client import MCPClient

@pytest.mark.asyncio
async def test_analyze_codebase():
    client = MCPClient()
    await client.connect("stdio", command="python", args=["deployment_server.py"])
    
    result = await client.call_tool(
        "analyze_codebase",
        {"path": "/path/to/test/app"}
    )
    
    assert result["language"] is not None
    assert result["framework"] is not None
    assert len(result["recommendations"]) > 0

@pytest.mark.asyncio
async def test_generate_dockerfile():
    client = MCPClient()
    await client.connect("stdio", command="python", args=["deployment_server.py"])
    
    result = await client.call_tool(
        "generate_deployment_config",
        {
            "app_path": "/path/to/test/app",
            "config_type": "dockerfile",
            "framework": "react"
        }
    )
    
    assert "Dockerfile" in result["configs"]
    assert ".dockerignore" in result["configs"]
```

---

## Usage Examples

### Example 1: Deploy a React App

```
User: I have a React app in ~/projects/my-app, can you deploy it to Docker?

Claude (using MCP server):
1. Calling analyze_codebase(path="~/projects/my-app")
   → Detected: React, Node.js, npm

2. Calling generate_deployment_config(
     app_path="~/projects/my-app",
     config_type="dockerfile",
     framework="React"
   )
   → Generated Dockerfile and .dockerignore

3. Would you like me to explain what these files do before deploying?

User: Yes, please explain!

Claude:
4. Calling explain_deployment_process(
     framework="React",
     platform="docker",
     detail_level="beginner"
   )
   
   [Provides step-by-step explanation]

User: Sounds good, let's deploy!

Claude:
5. Calling deploy_application(
     app_path="~/projects/my-app",
     platform="docker"
   )
   
   ✅ Deployment successful!
   Your app is running at: http://localhost:3000
```

### Example 2: Learn Kubernetes Deployment

```
User: I want to learn how to deploy my Node.js API to Kubernetes

Claude:
1. Calling interactive_deployment_tutorial(
     framework="Express",
     skill_level="beginner"
   )
   
   📚 Kubernetes Deployment Tutorial for Express
   
   Lesson 1: Understanding Kubernetes Basics
   - What is Kubernetes?
   - Why use it for your API?
   
   Lesson 2: Creating Deployment Manifests
   - deployment.yaml explained
   - service.yaml explained
   
   Lesson 3: Hands-on Deployment
   Let's deploy your API step by step!
   
2. Calling generate_deployment_config(
     app_path="~/projects/api",
     config_type="kubernetes",
     framework="Express"
   )

3. Calling show_manual_deployment_steps(
     framework="Express",
     platform="kubernetes",
     explain_each_step=true
   )
   
   [Shows commands with explanations]
```

---

## Best Practices

### 1. Progressive Enhancement
- Start with simple Docker deployments
- Progress to orchestration when needed
- Introduce advanced concepts gradually

### 2. Error Handling
```python
@mcp.tool()
async def deploy_application(app_path: str, platform: str) -> dict:
    try:
        # Validate inputs
        if not os.path.exists(app_path):
            return {
                "status": "error",
                "error": "App path does not exist",
                "suggestion": "Check the path and try again"
            }
        
        # Perform deployment
        result = await do_deployment(app_path, platform)
        return result
        
    except docker.errors.BuildError as e:
        return {
            "status": "error",
            "error": "Docker build failed",
            "details": str(e),
            "suggestion": "Check your Dockerfile for syntax errors"
        }
    
    except Exception as e:
        logger.exception("Unexpected deployment error")
        return {
            "status": "error",
            "error": str(e),
            "suggestion": "Please check the logs for more details"
        }
```

### 3. Documentation
- Include inline documentation
- Provide examples for each tool
- Link to external resources

### 4. Testing
- Test with real applications
- Include edge cases
- Mock external dependencies

---

## Resources

### Official Documentation
- **MCP Specification**: https://spec.modelcontextprotocol.io
- **MCP Documentation**: https://modelcontextprotocol.io
- **Python SDK**: https://github.com/modelcontextprotocol/python-sdk
- **TypeScript SDK**: https://github.com/modelcontextprotocol/typescript-sdk

### Example Servers
- **MCP Servers Repository**: https://github.com/modelcontextprotocol/servers
- **Kubernetes MCP Server**: https://github.com/containers/kubernetes-mcp-server
- **Docker MCP Catalog**: https://hub.docker.com/mcp

### Community
- **MCP Registry**: https://registry.modelcontextprotocol.io
- **GitHub Discussions**: https://github.com/modelcontextprotocol/modelcontextprotocol/discussions

---

## Next Steps

1. **Start Simple**: Build a basic server with 2-3 tools
2. **Test Locally**: Use MCP Inspector to verify functionality
3. **Add Features**: Gradually add deployment platforms
4. **Get Feedback**: Share with coworkers and iterate
5. **Deploy to Production**: Follow security and monitoring best practices

---

## Conclusion

Building an MCP server for deployment automation creates a powerful tool that:

✅ Enables Claude to understand and deploy any codebase
✅ Teaches users deployment concepts interactively
✅ Automates repetitive deployment tasks
✅ Scales from simple Docker deployments to complex Kubernetes orchestration
✅ Provides a foundation for your team's developer experience

Start building your MCP server today and empower your team with AI-assisted deployment automation!

---

## Appendix: Full Example Server

See the complete, production-ready examples in the sections above. The Python FastMCP example provides a quick start, while the TypeScript version offers production-grade type safety and performance.

Both implementations support:
- Multi-framework detection (React, Vue, Django, Flask, Express, etc.)
- Multi-platform deployment (Docker, Kubernetes, Vercel, Railway)
- Educational features for learning
- Security best practices
- Production deployment patterns

Choose the implementation that best fits your tech stack and start building!
