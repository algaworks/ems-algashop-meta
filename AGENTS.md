# AGENTS.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Structure

This is a **monorepo with microservices as Git submodules**. Each microservice lives in its own repo and is referenced here via submodules.

```
algashop/
├── microservices/
│   ├── authorization-server/   OAuth2 Authorization Server (port 8081, PostgreSQL)
│   ├── ordering/               Order Management (port 8080, PostgreSQL)
│   ├── billing/                Billing Service (port 8082, PostgreSQL)
│   ├── billing-scheduler/      Scheduled billing tasks (PostgreSQL)
│   └── product-catalog/        Product Catalog (port 8083, MongoDB)
├── etc/
│   ├── postgres/               PostgreSQL init scripts (creates DBs)
│   ├── aws/                    LocalStack S3 init
│   ├── wiremock/               WireMock stub mappings
│   └── hostnames               Entries to add to /etc/hosts
├── docker-compose.yml
├── docker-compose.tools.yml    Infrastructure services (Postgres, MongoDB, Redis, etc.)
└── docker-compose.services.yml Microservice containers
```

## Technology Stack

- **Java 25**, Gradle 9.2.1, Spring Boot 4.0.x, Spring Cloud 2025.x
- **PostgreSQL** services: ordering, billing, billing-scheduler, authorization-server
- **MongoDB** (replica set): product-catalog
- **Redis**: caching and session store (ordering, product-catalog)
- **Spring Security OAuth2**: authorization-server is the auth provider; all others are resource servers
- **Flyway**: database migrations (runs on startup)
- **Lombok**, ModelMapper, TSID for IDs
- **Spring Cloud Contract**: contract-driven testing
- **TestContainers**: integration test databases
- **WireMock**: external HTTP API mocking

## Build Commands

All commands run from within the individual microservice directory:

```bash
cd microservices/<service-name>

./gradlew build          # compile + test
./gradlew bootJar        # build runnable JAR only
./gradlew dockerBuild    # build multi-platform Docker image (linux/arm64,linux/amd64)
```

## Test Commands

```bash
cd microservices/<service-name>

./gradlew test              # unit tests (*Test.java)
./gradlew integrationTest   # integration tests (*IT.java), uses TestContainers
./gradlew contractTest      # Spring Cloud Contract verifier tests
./gradlew check             # unit + integration + contract tests
```

To run a single test class:
```bash
./gradlew test --tests "com.algaworks.algashop.<service>.<ClassName>"
```

## Running Locally with Docker

```bash
# Start all infrastructure (Postgres, MongoDB, Redis, WireMock, LocalStack, FastPay)
docker compose -f docker-compose.tools.yml up -d

# Start microservices
docker compose -f docker-compose.services.yml up -d

# Or start everything together
docker compose up -d
```

**Required /etc/hosts entries** (see `etc/hostnames`):
```
127.0.0.1 algashop-mongodb-1 algashop-mongodb-2 algashop-mongodb-3
127.0.0.1 algashop-localstack s3.algashop-localstack algashop-product-image.algashop-localstack
127.0.0.1 authorization-server
```

## Architecture

### Hexagonal Architecture
Services (especially `ordering`) follow hexagonal architecture with explicit adapter layers:
- `infrastructure/adapters/in/` — inbound adapters (REST controllers)
- `infrastructure/adapters/out/` — outbound adapters (database, HTTP clients)
- Domain layer contains entities and use cases, independent of frameworks

### Inter-Service HTTP Communication
- **Ordering → Product Catalog**: `GET /api/v1/products/{productId}` via `ProductCatalogAPIClient`
- **Ordering → RapiDex** (shipping): `RapiDexAPIClient`
- All HTTP clients have resilience wrappers (circuit breaker via Spring Cloud Circuit Breaker + Retry)

### OAuth2 Security Model
- `authorization-server` issues tokens (Spring Authorization Server)
- All services validate tokens as OAuth2 Resource Servers
- `ordering` is also an OAuth2 Client (calls other services with client credentials)

### Spring Profiles
Each service uses profile layering:
- `base` — common config
- `development-env` — local dev settings
- `docker-env` — Docker Compose settings (activated by `SPRING_PROFILES_ACTIVE=docker`)
- `production-env` — production settings
- `test` — test overrides

### Infrastructure Services (docker-compose.tools.yml)
| Service | Port | Purpose |
|---------|------|---------|
| algashop-postgres | 5432 | Shared PostgreSQL for all relational services |
| algashop-mongodb-{1,2,3} | 27017–27019 | MongoDB replica set for product-catalog |
| algashop-redis | 6379 | Cache + session (password: `algashop`) |
| wiremock | 8787 | External API mocking |
| algashop-localstack | 4566 | AWS S3 emulation for product images |
| fastpay | 9995 | Payment provider mock |

## Working with Submodules

Each microservice is an independent Git repo. When modifying service code, commits go into the submodule repo. After committing there, update the submodule reference from the monorepo root.

```bash
# Initialize submodules after cloning
git submodule update --init --recursive

# Update a specific submodule to its latest commit
git submodule update --remote microservices/<service-name>
```


<!-- rtk-instructions v2 -->
# RTK (Rust Token Killer) - Token-Optimized Commands

## Golden Rule

**Always prefix commands with `rtk`**. If RTK has a dedicated filter, it uses it. If not, it passes through unchanged. This means RTK is always safe to use.

**Important**: Even in command chains with `&&`, use `rtk`:
```bash
# ❌ Wrong
git add . && git commit -m "msg" && git push

# ✅ Correct
rtk git add . && rtk git commit -m "msg" && rtk git push
```

## RTK Commands by Workflow

### Build & Compile (80-90% savings)
```bash
rtk cargo build         # Cargo build output
rtk cargo check         # Cargo check output
rtk cargo clippy        # Clippy warnings grouped by file (80%)
rtk tsc                 # TypeScript errors grouped by file/code (83%)
rtk lint                # ESLint/Biome violations grouped (84%)
rtk prettier --check    # Files needing format only (70%)
rtk next build          # Next.js build with route metrics (87%)
```

### Test (60-99% savings)
```bash
rtk cargo test          # Cargo test failures only (90%)
rtk go test             # Go test failures only (90%)
rtk jest                # Jest failures only (99.5%)
rtk vitest              # Vitest failures only (99.5%)
rtk playwright test     # Playwright failures only (94%)
rtk pytest              # Python test failures only (90%)
rtk rake test           # Ruby test failures only (90%)
rtk rspec               # RSpec test failures only (60%)
rtk test <cmd>          # Generic test wrapper - failures only
```

### Git (59-80% savings)
```bash
rtk git status          # Compact status
rtk git log             # Compact log (works with all git flags)
rtk git diff            # Compact diff (80%)
rtk git show            # Compact show (80%)
rtk git add             # Ultra-compact confirmations (59%)
rtk git commit          # Ultra-compact confirmations (59%)
rtk git push            # Ultra-compact confirmations
rtk git pull            # Ultra-compact confirmations
rtk git branch          # Compact branch list
rtk git fetch           # Compact fetch
rtk git stash           # Compact stash
rtk git worktree        # Compact worktree
```

Note: Git passthrough works for ALL subcommands, even those not explicitly listed.

### GitHub (26-87% savings)
```bash
rtk gh pr view <num>    # Compact PR view (87%)
rtk gh pr checks        # Compact PR checks (79%)
rtk gh run list         # Compact workflow runs (82%)
rtk gh issue list       # Compact issue list (80%)
rtk gh api              # Compact API responses (26%)
```

### JavaScript/TypeScript Tooling (70-90% savings)
```bash
rtk pnpm list           # Compact dependency tree (70%)
rtk pnpm outdated       # Compact outdated packages (80%)
rtk pnpm install        # Compact install output (90%)
rtk npm run <script>    # Compact npm script output
rtk npx <cmd>           # Compact npx command output
rtk prisma              # Prisma without ASCII art (88%)
```

### Files & Search (60-75% savings)
```bash
rtk ls <path>           # Tree format, compact (65%)
rtk read <file>         # Code reading with filtering (60%)
rtk grep <pattern>      # Search grouped by file (75%)
rtk find <pattern>      # Find grouped by directory (70%)
```

### Analysis & Debug (70-90% savings)
```bash
rtk err <cmd>           # Filter errors only from any command
rtk log <file>          # Deduplicated logs with counts
rtk json <file>         # JSON structure without values
rtk deps                # Dependency overview
rtk env                 # Environment variables compact
rtk summary <cmd>       # Smart summary of command output
rtk diff                # Ultra-compact diffs
```

### Infrastructure (85% savings)
```bash
rtk docker ps           # Compact container list
rtk docker images       # Compact image list
rtk docker logs <c>     # Deduplicated logs
rtk kubectl get         # Compact resource list
rtk kubectl logs        # Deduplicated pod logs
```

### Network (65-70% savings)
```bash
rtk curl <url>          # Compact HTTP responses (70%)
rtk wget <url>          # Compact download output (65%)
```

### Meta Commands
```bash
rtk gain                # View token savings statistics
rtk gain --history      # View command history with savings
rtk discover            # Analyze Claude Code sessions for missed RTK usage
rtk proxy <cmd>         # Run command without filtering (for debugging)
rtk init                # Add RTK instructions to CLAUDE.md
rtk init --global       # Add RTK to ~/.claude/CLAUDE.md
```

## Token Savings Overview

| Category | Commands | Typical Savings |
|----------|----------|-----------------|
| Tests | vitest, playwright, cargo test | 90-99% |
| Build | next, tsc, lint, prettier | 70-87% |
| Git | status, log, diff, add, commit | 59-80% |
| GitHub | gh pr, gh run, gh issue | 26-87% |
| Package Managers | pnpm, npm, npx | 70-90% |
| Files | ls, read, grep, find | 60-75% |
| Infrastructure | docker, kubectl | 85% |
| Network | curl, wget | 65-70% |

Overall average: **60-90% token reduction** on common development operations.
<!-- /rtk-instructions -->