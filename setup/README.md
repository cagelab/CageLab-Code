# Setup for a CageLab System

Scripts to set up a minimal system with required tools for CageLab.

Run `bootstrap.sh` to install the required tools and set up the environment. Once one system is setup, we use [Clonezilla](https://clonezilla.org) to clone it to other systems. A clone is also a quick way to get back to a working state if a system has some sort of system failure.

The bootstrap installs the baseline apt packages for PTB etc. (`zsh`, `git`, `curl` etc.), netbird, nomachine, pixi; pixi installs minio-client, java and other tools needed for Alyx and a nicer terminal experience. There is an option to install MATLAB using the very cool mpm (MATLAB Package Manager) if you have a license.

Critical tools:

1. MATLAB R2025b [(see also mpm)](https://www.mathworks.com/products/mpm.html).
1. <https://pixi.sh> as a cross-platform package manager for essential shell tools.
1. [Netbird](https://netbird.io) is used for private wireguard-based VPN communication across control PCs and remote systems.
1. SSH and [NoMachine](https://www.nomachine.com) is used for remote access (+desktop), ideally tunneled through Netbird. Both SSH and NoMachine are setup to use SSH keys only, no passwords.
1. `minio-client` (installed via `pixi`) is used to upload data to the S3 server for Alyx.
1. `Python` with a specific version (V3.11 is needed for MATLAB R2024a) <https://mathworks.com/support/requirements/python-compatibility.html>
1. `Java` is used for matlab-jzmq, and needs to be a specific version (V21 for R2025a+, V17 for MATLAB <2025a, ). <https://mathworks.com/support/requirements/openjdk.html>

Instructions for how to setup secure remote login with netbird, SSH and NoMachine: <https://cogplatform.github.io/Notes/src/RemoteLogin.html>

Run `makelinks.sh` to keep the various config and script files linked so they are in the path and available.

## For Control PC

MATLAB is needed for the CageLab GUI. In general we install the same toolset (`netbird`, `nomachine`, `pixi`), and for management we use `ansible`. Ansible is cool as we can run a single command across the whole fleet of CageLabs in one go. As `pixi` installs `uv` (a fast Python package manager, that can also install tools globally), we can quickly install ansible: 

```
uv tool install ansible
ansible-galaxy collection install ansible.posix
```


