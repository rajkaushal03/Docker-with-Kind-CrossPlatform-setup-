$ErrorActionPreference = "Stop"
if (Test-Path variable:PSNativeCommandUseErrorActionPreference) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$UbuntuContainer = "docker-k8s-ubuntu"
$NginxContainer = "docker-k8s-nginx"
$Images = @(
    "nginx:stable",
    "kindest/node:v1.34.0",
    "ubuntu:24.04"
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

foreach ($Container in @($NginxContainer, $UbuntuContainer)) {
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
