$ErrorActionPreference = "Stop"

$UbuntuContainer = "docker-k8s-ubuntu"
$UbuntuImage = "ubuntu:24.04"
$UbuntuScriptsDirectory = Join-Path (Split-Path -Parent $PSScriptRoot) "ubuntu"
$UbuntuSetupScript = Join-Path $UbuntuScriptsDirectory "ubuntu_setup.sh"

function Invoke-Docker {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $PreviousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & docker @Arguments
        $DockerExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousErrorActionPreference
    }

    if ($DockerExitCode -ne 0) {
        throw "Docker command failed with exit code ${DockerExitCode}: docker $($Arguments -join ' ')"
    }
}

function Test-DockerCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $PreviousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & docker @Arguments 2>&1 | Out-Null
        return ($LASTEXITCODE -eq 0)
    }
    finally {
        $ErrorActionPreference = $PreviousErrorActionPreference
    }
}

function Get-DockerOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $PreviousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $DockerOutput = & docker @Arguments 2>$null
        $DockerExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousErrorActionPreference
    }

    if ($DockerExitCode -ne 0) {
        throw "Docker command failed with exit code ${DockerExitCode}: docker $($Arguments -join ' ')"
    }

    return ($DockerOutput -join [Environment]::NewLine).Trim()
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker CLI was not found. Run .\prerequisite.ps1 first."
}

if (-not (Test-Path -LiteralPath $UbuntuSetupScript)) {
    throw "Shared Ubuntu setup script not found at '$UbuntuSetupScript'. Ensure the ubuntu folder is alongside windows and linux-mac."
}

if (-not (Test-DockerCommand -Arguments @("info"))) {
    throw "Docker daemon is not ready. Run .\prerequisite.ps1 and start Docker Desktop."
}

Invoke-Docker -Arguments @("pull", $UbuntuImage)

if (-not (Test-DockerCommand -Arguments @("container", "inspect", $UbuntuContainer))) {
    Invoke-Docker -Arguments @(
        "run", "--detach",
        "--name", $UbuntuContainer,
        "--label", "com.example.docker-k8s-setup=true",
        "--mount", "type=bind,source=$UbuntuScriptsDirectory,target=/opt/docker-k8s-setup,readonly",
        "--mount", "type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock",
        $UbuntuImage, "sleep", "infinity"
    )
}
else {
    $UbuntuState = Get-DockerOutput -Arguments @(
        "inspect", "--format", "{{.State.Running}}", $UbuntuContainer
    )
    if ($UbuntuState -ne "true") {
        Invoke-Docker -Arguments @("start", $UbuntuContainer)
    }

    if (-not (Test-DockerCommand -Arguments @(
                "exec", $UbuntuContainer, "test", "-f", "/opt/docker-k8s-setup/ubuntu_setup.sh"
            ))) {
        Write-Warning "Existing Ubuntu container is missing the mounted setup script; recreating it with the current ubuntu folder."
        Invoke-Docker -Arguments @("rm", "--force", $UbuntuContainer)
        Invoke-Docker -Arguments @(
            "run", "--detach",
            "--name", $UbuntuContainer,
            "--label", "com.example.docker-k8s-setup=true",
            "--mount", "type=bind,source=$UbuntuScriptsDirectory,target=/opt/docker-k8s-setup,readonly",
            "--mount", "type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock",
            $UbuntuImage, "sleep", "infinity"
        )
    }
}

Invoke-Docker -Arguments @(
    "exec", $UbuntuContainer,
    "bash", "/opt/docker-k8s-setup/ubuntu_setup.sh"
)

Write-Output "Setup complete. Ubuntu is running in '$UbuntuContainer'."
Write-Output "Linkwise UI is running at http://localhost:5000"
