$ErrorActionPreference = "Stop"
if (Test-Path variable:PSNativeCommandUseErrorActionPreference) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$UbuntuDirectory = Join-Path (Split-Path -Parent $PSScriptRoot) "ubuntu"
$EnvironmentConfig = Join-Path $UbuntuDirectory "configure\env.conf"
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
        "KIND_NODE_VERSION",
        "LINKWISE_IMAGE_NAME",
        "LINKWISE_IMAGE_TAG",
        "LINKWISE_CONTAINER_NAME"
    )) {
    if (-not $Settings.ContainsKey($Name) -or [string]::IsNullOrWhiteSpace($Settings[$Name])) {
        throw "Required setting '$Name' is missing from '$EnvironmentConfig'."
    }
}

$UbuntuContainer = $Settings["UBUNTU_CONTAINER_NAME"]
$ApplicationContainers = @($Settings["LINKWISE_CONTAINER_NAME"])
$Images = @(
    "$($Settings['LINKWISE_IMAGE_NAME']):$($Settings['LINKWISE_IMAGE_TAG'])",
    "nginx:stable",
    "kindest/node:$($Settings['KIND_NODE_VERSION'])",
    $Settings["UBUNTU_IMAGE"]
)

function Invoke-DockerQuietly {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $PreviousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & docker @Arguments 2>&1 | Out-Null
        return $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousErrorActionPreference
    }
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker CLI was not found. Install or run Docker Desktop before cleanup."
}

if ((Invoke-DockerQuietly -Arguments @("info")) -ne 0) {
    throw "Cannot connect to Docker. Start Docker Desktop/Engine and retry."
}

foreach ($Container in @($ApplicationContainers + $UbuntuContainer)) {
    if ((Invoke-DockerQuietly -Arguments @("container", "inspect", $Container)) -eq 0) {
        if ((Invoke-DockerQuietly -Arguments @("rm", "--force", $Container)) -ne 0) {
            throw "Failed to remove container '$Container'."
        }
        Write-Output "Removed container '$Container'."
    }
    else {
        Write-Output "Container '$Container' is not present."
    }
}

foreach ($Image in $Images) {
    if ((Invoke-DockerQuietly -Arguments @("image", "inspect", $Image)) -eq 0) {
        if ((Invoke-DockerQuietly -Arguments @("image", "rm", $Image)) -ne 0) {
            throw "Failed to remove image '$Image'. It may still be used by another container."
        }
        Write-Output "Removed image '$Image'."
    }
    else {
        Write-Output "Image '$Image' is not present."
    }
}

Write-Output "Cleanup complete. Docker itself was left installed."
