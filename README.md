# PPP Map Setup
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
docker-compose up -d
docker-compose down
```

## Services
- **pain-server**: Node.js/TypeScript API server with Python 3.11 support
- **pain-db**: PostgreSQL 16 database

## Requirements
- Docker and Docker Compose installed
- Services in sibling folders: `../pain-server`, `../pain-db`
