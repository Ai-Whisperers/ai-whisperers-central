# API Contract Specification

**Version:** 1.0.0
**Date:** 2025-12-19
**Purpose:** Define REST API and CLI interfaces for feedback-arrow
**Status:** Specification

---

## OVERVIEW

feedback-arrow exposes two interfaces:
1. **CLI** - Command-line interface for local/scripted usage
2. **REST API** - HTTP API for integrations and web access

Both interfaces use the same underlying analysis pipeline and share configuration.

---

## 1. REST API SPECIFICATION

### 1.1 OpenAPI 3.1 Definition

```yaml
openapi: 3.1.0
info:
  title: Feedback Arrow API
  description: Customer feedback analysis with LLM-powered insights
  version: 1.0.0
  contact:
    name: feedback-arrow
    url: https://github.com/feedback-arrow/feedback-arrow
  license:
    name: MIT

servers:
  - url: http://localhost:8000
    description: Local development
  - url: https://api.feedback-arrow.com
    description: Production

tags:
  - name: Analysis
    description: Submit and retrieve analysis jobs
  - name: Tasks
    description: Task management and monitoring
  - name: Providers
    description: LLM provider management
  - name: Config
    description: Configuration endpoints
  - name: Health
    description: Health checks

paths:
  /api/v1/analyze:
    post:
      summary: Submit analysis job
      description: |
        Upload a file and start analysis. Returns a task ID for tracking.
        Supports CSV, Excel (.xlsx), and Parquet files.
      tags: [Analysis]
      operationId: submitAnalysis
      requestBody:
        required: true
        content:
          multipart/form-data:
            schema:
              type: object
              required: [file]
              properties:
                file:
                  type: string
                  format: binary
                  description: File to analyze (CSV, XLSX, Parquet)
                config:
                  type: string
                  format: json
                  description: Optional analysis configuration JSON
                callback_url:
                  type: string
                  format: uri
                  description: Webhook URL for completion notification
            examples:
              csv_upload:
                summary: CSV file upload
                value:
                  file: "feedback.csv"
                  config: '{"language": "es", "modules": {"emotions": true}}'
      responses:
        '202':
          description: Analysis job accepted
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/TaskCreated'
        '400':
          description: Invalid request
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Error'
        '413':
          description: File too large
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Error'

  /api/v1/analyze/sync:
    post:
      summary: Synchronous analysis (small files)
      description: |
        Analyze file synchronously and return results directly.
        Limited to files under 1000 rows. For larger files, use async endpoint.
      tags: [Analysis]
      operationId: analyzeSync
      requestBody:
        required: true
        content:
          multipart/form-data:
            schema:
              type: object
              required: [file]
              properties:
                file:
                  type: string
                  format: binary
                config:
                  type: string
                  format: json
                format:
                  type: string
                  enum: [json, csv, parquet]
                  default: json
      responses:
        '200':
          description: Analysis results
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/AnalysisResult'
            text/csv:
              schema:
                type: string
            application/octet-stream:
              schema:
                type: string
                format: binary
        '400':
          description: Invalid request or file too large
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Error'

  /api/v1/tasks:
    get:
      summary: List tasks
      description: List analysis tasks with optional filtering
      tags: [Tasks]
      operationId: listTasks
      parameters:
        - name: status
          in: query
          schema:
            type: string
            enum: [pending, running, completed, failed, cancelled]
        - name: limit
          in: query
          schema:
            type: integer
            default: 20
            maximum: 100
        - name: offset
          in: query
          schema:
            type: integer
            default: 0
      responses:
        '200':
          description: List of tasks
          content:
            application/json:
              schema:
                type: object
                properties:
                  tasks:
                    type: array
                    items:
                      $ref: '#/components/schemas/Task'
                  total:
                    type: integer
                  limit:
                    type: integer
                  offset:
                    type: integer

  /api/v1/tasks/{task_id}:
    get:
      summary: Get task status
      description: Get detailed status of a specific task
      tags: [Tasks]
      operationId: getTask
      parameters:
        - name: task_id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      responses:
        '200':
          description: Task details
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Task'
        '404':
          description: Task not found
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Error'

    delete:
      summary: Cancel task
      description: Cancel a running or pending task
      tags: [Tasks]
      operationId: cancelTask
      parameters:
        - name: task_id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      responses:
        '200':
          description: Task cancelled
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Task'
        '404':
          description: Task not found
        '409':
          description: Task cannot be cancelled (already completed/failed)

  /api/v1/tasks/{task_id}/results:
    get:
      summary: Download results
      description: Download analysis results in specified format
      tags: [Tasks]
      operationId: getResults
      parameters:
        - name: task_id
          in: path
          required: true
          schema:
            type: string
            format: uuid
        - name: format
          in: query
          schema:
            type: string
            enum: [parquet, csv, json, jsonl]
            default: parquet
        - name: columns
          in: query
          schema:
            type: array
            items:
              type: string
          description: Specific columns to include (default all)
      responses:
        '200':
          description: Analysis results
          content:
            application/vnd.apache.parquet:
              schema:
                type: string
                format: binary
            text/csv:
              schema:
                type: string
            application/json:
              schema:
                type: array
                items:
                  type: object
            application/x-ndjson:
              schema:
                type: string
        '202':
          description: Results not yet available
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Task'
        '404':
          description: Task not found

  /api/v1/tasks/{task_id}/progress:
    get:
      summary: Get task progress (SSE)
      description: Server-sent events stream for real-time progress updates
      tags: [Tasks]
      operationId: getProgress
      parameters:
        - name: task_id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      responses:
        '200':
          description: SSE stream of progress events
          content:
            text/event-stream:
              schema:
                type: string

  /api/v1/providers:
    get:
      summary: List LLM providers
      description: List available and configured LLM providers
      tags: [Providers]
      operationId: listProviders
      responses:
        '200':
          description: List of providers
          content:
            application/json:
              schema:
                type: object
                properties:
                  providers:
                    type: array
                    items:
                      $ref: '#/components/schemas/Provider'
                  default:
                    type: string

  /api/v1/providers/{provider_id}/health:
    get:
      summary: Check provider health
      description: Check if a specific provider is available and responding
      tags: [Providers]
      operationId: checkProviderHealth
      parameters:
        - name: provider_id
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Provider health status
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/HealthStatus'

  /api/v1/config:
    get:
      summary: Get current configuration
      description: Get current analysis configuration
      tags: [Config]
      operationId: getConfig
      responses:
        '200':
          description: Configuration
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Config'

    patch:
      summary: Update configuration
      description: Update analysis configuration (partial update)
      tags: [Config]
      operationId: updateConfig
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/ConfigUpdate'
      responses:
        '200':
          description: Updated configuration
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Config'

  /api/v1/health:
    get:
      summary: Health check
      description: Basic health check endpoint
      tags: [Health]
      operationId: healthCheck
      responses:
        '200':
          description: Service is healthy
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/HealthStatus'

  /api/v1/health/ready:
    get:
      summary: Readiness check
      description: Check if service is ready to accept requests
      tags: [Health]
      operationId: readinessCheck
      responses:
        '200':
          description: Service is ready
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/HealthStatus'
        '503':
          description: Service not ready
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/HealthStatus'

  /api/v1/health/live:
    get:
      summary: Liveness check
      description: Check if service is alive (for k8s probes)
      tags: [Health]
      operationId: livenessCheck
      responses:
        '200':
          description: Service is alive
          content:
            application/json:
              schema:
                type: object
                properties:
                  status:
                    type: string
                    enum: [ok]

components:
  schemas:
    TaskCreated:
      type: object
      required: [task_id, status, created_at]
      properties:
        task_id:
          type: string
          format: uuid
        status:
          type: string
          enum: [pending]
        created_at:
          type: string
          format: date-time
        estimated_cost:
          $ref: '#/components/schemas/CostEstimate'
        links:
          type: object
          properties:
            status:
              type: string
              format: uri
            results:
              type: string
              format: uri
            cancel:
              type: string
              format: uri

    Task:
      type: object
      required: [task_id, status, created_at]
      properties:
        task_id:
          type: string
          format: uuid
        status:
          type: string
          enum: [pending, running, completed, failed, cancelled]
        created_at:
          type: string
          format: date-time
        started_at:
          type: string
          format: date-time
        completed_at:
          type: string
          format: date-time
        progress:
          type: number
          minimum: 0
          maximum: 1
        current_node:
          type: string
        rows_processed:
          type: integer
        rows_total:
          type: integer
        error:
          type: string
        config:
          type: object
        metrics:
          $ref: '#/components/schemas/TaskMetrics'

    TaskMetrics:
      type: object
      properties:
        duration_ms:
          type: integer
        rows_analyzed:
          type: integer
        duplicates_found:
          type: integer
        llm_tokens_used:
          type: integer
        llm_cost_usd:
          type: number
        cache_hit_rate:
          type: number

    CostEstimate:
      type: object
      properties:
        per_row_usd:
          type: number
        total_usd:
          type: number
        breakdown:
          type: object
          additionalProperties:
            type: number

    AnalysisResult:
      type: object
      properties:
        task_id:
          type: string
        rows:
          type: array
          items:
            type: object
        metrics:
          $ref: '#/components/schemas/TaskMetrics'
        schema:
          type: object
          description: Arrow schema as JSON

    Provider:
      type: object
      required: [id, name, status]
      properties:
        id:
          type: string
        name:
          type: string
        type:
          type: string
          enum: [local, cloud]
        status:
          type: string
          enum: [available, unavailable, degraded]
        model:
          type: string
        capabilities:
          type: object
          properties:
            structured_output:
              type: boolean
            batch:
              type: boolean
            streaming:
              type: boolean
            vision:
              type: boolean
        cost:
          type: object
          properties:
            per_1k_input:
              type: number
            per_1k_output:
              type: number

    Config:
      type: object
      properties:
        language:
          type: string
          default: es
        modules:
          type: object
          properties:
            sentiment:
              type: boolean
            churn:
              type: boolean
            emotions:
              type: boolean
            pain_points:
              type: boolean
            nps:
              type: boolean
            insights:
              type: boolean
        llm:
          type: object
          properties:
            provider:
              type: string
            routing_strategy:
              type: string
              enum: [local_first, cost, latency, quality, failover]
        output:
          type: object
          properties:
            formats:
              type: array
              items:
                type: string
            compression:
              type: string

    ConfigUpdate:
      type: object
      properties:
        language:
          type: string
        modules:
          type: object
        llm:
          type: object
        output:
          type: object

    HealthStatus:
      type: object
      required: [status]
      properties:
        status:
          type: string
          enum: [healthy, unhealthy, degraded]
        version:
          type: string
        uptime_seconds:
          type: integer
        checks:
          type: object
          additionalProperties:
            type: object
            properties:
              status:
                type: string
              message:
                type: string

    Error:
      type: object
      required: [error, message]
      properties:
        error:
          type: string
        message:
          type: string
        details:
          type: object

  securitySchemes:
    BearerAuth:
      type: http
      scheme: bearer
    ApiKeyAuth:
      type: apiKey
      in: header
      name: X-API-Key

security:
  - BearerAuth: []
  - ApiKeyAuth: []
```

---

## 2. CLI SPECIFICATION

### 2.1 Command Structure

```
feedback-arrow <command> [subcommand] [options] [arguments]

Commands:
  analyze     Run feedback analysis
  validate    Validate input files or language packs
  providers   Manage LLM providers
  config      View/edit configuration
  server      Start API server
  version     Show version information
```

### 2.2 analyze Command

```bash
feedback-arrow analyze [OPTIONS] <INPUT>

Arguments:
  INPUT                     Input file path (CSV, XLSX, Parquet)

Options:
  -o, --output PATH         Output file path (default: {input}_analyzed.parquet)
  -f, --format FORMAT       Output format: parquet, csv, json (default: parquet)
  -l, --language LANG       Language code (default: es)
  -c, --config PATH         Config file path
  --modules MODULES         Comma-separated modules to enable
  --provider PROVIDER       LLM provider to use (default: auto)
  --batch-size N            Batch size for LLM calls (default: 50)
  --no-cache                Disable cache
  --resume CHECKPOINT       Resume from checkpoint
  --dry-run                 Show what would be done without executing
  -v, --verbose             Verbose output
  -q, --quiet               Suppress output except errors
  --progress                Show progress bar (default in TTY)
  -h, --help                Show help

Examples:
  # Basic analysis
  feedback-arrow analyze feedback.csv

  # Specify output and format
  feedback-arrow analyze input.xlsx -o results.csv -f csv

  # Enable specific modules only
  feedback-arrow analyze data.csv --modules sentiment,churn

  # Use specific provider
  feedback-arrow analyze data.csv --provider ollama

  # Resume from checkpoint
  feedback-arrow analyze data.csv --resume checkpoints/abc123/

Output:
  Creates analysis output file with 36 columns.
  Prints summary statistics on completion.

Exit Codes:
  0   Success
  1   General error
  2   Invalid arguments
  3   Input file error
  4   LLM provider error
  5   Output write error
```

### 2.3 validate Command

```bash
feedback-arrow validate [OPTIONS] <TARGET>

Subcommands:
  input           Validate input file
  output          Validate output file schema
  language-pack   Validate language pack
  config          Validate configuration file

Arguments:
  TARGET          Path to file/directory to validate

Options:
  --schema PATH   Custom schema path
  --strict        Fail on warnings
  -v, --verbose   Show detailed validation results
  -h, --help      Show help

Examples:
  # Validate input file
  feedback-arrow validate input feedback.csv

  # Validate language pack
  feedback-arrow validate language-pack language_packs/es/

  # Validate config
  feedback-arrow validate config config/pipeline.yaml

Output:
  Lists validation errors and warnings.
  Returns exit code 0 if valid, 1 if errors found.
```

### 2.4 providers Command

```bash
feedback-arrow providers <SUBCOMMAND>

Subcommands:
  list            List available providers
  health          Check provider health
  test            Test provider with sample input
  set-default     Set default provider

Options:
  --json          Output as JSON
  -h, --help      Show help

Examples:
  # List all providers
  feedback-arrow providers list

  # Check health of all providers
  feedback-arrow providers health

  # Test specific provider
  feedback-arrow providers test ollama

  # Set default provider
  feedback-arrow providers set-default ollama

Output (list):
  ┌──────────┬─────────┬───────────┬────────────────┐
  │ Provider │ Status  │ Model     │ Cost/1K tokens │
  ├──────────┼─────────┼───────────┼────────────────┤
  │ ollama   │ healthy │ llama3:8b │ $0.00          │
  │ openai   │ healthy │ gpt-4o-m  │ $0.00015       │
  │ anthropic│ unavail │ -         │ -              │
  └──────────┴─────────┴───────────┴────────────────┘
```

### 2.5 config Command

```bash
feedback-arrow config <SUBCOMMAND>

Subcommands:
  show            Show current configuration
  edit            Open config in editor
  get KEY         Get specific config value
  set KEY VALUE   Set config value
  reset           Reset to defaults
  path            Show config file path

Options:
  --global        Use global config (~/.feedback-arrow/config.yaml)
  --local         Use local config (./feedback-arrow.yaml)
  --json          Output as JSON
  -h, --help      Show help

Examples:
  # Show all config
  feedback-arrow config show

  # Get specific value
  feedback-arrow config get llm.provider

  # Set value
  feedback-arrow config set language es

  # Reset to defaults
  feedback-arrow config reset
```

### 2.6 server Command

```bash
feedback-arrow server [OPTIONS]

Start the REST API server.

Options:
  -p, --port PORT       Port to listen on (default: 8000)
  -h, --host HOST       Host to bind to (default: 127.0.0.1)
  -w, --workers N       Number of worker processes (default: 1)
  --reload              Enable auto-reload for development
  --no-docs             Disable OpenAPI docs endpoint
  --log-level LEVEL     Log level: debug, info, warn, error
  --config PATH         Config file path
  --help                Show help

Examples:
  # Start development server
  feedback-arrow server --reload

  # Production with multiple workers
  feedback-arrow server -p 8080 --host 0.0.0.0 -w 4

  # With custom config
  feedback-arrow server --config production.yaml
```

### 2.7 Global Options

```bash
Global Options (available for all commands):
  --version       Show version and exit
  --help, -h      Show help
  --config PATH   Path to config file
  --log-level     Log level: debug, info, warn, error (default: info)
  --no-color      Disable colored output
  --json          Output as JSON where applicable
```

---

## 3. API IMPLEMENTATION NOTES

### 3.1 FastAPI Application Structure

```python
# src/feedback_arrow/api/app.py

from fastapi import FastAPI, UploadFile, BackgroundTasks, Depends
from fastapi.responses import StreamingResponse
from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    await initialize_providers()
    await warm_caches()
    yield
    # Shutdown
    await cleanup_tasks()
    await close_connections()

app = FastAPI(
    title="Feedback Arrow API",
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/api/docs",
    openapi_url="/api/openapi.json"
)

# Include routers
app.include_router(analysis_router, prefix="/api/v1")
app.include_router(tasks_router, prefix="/api/v1")
app.include_router(providers_router, prefix="/api/v1")
app.include_router(config_router, prefix="/api/v1")
app.include_router(health_router, prefix="/api/v1")
```

### 3.2 Authentication Middleware

```python
# src/feedback_arrow/api/auth.py

from fastapi import Security, HTTPException
from fastapi.security import HTTPBearer, APIKeyHeader

bearer_scheme = HTTPBearer(auto_error=False)
api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)

async def get_current_user(
    bearer: str = Security(bearer_scheme),
    api_key: str = Security(api_key_header)
):
    if bearer:
        return await verify_bearer_token(bearer.credentials)
    if api_key:
        return await verify_api_key(api_key)

    # Allow unauthenticated access for local deployments
    if settings.allow_anonymous:
        return AnonymousUser()

    raise HTTPException(status_code=401, detail="Authentication required")
```

### 3.3 Rate Limiting

```python
# src/feedback_arrow/api/ratelimit.py

from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

# Rate limits
RATE_LIMITS = {
    "analyze": "10/minute",        # 10 analysis jobs per minute
    "analyze_sync": "30/minute",   # 30 sync analyses per minute
    "tasks": "100/minute",         # 100 task queries per minute
    "default": "1000/minute"       # Default for other endpoints
}
```

### 3.4 Background Task Processing

```python
# src/feedback_arrow/api/tasks.py

from fastapi import BackgroundTasks
import asyncio

class TaskManager:
    def __init__(self, persistence: IPersistence, state: IStateStore):
        self.persistence = persistence
        self.state = state
        self.running_tasks: Dict[str, asyncio.Task] = {}

    async def submit_task(
        self,
        file_path: str,
        config: Dict[str, Any],
        callback_url: Optional[str] = None
    ) -> str:
        # Create task record
        task_id = str(uuid.uuid4())
        await self.persistence.create("tasks", {
            "id": task_id,
            "status": "pending",
            "config": config,
            "input_path": file_path,
            "created_at": datetime.utcnow().isoformat()
        })

        # Start background processing
        task = asyncio.create_task(
            self._run_analysis(task_id, file_path, config, callback_url)
        )
        self.running_tasks[task_id] = task

        return task_id

    async def _run_analysis(
        self,
        task_id: str,
        file_path: str,
        config: Dict[str, Any],
        callback_url: Optional[str]
    ):
        try:
            # Update status to running
            await self.persistence.update("tasks", task_id, {"status": "running"})

            # Run pipeline
            result = await run_pipeline(file_path, config, progress_callback=lambda p: self._update_progress(task_id, p))

            # Update status to completed
            await self.persistence.update("tasks", task_id, {
                "status": "completed",
                "output_path": result.output_path,
                "metrics": result.metrics,
                "completed_at": datetime.utcnow().isoformat()
            })

            # Webhook callback
            if callback_url:
                await self._send_callback(callback_url, task_id, "completed")

        except Exception as e:
            await self.persistence.update("tasks", task_id, {
                "status": "failed",
                "error": str(e)
            })
            if callback_url:
                await self._send_callback(callback_url, task_id, "failed", str(e))
```

---

## 4. CLI IMPLEMENTATION NOTES

### 4.1 Typer Application Structure

```python
# src/feedback_arrow/cli/main.py

import typer
from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn

app = typer.Typer(
    name="feedback-arrow",
    help="Customer feedback analysis with LLM-powered insights",
    no_args_is_help=True
)
console = Console()

# Add subcommands
app.add_typer(analyze_app, name="analyze")
app.add_typer(validate_app, name="validate")
app.add_typer(providers_app, name="providers")
app.add_typer(config_app, name="config")
app.add_typer(server_app, name="server")

@app.callback()
def main(
    version: bool = typer.Option(False, "--version", help="Show version"),
    config: Path = typer.Option(None, "--config", help="Config file path"),
    log_level: str = typer.Option("info", "--log-level", help="Log level"),
    no_color: bool = typer.Option(False, "--no-color", help="Disable colors"),
):
    if version:
        console.print(f"feedback-arrow {__version__}")
        raise typer.Exit()

    if no_color:
        console.no_color = True

    setup_logging(log_level)
    load_config(config)
```

### 4.2 Analyze Command Implementation

```python
# src/feedback_arrow/cli/analyze.py

import typer
from pathlib import Path
from rich.progress import Progress, BarColumn, TaskProgressColumn
from rich.table import Table

analyze_app = typer.Typer()

@analyze_app.callback(invoke_without_command=True)
def analyze(
    input_path: Path = typer.Argument(..., help="Input file"),
    output: Path = typer.Option(None, "-o", "--output", help="Output path"),
    format: str = typer.Option("parquet", "-f", "--format", help="Output format"),
    language: str = typer.Option("es", "-l", "--language", help="Language"),
    modules: str = typer.Option(None, "--modules", help="Modules to enable"),
    provider: str = typer.Option("auto", "--provider", help="LLM provider"),
    batch_size: int = typer.Option(50, "--batch-size", help="Batch size"),
    no_cache: bool = typer.Option(False, "--no-cache", help="Disable cache"),
    resume: Path = typer.Option(None, "--resume", help="Resume from checkpoint"),
    dry_run: bool = typer.Option(False, "--dry-run", help="Dry run"),
    verbose: bool = typer.Option(False, "-v", "--verbose", help="Verbose"),
    quiet: bool = typer.Option(False, "-q", "--quiet", help="Quiet"),
    progress: bool = typer.Option(True, "--progress/--no-progress", help="Progress bar"),
):
    """Run feedback analysis on input file."""

    # Validate input
    if not input_path.exists():
        console.print(f"[red]Error:[/red] File not found: {input_path}")
        raise typer.Exit(2)

    # Determine output path
    if output is None:
        output = input_path.with_stem(f"{input_path.stem}_analyzed").with_suffix(f".{format}")

    # Build config
    config = build_config(
        language=language,
        modules=modules.split(",") if modules else None,
        provider=provider,
        batch_size=batch_size,
        no_cache=no_cache
    )

    if dry_run:
        console.print("[yellow]Dry run mode - no analysis will be performed[/yellow]")
        print_config(config)
        raise typer.Exit(0)

    # Run analysis with progress
    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        BarColumn(),
        TaskProgressColumn(),
        console=console,
        disable=quiet or not progress
    ) as progress:
        task = progress.add_task("Analyzing...", total=100)

        def update_progress(node: str, pct: float):
            progress.update(task, completed=int(pct * 100), description=f"[{node}]")

        result = run_analysis(
            input_path=input_path,
            output_path=output,
            config=config,
            resume=resume,
            progress_callback=update_progress
        )

    # Print summary
    if not quiet:
        print_summary(result)

    raise typer.Exit(0)


def print_summary(result: AnalysisResult):
    """Print analysis summary."""
    table = Table(title="Analysis Complete")
    table.add_column("Metric", style="cyan")
    table.add_column("Value", style="green")

    table.add_row("Rows analyzed", str(result.metrics["rows_analyzed"]))
    table.add_row("Duplicates found", str(result.metrics["duplicates_found"]))
    table.add_row("LLM tokens used", str(result.metrics["llm_tokens_used"]))
    table.add_row("Estimated cost", f"${result.metrics['llm_cost_usd']:.4f}")
    table.add_row("Duration", f"{result.metrics['duration_ms'] / 1000:.1f}s")
    table.add_row("Output file", str(result.output_path))

    console.print(table)
```

---

## 5. ERROR HANDLING

### 5.1 Error Response Format

```json
{
  "error": "ValidationError",
  "message": "Missing required column: customer_comment",
  "details": {
    "file": "input.csv",
    "required_columns": ["customer_comment"],
    "found_columns": ["comment", "score"]
  },
  "request_id": "abc123",
  "documentation_url": "https://docs.feedback-arrow.com/errors/validation"
}
```

### 5.2 Error Codes

| HTTP | Error Code | Description |
|------|------------|-------------|
| 400 | ValidationError | Invalid input data |
| 400 | InvalidFormat | Unsupported file format |
| 400 | SchemaError | Schema validation failed |
| 401 | AuthenticationError | Invalid or missing credentials |
| 403 | ForbiddenError | Permission denied |
| 404 | NotFoundError | Resource not found |
| 409 | ConflictError | Resource state conflict |
| 413 | FileTooLarge | File exceeds size limit |
| 422 | ProcessingError | Analysis processing failed |
| 429 | RateLimitError | Rate limit exceeded |
| 500 | InternalError | Internal server error |
| 503 | ProviderUnavailable | LLM provider unavailable |

---

## 6. WEBHOOKS

### 6.1 Webhook Payload

```json
{
  "event": "task.completed",
  "task_id": "abc123",
  "timestamp": "2025-01-15T10:30:00Z",
  "data": {
    "status": "completed",
    "metrics": {
      "rows_analyzed": 1000,
      "duration_ms": 45000,
      "llm_cost_usd": 0.45
    },
    "results_url": "https://api.feedback-arrow.com/api/v1/tasks/abc123/results"
  }
}
```

### 6.2 Webhook Events

| Event | Description |
|-------|-------------|
| `task.created` | Task was created |
| `task.started` | Task started processing |
| `task.progress` | Task progress update (optional) |
| `task.completed` | Task completed successfully |
| `task.failed` | Task failed with error |
| `task.cancelled` | Task was cancelled |

### 6.3 Webhook Security

```python
# Webhooks are signed with HMAC-SHA256
# Header: X-Webhook-Signature

def verify_webhook(payload: bytes, signature: str, secret: str) -> bool:
    expected = hmac.new(
        secret.encode(),
        payload,
        hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(f"sha256={expected}", signature)
```

---

## 7. SECURITY SCHEMES

### 7.1 API Key Authentication

**Header Format:**
```
Authorization: Bearer fa_live_abc123def456ghi789jkl012mno345
```

**Key Format:**
```
fa_{environment}_{32_char_secret}

Environments:
- fa_live_*  - Production keys
- fa_test_*  - Sandbox/test keys
- fa_dev_*   - Development keys (local only)
```

**OpenAPI Security Scheme:**
```yaml
components:
  securitySchemes:
    ApiKeyAuth:
      type: http
      scheme: bearer
      bearerFormat: "fa_{env}_{secret}"
      description: |
        API key authentication. Keys are prefixed with environment:
        - fa_live_* for production
        - fa_test_* for sandbox

security:
  - ApiKeyAuth: []
```

### 7.2 JWT Bearer Token (Web Sessions)

**Header Format:**
```
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
```

**JWT Claims:**
```json
{
  "sub": "usr_abc123",
  "tenant_id": "ws_xyz789",
  "roles": ["admin"],
  "scopes": ["analyze:create", "results:read"],
  "iat": 1734567890,
  "exp": 1734571490
}
```

**OpenAPI Security Scheme:**
```yaml
components:
  securitySchemes:
    JWTAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
      description: JWT token for web application sessions
```

### 7.3 Authentication Error Responses

**401 Unauthorized:**
```json
{
  "error": {
    "code": "FA-AUTH-001",
    "message": "Authentication required",
    "details": {
      "reason": "missing_authorization_header"
    }
  }
}
```

**401 Invalid Token:**
```json
{
  "error": {
    "code": "FA-AUTH-002",
    "message": "Invalid authentication token",
    "details": {
      "reason": "token_expired",
      "expired_at": "2025-01-15T10:00:00Z"
    }
  }
}
```

**403 Forbidden:**
```json
{
  "error": {
    "code": "FA-AUTH-003",
    "message": "Insufficient permissions",
    "details": {
      "required_permission": "analyze:create",
      "user_permissions": ["results:read"]
    }
  }
}
```

### 7.4 Rate Limit Headers

**Standard Headers:**
```
X-RateLimit-Limit: 100          # Max requests per window
X-RateLimit-Remaining: 95       # Remaining requests
X-RateLimit-Reset: 1734567890   # Window reset timestamp (Unix)
X-RateLimit-Window: 60          # Window size in seconds
```

**When Rate Limited (429):**
```
HTTP/1.1 429 Too Many Requests
Retry-After: 30
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1734567920

{
  "error": {
    "code": "FA-RATE-001",
    "message": "Rate limit exceeded",
    "details": {
      "limit": 100,
      "window_seconds": 60,
      "retry_after_seconds": 30
    }
  }
}
```

---

## 8. ERROR RESPONSE FORMAT

### 8.1 Standard Error Envelope

All error responses follow this structure:

```json
{
  "error": {
    "code": "FA-XXX-NNN",
    "message": "Human-readable error message",
    "details": {},
    "trace_id": "req_abc123xyz"
  }
}
```

**Fields:**
| Field | Type | Description |
|-------|------|-------------|
| `code` | string | Error code (FA-{category}-{number}) |
| `message` | string | Human-readable message (safe to display) |
| `details` | object | Additional context (varies by error) |
| `trace_id` | string | Request trace ID for debugging |

### 8.2 Error Code Registry

**Format:** `FA-{CATEGORY}-{NUMBER}`

| Category | Code Range | Description |
|----------|------------|-------------|
| AUTH | FA-AUTH-001..099 | Authentication/authorization errors |
| RATE | FA-RATE-001..099 | Rate limiting errors |
| VALID | FA-VALID-001..099 | Validation errors |
| QUOTA | FA-QUOTA-001..099 | Quota exceeded errors |
| TASK | FA-TASK-001..099 | Task/job errors |
| PROV | FA-PROV-001..099 | LLM provider errors |
| SYS | FA-SYS-001..099 | System/internal errors |

**Complete Error Codes:**

```yaml
# Authentication
FA-AUTH-001: Authentication required
FA-AUTH-002: Invalid authentication token
FA-AUTH-003: Insufficient permissions
FA-AUTH-004: API key revoked
FA-AUTH-005: API key expired

# Rate Limiting
FA-RATE-001: Rate limit exceeded
FA-RATE-002: Concurrent request limit exceeded

# Validation
FA-VALID-001: Invalid request body
FA-VALID-002: Missing required field
FA-VALID-003: Invalid field value
FA-VALID-004: File format not supported
FA-VALID-005: File too large
FA-VALID-006: Invalid file content

# Quota
FA-QUOTA-001: Monthly analysis quota exceeded
FA-QUOTA-002: Row limit per analysis exceeded
FA-QUOTA-003: Token limit exceeded
FA-QUOTA-004: Storage quota exceeded
FA-QUOTA-005: Concurrent job limit exceeded

# Task
FA-TASK-001: Task not found
FA-TASK-002: Task already completed
FA-TASK-003: Task cancelled
FA-TASK-004: Task failed
FA-TASK-005: Invalid task state transition

# Provider
FA-PROV-001: No providers available
FA-PROV-002: Provider timeout
FA-PROV-003: Provider rate limited
FA-PROV-004: Provider error

# System
FA-SYS-001: Internal server error
FA-SYS-002: Service unavailable
FA-SYS-003: Database error
FA-SYS-004: Storage error
```

### 8.3 Validation Error Format

**Field-Level Errors:**
```json
{
  "error": {
    "code": "FA-VALID-001",
    "message": "Validation failed",
    "details": {
      "errors": [
        {
          "field": "config.language",
          "code": "invalid_value",
          "message": "Language 'xx' is not supported",
          "allowed_values": ["es", "en", "pt"]
        },
        {
          "field": "config.batch_size",
          "code": "out_of_range",
          "message": "Value must be between 1 and 1000",
          "min": 1,
          "max": 1000,
          "actual": 5000
        }
      ]
    },
    "trace_id": "req_abc123xyz"
  }
}
```

### 8.4 HTTP Status Code Mapping

| Status | Usage | Example Code |
|--------|-------|--------------|
| 400 | Validation errors | FA-VALID-* |
| 401 | Missing/invalid auth | FA-AUTH-001, FA-AUTH-002 |
| 403 | Forbidden | FA-AUTH-003 |
| 404 | Resource not found | FA-TASK-001 |
| 409 | Conflict | FA-TASK-002 |
| 413 | Payload too large | FA-VALID-005 |
| 422 | Unprocessable entity | FA-VALID-006 |
| 429 | Rate limited | FA-RATE-001 |
| 500 | Internal error | FA-SYS-001 |
| 502 | Provider error | FA-PROV-002, FA-PROV-004 |
| 503 | Service unavailable | FA-SYS-002 |

### 8.5 Retry-After Header Usage

Include `Retry-After` header for recoverable errors:

```
# Rate limited - retry in 30 seconds
HTTP/1.1 429 Too Many Requests
Retry-After: 30

# Provider busy - retry in 5 seconds
HTTP/1.1 503 Service Unavailable
Retry-After: 5

# Maintenance window - retry at specific time
HTTP/1.1 503 Service Unavailable
Retry-After: Sat, 15 Jan 2025 11:00:00 GMT
```

---

## 9. PAGINATION & FILTERING

### 9.1 Cursor-Based Pagination

**Request:**
```
GET /api/v1/tasks?limit=20&cursor=eyJpZCI6ImFiYzEyMyJ9
```

**Response:**
```json
{
  "data": [...],
  "pagination": {
    "next_cursor": "eyJpZCI6Inh5ejc4OSJ9",
    "prev_cursor": "eyJpZCI6ImRlZjQ1NiJ9",
    "has_more": true,
    "total_count": 150
  }
}
```

**Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `limit` | int | 20 | Items per page (max 100) |
| `cursor` | string | - | Pagination cursor (opaque) |

**Cursor Format (Internal):**
```python
# Cursor encodes last item position
cursor = base64.urlsafe_b64encode(json.dumps({
    "id": "last_item_id",
    "created_at": "2025-01-15T10:00:00Z"
}).encode()).decode()
```

### 9.2 Filter Query Syntax

**Basic Filtering:**
```
GET /api/v1/tasks?status=completed&language=es
```

**Operators:**
```
# Equals (default)
?status=completed

# Not equals
?status[ne]=failed

# Greater than / Less than
?created_at[gt]=2025-01-01T00:00:00Z
?rows_count[lt]=1000

# In list
?status[in]=completed,pending

# Contains (string)
?name[contains]=survey

# Starts with
?name[starts]=Q4
```

**OpenAPI Definition:**
```yaml
parameters:
  - name: status
    in: query
    schema:
      type: string
      enum: [pending, processing, completed, failed, cancelled]
    description: Filter by status

  - name: status[ne]
    in: query
    schema:
      type: string
    description: Filter by status not equal to

  - name: created_at[gt]
    in: query
    schema:
      type: string
      format: date-time
    description: Filter by created_at greater than
```

### 9.3 Sort Parameter Syntax

**Single Sort:**
```
GET /api/v1/tasks?sort=created_at:desc
```

**Multiple Sort:**
```
GET /api/v1/tasks?sort=status:asc,created_at:desc
```

**Format:** `field:direction` where direction is `asc` or `desc`

**Sortable Fields:**
- `created_at` - Creation timestamp
- `updated_at` - Last update timestamp
- `status` - Task status
- `rows_count` - Number of rows analyzed
- `duration_ms` - Analysis duration

### 9.4 Field Selection (Sparse Fieldsets)

**Select Specific Fields:**
```
GET /api/v1/tasks?fields=id,status,created_at
```

**Response:**
```json
{
  "data": [
    {
      "id": "ana_abc123",
      "status": "completed",
      "created_at": "2025-01-15T10:00:00Z"
    }
  ]
}
```

**Nested Field Selection:**
```
GET /api/v1/tasks/ana_abc123?fields=id,status,metrics.rows_count,metrics.duration_ms
```

**Response:**
```json
{
  "id": "ana_abc123",
  "status": "completed",
  "metrics": {
    "rows_count": 1000,
    "duration_ms": 45000
  }
}
```

### 9.5 Combined Example

```
GET /api/v1/tasks
  ?status=completed
  &created_at[gt]=2025-01-01T00:00:00Z
  &sort=created_at:desc
  &fields=id,status,metrics.rows_count
  &limit=50
  &cursor=eyJpZCI6ImFiYzEyMyJ9
```

**Response:**
```json
{
  "data": [
    {
      "id": "ana_xyz789",
      "status": "completed",
      "metrics": {
        "rows_count": 500
      }
    },
    {
      "id": "ana_def456",
      "status": "completed",
      "metrics": {
        "rows_count": 1200
      }
    }
  ],
  "pagination": {
    "next_cursor": "eyJpZCI6ImRlZjQ1NiJ9",
    "has_more": true,
    "total_count": 150
  },
  "meta": {
    "filters_applied": {
      "status": "completed",
      "created_at[gt]": "2025-01-01T00:00:00Z"
    },
    "sort": "created_at:desc",
    "fields": ["id", "status", "metrics.rows_count"]
  }
}
```

---

## SUMMARY

```
INTERFACES:
├── REST API (OpenAPI 3.1)
│   ├── /api/v1/analyze - Submit analysis
│   ├── /api/v1/tasks - Task management
│   ├── /api/v1/providers - LLM providers
│   ├── /api/v1/config - Configuration
│   └── /api/v1/health - Health checks
│
└── CLI (Typer)
    ├── analyze - Run analysis
    ├── validate - Validate files
    ├── providers - Manage providers
    ├── config - Configuration
    └── server - Start API server

IMPLEMENTATION:
- FastAPI for REST API
- Typer + Rich for CLI
- Background task processing
- HMAC-signed webhooks
- Rate limiting
- JWT/API key auth
```

---

**Document Version:** 1.0.0
**Created:** 2025-12-19
**Purpose:** REST API and CLI interface specification
