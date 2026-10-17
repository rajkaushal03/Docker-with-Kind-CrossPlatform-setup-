$ErrorActionPreference = "Stop"

function Test-DockerDaemon {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        return $false
    }

    $PreviousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        docker info 2>&1 | Out-Null
        $DockerExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousErrorActionPreference
    }

    return ($DockerExitCode -eq 0)
}

if (Test-DockerDaemon) {
    Write-Output "Docker is installed and its daemon is ready."
    exit 0
}

if ([Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
        [Runtime.InteropServices.OSPlatform]::Windows)) {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            throw "Install Docker Desktop from https://docs.docker.com/desktop/setup/install/windows-install/ (winget is unavailable), then rerun this script."
        }

        winget install --id Docker.DockerDesktop --exact --silent `
            --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) {
            throw "Docker Desktop installation failed. Install it from https://docs.docker.com/desktop/setup/install/windows-install/ and rerun this script."
        }
    }

    $DockerDesktop = Join-Path $env:ProgramFiles "Docker\Docker\Docker Desktop.exe"
    $DockerCliDirectory = Join-Path $env:ProgramFiles "Docker\Docker\resources\bin"
    if ((Test-Path -LiteralPath $DockerCliDirectory) -and
        ($env:Path -notlike "*$DockerCliDirectory*")) {
        $env:Path = "$DockerCliDirectory;$env:Path"
    }
    if (Test-Path -LiteralPath $DockerDesktop) {
        Start-Process -FilePath $DockerDesktop
    }
}
elseif ([Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
        [Runtime.InteropServices.OSPlatform]::OSX)) {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        if (-not (Get-Command brew -ErrorAction SilentlyContinue)) {
            throw "Install Docker Desktop from https://docs.docker.com/desktop/setup/install/mac-install/ or install Homebrew, then rerun this script."
        }

        brew install --cask docker
        if ($LASTEXITCODE -ne 0) {
            throw "Docker Desktop installation failed. See https://docs.docker.com/desktop/setup/install/mac-install/."
        }
    }
    open -a Docker
}
else {
    throw "Automatic installation is supported only for Windows with winget and macOS with Homebrew. Install Docker Engine for your Linux distribution from https://docs.docker.com/engine/install/, then rerun this script."
}

Write-Output "Waiting for the Docker daemon to become ready..."
for ($Attempt = 0; $Attempt -lt 36; $Attempt++) {
    Start-Sleep -Seconds 5
    if (Test-DockerDaemon) {
        Write-Output "Docker is installed and its daemon is ready."
        exit 0
    }
}

throw "Docker was installed, but its daemon is not ready. Start Docker Desktop, wait for it to finish starting, and rerun this script."
