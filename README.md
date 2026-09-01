# PPP Map Setup

Last Updated: 2026-09-01
Version: 1.0

This repository contains the Docker Compose configuration for the entire PPP Map project.
It allows versioning the orchestration setup separately from individual services.

## Usage

### PowerShell (Windows)
```powershell
# Start all services
.\setup.ps1 -Up

# Stop all services
.\setup.ps1 -Down

# Build services
.\setup.ps1 -Build
```

### Manual (any OS)
```bash
# Copy compose file to workspace root
cp docker-compose.yml ../

# Then run from workspace root
docker compose up -d
docker compose down
```

## Services
- **pain-server**: Node.js/TypeScript API server with Python 3.11 support
- **pain-db**: PostgreSQL 16 database
- **pain-message**: Private Python sidecar that returns a survey paragraph and coordinate

`pain-message` listens on container port `7246` and is not published to the host. `pain-server`
reaches it over the Compose network at `http://pain-message:7246`.

## Requirements
- Docker and Docker Compose installed
- Application repositories in sibling folders: `../pain-server`, `../pain-db`, `../pain-frontend`
- Private `pain-message-based-on-survey` repository checked out beside the workspace root

The message service adds no database, volume, or migration. Its repository must be available to
the Docker build context before building the stack.
