$ErrorActionPreference = "Stop"

$UbuntuScriptsDirectory = Join-Path (Split-Path -Parent $PSScriptRoot) "ubuntu"
$EnvironmentConfig = Join-Path $UbuntuScriptsDirectory "configure\env.conf"

if (-not (Test-Path -LiteralPath $EnvironmentConfig)) {
    throw "Environment configuration file not found: '$EnvironmentConfig'."
}

$Settings = @{}
foreach ($Line in Get-Content -LiteralPath $EnvironmentConfig) {
    if ($Line -match '^\s*([A-Z][A-Z0-9_]*)\s*=\s*(.*?)\s*$') {
        $Settings[$Matches[1]] = $Matches[2].Trim('"').Trim("'")
    }
}

foreach ($Name in @(
        "UBUNTU_IMAGE",
        "UBUNTU_CONTAINER_NAME",
        "UBUNTU_SETUP_FILE_NAME",
        "UBUNTU_CONTAINER_SCRIPTS_PATH",
        "DOCKER_SOCKET_PATH",
        "LINKWISE_HOST_PORT"
    )) {
    if (-not $Settings.ContainsKey($Name) -or [string]::IsNullOrWhiteSpace($Settings[$Name])) {
        throw "Required setting '$Name' is missing from '$EnvironmentConfig'."
    }
}

$UbuntuImage = $Settings["UBUNTU_IMAGE"]
$UbuntuContainer = $Settings["UBUNTU_CONTAINER_NAME"]
$UbuntuSetupFileName = $Settings["UBUNTU_SETUP_FILE_NAME"]
$UbuntuContainerScriptsPath = $Settings["UBUNTU_CONTAINER_SCRIPTS_PATH"]
$DockerSocketPath = $Settings["DOCKER_SOCKET_PATH"]
$UbuntuSetupScript = Join-Path $UbuntuScriptsDirectory $UbuntuSetupFileName
$UbuntuSetupContainerPath = "$UbuntuContainerScriptsPath/$UbuntuSetupFileName"

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
        "--mount", "type=bind,source=$UbuntuScriptsDirectory,target=$UbuntuContainerScriptsPath,readonly",
        "--mount", "type=bind,source=$DockerSocketPath,target=$DockerSocketPath",
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
                "exec", $UbuntuContainer, "test", "-f", $UbuntuSetupContainerPath
            ))) {
        Write-Warning "Existing Ubuntu container is missing the mounted setup script; recreating it with the current ubuntu folder."
        Invoke-Docker -Arguments @("rm", "--force", $UbuntuContainer)
        Invoke-Docker -Arguments @(
            "run", "--detach",
            "--name", $UbuntuContainer,
            "--label", "com.example.docker-k8s-setup=true",
            "--mount", "type=bind,source=$UbuntuScriptsDirectory,target=$UbuntuContainerScriptsPath,readonly",
            "--mount", "type=bind,source=$DockerSocketPath,target=$DockerSocketPath",
            $UbuntuImage, "sleep", "infinity"
        )
    }
}

$ContainerSetupCommand = @'
set -euo pipefail
setup_dir="$(mktemp -d)"
trap 'rm -rf "$setup_dir" /tmp/docker-k8s-setup-bootstrap.sh' EXIT
cp -R "$UBUNTU_CONTAINER_SCRIPTS_PATH/." "$setup_dir/"
find "$setup_dir" -type f \( -name '*.sh' -o -name '*.conf' \) -exec sed -i 's/\r$//' {} +
bash "$setup_dir/$UBUNTU_SETUP_FILE_NAME"
'@

$BootstrapScriptPath = [System.IO.Path]::GetTempFileName()
try {
    [System.IO.File]::WriteAllText(
        $BootstrapScriptPath,
        $ContainerSetupCommand.Replace("`r`n", "`n").Replace("`r", "`n"),
        [System.Text.UTF8Encoding]::new($false)
    )

    Invoke-Docker -Arguments @("cp", $BootstrapScriptPath, "${UbuntuContainer}:/tmp/docker-k8s-setup-bootstrap.sh")
    Invoke-Docker -Arguments @(
        "exec",
        "--env", "UBUNTU_SETUP_FILE_NAME=$UbuntuSetupFileName",
        "--env", "UBUNTU_CONTAINER_SCRIPTS_PATH=$UbuntuContainerScriptsPath",
        $UbuntuContainer,
        "bash", "/tmp/docker-k8s-setup-bootstrap.sh"
    )
}
finally {
    if (Test-Path -LiteralPath $BootstrapScriptPath) {
        Remove-Item -LiteralPath $BootstrapScriptPath -Force
    }
}

Write-Output "Setup complete. Ubuntu is running in '$UbuntuContainer'."
Write-Output "Linkwise UI is running at http://localhost:$($Settings['LINKWISE_HOST_PORT'])"
