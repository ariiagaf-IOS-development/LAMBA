$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot

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

    Write-Error "Go is not installed or is not in PATH. Run .\scripts\setup.ps1 after installing Go 1.22+."
}

Push-Location $RepoRoot
try {
    $go = Resolve-Go

    & $go mod tidy
    & $go test ./...
}
finally {
    Pop-Location
}
