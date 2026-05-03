$composeFile = Join-Path $PSScriptRoot "docker-compose.yml"
$csvDir = Join-Path $PSScriptRoot "..\pain\data\dummy"
$containerId = docker compose -f $composeFile ps -q pain-db

if (-not $containerId) {
    Write-Error "No running pain-db container found. Start the stack first with .\setup.ps1 -Up"
    exit 1
}

Get-ChildItem $csvDir -Filter *.csv | ForEach-Object {
    $src = $_.FullName
    $dest = "/tmp/$($_.Name)"

    docker cp $src "$containerId:$dest"
    docker exec $containerId psql -U postgres -d pain_db -c "COPY dummy_pain FROM '$dest' CSV HEADER;"
    Write-Host "Imported $($_.Name)"
}