# Docker, Ubuntu, kind, and Linkwise UI setup

The project keeps platform-specific scripts in separate folders and the
provisioning script used inside Ubuntu in its own shared folder:

```text
env-setup/
├── ubuntu/       Shared Ubuntu setup, configuration, and modules
├── linux-mac/    Linux and macOS scripts
└── windows/      Windows PowerShell scripts
```

Run the scripts directly from the folder for your operating system. There is
no root-level launcher.

## Windows

Open PowerShell in the project directory and run:

```powershell
cd .\env-setup\windows
.\prerequisite.ps1
.\install.ps1
```

If the PowerShell prompt already ends in `\env-setup\windows>`, you are
already in the Windows folder; do not run `cd windows` again.

To remove the containers and images later:

```powershell
.\cleanup.ps1
```

## Linux

Open a terminal in the project directory and run:

```sh
cd env-setup/linux-mac
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
cd env-setup/linux-mac
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

The install step creates or starts the `ubuntu` container from
`ubuntu:24.04`, mounts `env-setup/ubuntu/` and the host Docker socket, then
runs `env-setup/ubuntu/ubuntu_setup.sh` inside the container. If an existing
Ubuntu container was created with an old or missing mount, the installer
recreates it with the current `env-setup/ubuntu/` folder. The setup entry point
loads `env-setup/ubuntu/configure/env.conf` and directly calls modular scripts
from `env-setup/ubuntu/scripts/`. Those scripts install curl, vim, git, Docker
CLI, kind, and other utilities; pull `kindest/node:v1.34.0` and
`nidznd/linkwise-ui:latest`; and start the Linkwise UI detached with port
mapping `5000:80`.

The Ubuntu container remains running after installation. The Linkwise UI should be available at <http://localhost:5000>. Access to the
Docker socket grants control over the host Docker daemon, so do not expose the
Ubuntu container to untrusted users.

Cleanup stops and removes the workflow's Ubuntu and Linkwise UI containers and
removes the Ubuntu, Linkwise UI, and kind node images. It also removes the
previous `nginx` container and `nginx:stable` image if present. It
does not uninstall Docker.
If another container still uses one of those images, Docker will refuse to
remove it; remove that dependent container and rerun cleanup.

`system_cleanup` is not included in this iteration.

## Environment configuration

Ubuntu setup defaults are centralized in
[`env-setup/ubuntu/configure/env.conf`](./env-setup/ubuntu/configure/env.conf).
Edit that file to change the Ubuntu image/container, kind and Kubernetes node
versions, Linkwise image/tag/container/ports, or the application build stack
versions (Node.js, React, Vite, React plugin, and Firebase SDK). The Ubuntu
setup entry point and host installers load those shared settings. Application
stack versions document the versions used to build the prebuilt Linkwise UI
image; they do not install Node.js or rebuild that image.
