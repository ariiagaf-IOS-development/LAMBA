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

function Resolve-Swag {
    $candidates = @()
    if ($env:GOBIN) {
        $candidates += Join-Path $env:GOBIN "swag.exe"
    }
    if ($env:USERPROFILE) {
        $candidates += Join-Path $env:USERPROFILE "go\bin\swag.exe"
    }

    $userProfile = [Environment]::GetFolderPath("UserProfile")
    if ($userProfile) {
        $candidates += Join-Path $userProfile "go\bin\swag.exe"
    }

    $go = Resolve-Go
    $goPath = & $go env GOPATH
    if ($goPath) {
        $candidates += Join-Path $goPath "bin\swag.exe"
    }

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            $env:Path = "$(Split-Path -Parent $candidate);$env:Path"
            return $candidate
        }
    }

    $swagCommand = Get-Command swag -ErrorAction SilentlyContinue
    if ($swagCommand) {
        return $swagCommand.Source
    }

    Write-Error "swag CLI is not installed. Run .\scripts\setup.ps1 first."
}

Push-Location $RepoRoot
try {
    $swag = Resolve-Swag
    & $swag init -g main.go -d "cmd/api,internal/handler,internal/domain" -o docs --parseInternal
}
finally {
    Pop-Location
}
