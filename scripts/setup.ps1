$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$SwagVersion = "v1.8.12"

function Resolve-Go {
    $candidates = @()
    if ($env:ProgramFiles) {
        $candidates += Join-Path $env:ProgramFiles "Go\bin\go.exe"
    }
    if ($env:ProgramW6432) {
        $candidates += Join-Path $env:ProgramW6432 "Go\bin\go.exe"
    }
    $candidates += "C:\Program Files\Go\bin\go.exe"

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            $env:Path = "$(Split-Path -Parent $candidate);$env:Path"
            return $candidate
        }
    }

    $goCommand = Get-Command go -ErrorAction SilentlyContinue
    if ($goCommand) {
        return $goCommand.Source
    }

    Write-Error "Go is not installed or is not in PATH. Install Go 1.22+ from https://go.dev/dl/ and run this script again."
}

function Assert-GoVersion {
    param([string] $GoExe)

    $version = & $GoExe env GOVERSION
    if ($version -notmatch '^go(\d+)\.(\d+)') {
        Write-Error "Could not parse Go version: $version"
    }

    $major = [int]$Matches[1]
    $minor = [int]$Matches[2]
    if ($major -lt 1 -or ($major -eq 1 -and $minor -lt 22)) {
        Write-Error "Go 1.22+ is required. Current version is $version."
    }

    Write-Host "Go: $version"
}

Push-Location $RepoRoot
try {
    $go = Resolve-Go
    Assert-GoVersion $go

    $goPath = & $go env GOPATH
    $goBin = Join-Path $goPath "bin"
    New-Item -ItemType Directory -Force -Path $goBin | Out-Null

    if (($env:Path -split ';') -notcontains $goBin) {
        $env:Path = "$goBin;$env:Path"
    }

    Write-Host "Downloading Go module dependencies..."
    & $go mod download

    Write-Host "Installing swag CLI $SwagVersion..."
    & $go install "github.com/swaggo/swag/cmd/swag@$SwagVersion"

    $swagExe = Join-Path $goBin "swag.exe"
    if (!(Test-Path $swagExe)) {
        Write-Error "swag was not found at $swagExe after installation."
    }

    Write-Host ""
    Write-Host "Setup complete."
    Write-Host "Run the backend with:"
    Write-Host "  .\scripts\dev.ps1"
    Write-Host ""
    Write-Host "Swagger UI:"
    Write-Host "  http://localhost:8080/swagger/index.html"
}
finally {
    Pop-Location
}
