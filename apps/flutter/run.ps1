#!/usr/bin/env pwsh
# run.ps1 — Reads .env and passes all values as --dart-define to flutter run
# Usage: .\run.ps1
#        .\run.ps1 --release
#        .\run.ps1 --dart-define=PHASEGUARD_BACKEND_URL=http://192.168.1.10:8000

$envFile = ".env"
$dartDefines = @()

if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        $line = $_.Trim()
        # Skip comments and empty lines
        if ($line -and -not $line.StartsWith("#")) {
            $dartDefines += "--dart-define=$line"
        }
    }
    Write-Host "✅ Loaded .env with $($dartDefines.Count) variables" -ForegroundColor Green
} else {
    Write-Host "⚠️  No .env file found, running without dart-defines" -ForegroundColor Yellow
}

# Pass any extra args from command line
$extraArgs = $args

Write-Host "🚀 Running flutter with backend: $(($dartDefines | Where-Object { $_ -like '*BACKEND*' }) -join ', ')" -ForegroundColor Cyan

flutter run @dartDefines @extraArgs
