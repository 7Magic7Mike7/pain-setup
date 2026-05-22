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

# load config variables from db-config.env
$configFile = Join-Path $PSScriptRoot 'db-config.env'
if (-not (Test-Path $configFile)) {
    throw "Missing DB config: $configFile"
}
# load config file and set variables
Get-Content $configFile | ForEach-Object {
    if ($_ -match '^\s*([^=]+)\s*=\s*(.*)\s*$') {
        Set-Variable -Name $matches[1] -Value $matches[2]
    }
}

if ($Init) {
    Write-Host "Initializing database schema..."
    docker exec -it $containerId psql -U postgres -d pain_db -c "CREATE TABLE $TABLE_NAME ($COL_ID SERIAL PRIMARY KEY, $COL_LAT FLOAT NOT NULL, $COL_LNG FLOAT NOT NULL, $COL_VALUE FLOAT, $COL_DATATYPE TEXT NOT NULL, $COL_PAINORIGIN TEXT);"
}
elseif ($Fill) {
    $csvFile = Join-Path $workspaceRoot "pain\data\dummy\db_data.csv"
    $dest = "/tmp/db_data.csv"
    
    Write-Host "Filling database with dummy data..."
    docker cp $csvFile "$($containerId):$dest"
    docker exec $containerId psql -U postgres -d pain_db -c "COPY $TABLE_NAME FROM '$dest' CSV HEADER;"
    Write-Host "Imported data from $csvFile into $TABLE_NAME table"
}
elseif ($Test) {
    Write-Host "Testing database connection and contents..."
    docker exec -it $containerId psql -U postgres -d pain_db -c "SELECT * FROM $TABLE_NAME LIMIT 7;"
}
elseif ($Reset) {
    Write-Host "Resetting database..."
    docker exec -it $containerId psql -U postgres -d pain_db -c "DROP TABLE IF EXISTS $TABLE_NAME;"
}
else {
    Write-Host "Usage: .\populate-db.ps1 -Init | -Fill | -Test | -Reset"
    Write-Host "  -Init  : Initialize database schema (run once)"
    Write-Host "  -Fill  : Fill database with dummy data (run after init)"
    Write-Host "  -Test  : Test database connection and contents"
    Write-Host "  -Reset : Reset database by dropping the $TABLE_NAME table"
}
