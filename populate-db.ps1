# 
param(
    [switch]$Init,
    [switch]$Fill,
    [switch]$Test,
    [switch]$Reset,
    [switch]$Info
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
    function Create-Table {
        param ($TableName, $Additions)

        docker exec -it $containerId psql -U postgres -d pain_db -c "CREATE TABLE $TableName ($COL_ID SERIAL PRIMARY KEY, $COL_AGGR_ID INTEGER REFERENCES $TableName($COL_ID), $COL_VALUE FLOAT NOT NULL, $COL_CATEGORY TEXT NOT NULL $Additions);"
    }
    Write-Host "Initializing database schema..."
    # create Emotional, Environment, Physical & Socioeconomic Layer Table
    Create-Table $TN_EMO ", $COL_COUNTRY TEXT NOT NULL, $COL_WORD TEXT NOT NULL"
    Create-Table $TN_ENV ", $COL_LAT FLOAT NOT NULL, $COL_LNG FLOAT NOT NULL"
    Create-Table $TN_PHYS ", $COL_LAT FLOAT NOT NULL, $COL_LNG FLOAT NOT NULL"
    Create-Table $TN_SOCIOECO ", $COL_COUNTRY TEXT NOT NULL"
    Create-Table $TN_EXPERIMENTAL ", $COL_LAT FLOAT NOT NULL, $COL_LNG FLOAT NOT NULL"
    Write-Host "Finished initializing!"
}
elseif ($Fill) {
    function Fill-Table {
        param ($TableName, $csvFile, $destFile)

        Write-Host "Filling $TableName with dummy data..."
        docker cp $csvFile "$($containerId):$destFile"
        # copy data from CSV into the table
        docker exec $containerId psql -U postgres -d pain_db -c "COPY $TableName FROM '$destFile' CSV HEADER;"
        # reset the sequence for the table's serial ID column
        docker exec $containerId psql -U postgres -d pain_db -c "SELECT setval(pg_get_serial_sequence('$TableName', '$COL_ID'), COALESCE(MAX($COL_ID), 1)) FROM $TableName;"
        Write-Host "  Imported data from $csvFile into $TableName table"
    }

    #$csvRootFolder = Join-Path $workspaceRoot "pain\data\actual"
    $csvRootFolder = Join-Path $workspaceRoot "pain\data\dummy\data_types"
    Write-Host "Filling database with data..."
    Fill-Table $TN_EMO (Join-Path $csvRootFolder "emo.csv") "/tmp/emo.csv"
    Fill-Table $TN_ENV (Join-Path $csvRootFolder "env.csv") "/tmp/env.csv"
    Fill-Table $TN_PHYS (Join-Path $csvRootFolder "phys.csv") "/tmp/phys.csv"
    Fill-Table $TN_SOCIOECO (Join-Path $csvRootFolder "socioeco.csv") "/tmp/socioeco.csv"
    Fill-Table $TN_EXPERIMENTAL (Join-Path $csvRootFolder "experimental.csv") "/tmp/experimental.csv"
    Write-Host "Finished importing data!"
}
elseif ($Test) {
    Write-Host "Testing database connection and contents..."
    docker exec -it $containerId psql -U postgres -d pain_db -c "SELECT * FROM $TN_ENV LIMIT 7;"
}
elseif ($Reset) {
    function Drop-Table {
        param ($TableName)

        docker exec -it $containerId psql -U postgres -d pain_db -c "DROP TABLE IF EXISTS $TableName;"
    }

    Write-Host "Resetting database..."
    Drop-Table $TN_EMO
    Drop-Table $TN_ENV
    Drop-Table $TN_PHYS
    Drop-Table $TN_SOCIOECO
    Drop-Table $TN_EXPERIMENTAL
}
elseif ($Info) {
    Write-Host "Preparing info for database..."
    Write-Host "TODO"
    docker exec -it $containerId psql -U postgres -d pain_db #"\dt"
}
else {
    Write-Host "Usage: .\populate-db.ps1 -Init | -Fill | -Test | -Reset | -Info"
    Write-Host "  -Init  : Initialize database schema (run once)"
    Write-Host "  -Fill  : Fill database with dummy data (run after init)"
    Write-Host "  -Test  : Test database connection and contents"
    Write-Host "  -Reset : Reset database by dropping all known tables"
    Write-Host "  -Info  : Prints some information about the database's tables"
}
