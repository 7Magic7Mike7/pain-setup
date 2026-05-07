# 
param(
    [switch]$Init,
    [switch]$Fill,
    [switch]$Test,
    [switch]$Reset
)

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$composeFile = Join-Path $workspaceRoot "docker-compose.yml"

if (-not (Test-Path $composeFile)) {
    Write-Error "Compose file not found at $composeFile. Run .\setup.ps1 -Up first to generate it."
    exit 1
}

$containerId = docker compose -f $composeFile ps -q pain-db
Write-Host "Found pain-db container with ID: $containerId"

if (-not $containerId) {
    Write-Error "No running pain-db container found. Start the stack first with .\setup.ps1 -Up"
    exit 1
}

if ($Init) {
    Write-Host "Initializing database schema..."
    docker exec -it $containerId psql -U postgres -d pain_db -c "CREATE TABLE DummyPain (id SERIAL PRIMARY KEY, x FLOAT NOT NULL, y FLOAT NOT NULL, value FLOAT, datatype TEXT NOT NULL, painorigin TEXT);"
}
elseif ($Fill) {
    $csvFile = Join-Path $workspaceRoot "pain\data\dummy\db_data.csv"
    $dest = "/tmp/db_data.csv"
    
    Write-Host "Filling database with dummy data..."
    docker cp $csvFile "$($containerId):$dest"
    docker exec $containerId psql -U postgres -d pain_db -c "COPY DummyPain FROM '$dest' CSV HEADER;"
    Write-Host "Imported data from $csvFile into DummyPain table"
}
elseif ($Test) {
    Write-Host "Testing database connection and contents..."
    docker exec -it $containerId psql -U postgres -d pain_db -c "SELECT * FROM DummyPain LIMIT 7;"
}
elseif ($Reset) {
    Write-Host "Resetting database..."
    docker exec -it $containerId psql -U postgres -d pain_db -c "DROP TABLE IF EXISTS DummyPain;"
}
else {
    Write-Host "Usage: .\populate-db.ps1 -Init | -Fill | -Test | -Reset"
    Write-Host "  -Init  : Initialize database schema (run once)"
    Write-Host "  -Fill  : Fill database with dummy data (run after init)"
    Write-Host "  -Test  : Test database connection and contents"
    Write-Host "  -Reset : Reset database by dropping the DummyPain table"
}
