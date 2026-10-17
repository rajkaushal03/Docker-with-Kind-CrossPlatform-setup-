# Docker, Ubuntu, kind, and Nginx setup

The project keeps platform-specific scripts in separate folders and the
provisioning script used inside Ubuntu in its own shared folder:

```text
ubuntu/       Shared Ubuntu provisioning script
linux-mac/    Linux and macOS scripts
windows/      Windows PowerShell scripts
```

Run the scripts directly from the folder for your operating system. There is
no root-level launcher.

## Windows

Open PowerShell in the project directory and run:

```powershell
cd .\windows
.\prerequisite.ps1
.\install.ps1
```

To remove the containers and images later:

```powershell
.\cleanup.ps1
```

## Linux

Open a terminal in the project directory and run:

```sh
cd linux-mac
./prerequisite.sh
./install.sh
```

To clean up:

```sh
./cleanup.sh
```

If the shell scripts are not executable, run them with `bash`, for example
`bash ./install.sh`.

## macOS

Use the same scripts as Linux:

```sh
cd linux-mac
./prerequisite.sh
./install.sh
```

To clean up, run `./cleanup.sh`.

## What the scripts do

The prerequisite step checks that Docker and its daemon are available. It can
install Docker on supported systems; some platform installations require
administrator approval or manual startup. Linux users need permission to use
the Docker daemon. Membership in the `docker` group grants root-equivalent
privileges.

The install step creates or starts the `docker-k8s-ubuntu` container from
`ubuntu:24.04`, mounts the shared `ubuntu/` folder and host Docker socket, then
runs `ubuntu/ubuntu_setup.sh` inside the container. That script installs curl,
vim, git, Docker CLI, kind, and other utilities; pulls `kindest/node:v1.34.0`
and `nginx:stable`; and starts Nginx detached with port mapping `3000:80`.

The Ubuntu container remains running after installation. Nginx should be
available at <http://localhost:3000>. Access to the Docker socket grants
control over the host Docker daemon, so do not expose the Ubuntu container to
untrusted users.

Cleanup stops and removes the workflow's Ubuntu and Nginx containers and
removes the Ubuntu, Nginx, and kind node images. It does not uninstall Docker.
If another container still uses one of those images, Docker will refuse to
remove it; remove that dependent container and rerun cleanup.

`system_cleanup` is not included in this iteration.
