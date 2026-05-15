# Setup

Scripts to set up a minimal system with required tools for CageLab.

Run `bootstrap.sh` to install the required tools and set up the environment.

This installs netbird, nomachine, pixi; pixi installs java and other command line tools needed for Alyx. There is an option to install MATLAB using the very cool mpm (MATLAB Package Manager) if you have a license.

Critical tools:

1. MATLAB R2025b [(see also mpm)](https://www.mathworks.com/products/mpm.html).
1. <https://pixi.sh> as a cross-platform package manager for essential shell tools.
1. [Netbird](https://netbird.io) is used for private wireguard-based VPN communication across control PCs and remote systems.
1. SSH and [NoMachine](https://www.nomachine.com) is used for remote access (+desktop), ideally tunneled through Netbird. Both SSH and NoMachine are setup to use SSH keys only, no passwords.
1. `minio-client` (installed via `pixi`) is used to upload data to the S3 server for Alyx.
1. `Python` with a specific version (V3.11 is needed for MATLAB R2024a) to use awscli. <https://mathworks.com/support/requirements/python-compatibility.html>
1. `Java` is used for matlab-jzmq, and needs to be a specific version (V17 for MATLAB <2025a, V21 for R2025a+). <https://mathworks.com/support/requirements/openjdk.html>

Instructions for how to setup secure remote login with netbird, SSH and NoMachine: <https://cogplatform.github.io/Notes/src/RemoteLogin.html>

