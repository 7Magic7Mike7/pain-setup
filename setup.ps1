# PowerShell script to set up and run the PPP Map project with Docker Compose
# This script copies the docker-compose.yml to the workspace root and runs it

param(
    [switch]$Up,
    [switch]$Down,
    [switch]$Build
)

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$composeFile = Join-Path $PSScriptRoot "docker-compose.yml"
$targetCompose = Join-Path $workspaceRoot "docker-compose.yml"

function Copy-ComposeFile {
    Copy-Item $composeFile $targetCompose -Force
    Write-Host "Copied docker-compose.yml to workspace root"
}

function Run-DockerCompose {
    param([string]$Command)
    Push-Location $workspaceRoot
    try {
        & docker-compose $Command.Split()
    } finally {
        Pop-Location
    }
}

if ($Up) {
    Copy-ComposeFile
    Run-DockerCompose "up -d"
} elseif ($Down) {
    Copy-ComposeFile
    Run-DockerCompose "down"
} elseif ($Build) {
    Copy-ComposeFile
    Run-DockerCompose "build"
} else {
    Write-Host "Usage: .\setup.ps1 -Up | -Down | -Build"
    Write-Host "  -Up    : Copy compose file and start services"
    Write-Host "  -Down  : Copy compose file and stop services"
    Write-Host "  -Build : Copy compose file and build services"
}