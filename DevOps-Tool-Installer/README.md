# Universal Linux DevOps Tool Installer

A single Bash script that installs, updates, and removes the most common DevOps tools on any major Linux distribution. It auto-detects your OS and package manager, always pulls the latest upstream release, and requires no external dependencies beyond `curl` and `bash`.

## Supported Distributions

| Package Manager | Distributions |
|---|---|
| APT | Debian, Ubuntu, Mint, Kali, Pop!_OS |
| DNF / YUM | RHEL, Fedora, Rocky, AlmaLinux, CentOS, Amazon Linux |
| Pacman | Arch, Manjaro, EndeavourOS |
| Zypper | openSUSE, SUSE |
| APK | Alpine |
| XBPS | Void Linux |
| Portage | Gentoo |
| EOPKG | Solus |
| Nix | NixOS |

## Supported Architectures

`amd64` · `arm64` · `arm`

---

## Available Tools

| Tool | Description |
|---|---|
| `common` | curl, git, jq, unzip, make, gcc, and other common utilities |
| `docker` | Docker container engine |
| `docker-compose` | Docker Compose v2 plugin for Docker CLI |
| `kubectl` | Kubernetes CLI |
| `helm` | Kubernetes package manager |
| `kustomize` | Kubernetes configuration customization |
| `k9s` | Kubernetes terminal UI |
| `kind` | Kubernetes in Docker |
| `minikube` | Local Kubernetes cluster |
| `eksctl` | Amazon EKS CLI |
| `argocd` | Argo CD CLI |
| `flux` | Flux CD CLI |
| `kubectx` | kubectl context/namespace switcher |
| `stern` | Multi-pod log tailing |
| `istio` | Istio service mesh CLI (`istioctl`) |
| `oc` | OpenShift CLI |
| `terraform` | HashiCorp Terraform |
| `vault` | HashiCorp Vault |
| `consul` | HashiCorp Consul |
| `packer` | HashiCorp Packer |
| `ansible` | Configuration management / automation |
| `awscli` | AWS CLI v2 |
| `azurecli` | Azure CLI |
| `gcloud` | Google Cloud CLI |
| `trivy` | Container / IaC vulnerability scanner |
| `cosign` | Container image signing and verification |
| `sops` | Secrets encryption |
| `jenkins` | Jenkins CI server |
| `grafana` | Grafana monitoring and visualization |
| `nodejs` | Node.js and npm |
| `go` | Go programming language |
| `java` | OpenJDK 17 |
| `container-tools` | Podman, Buildah, Skopeo |

---

## Prerequisites

- `curl`
- `sudo` (or run as root)
- `gpg` (required for Jenkins and Grafana installs)
- `unzip` (required for Terraform, Vault, Consul, Packer, AWS CLI)

---

## Quick Start

```bash
# Clone or download the script
git clone https://github.com/your-org/scripts.git
cd scripts/DevOps-Tool-Installer

# Make executable
chmod +x install_devops_tools.sh

# Launch the interactive menu
sudo ./install_devops_tools.sh
```

---

## Usage

```
./install_devops_tools.sh [action] [tool...]
```

Running with no arguments launches the interactive menu.

### Actions

| Action | Description |
|---|---|
| `install <tool...>` | Install one or more tools |
| `install-missing` | Detect and install all missing tools interactively |
| `uninstall <tool...>` | Remove one or more tools |
| `update <tool...>` | Update one or more tools to the latest version |
| `update-all` | Update system packages and all supported upstream tools |
| `check` / `status` | Show installation status of all tools |
| `missing` | List only tools that are not installed |
| `list` | List all available tools with descriptions |
| `detect` | Show detected OS, architecture, and package manager |
| `help` / `--help` | Show usage information |

---

## Examples

```bash
# Check the status of every supported tool
sudo ./install_devops_tools.sh check

# List only tools that are not installed
sudo ./install_devops_tools.sh missing

# Install specific tools
sudo ./install_devops_tools.sh install docker docker-compose kubectl helm terraform

# Install all missing tools (prompts for confirmation)
sudo ./install_devops_tools.sh install-missing

# Update specific tools to their latest versions
sudo ./install_devops_tools.sh update kubectl helm trivy

# Update everything
sudo ./install_devops_tools.sh update-all

# Uninstall tools
sudo ./install_devops_tools.sh uninstall terraform vault packer

# Detect OS and package manager
./install_devops_tools.sh detect
```

---

## Interactive Menu

Running the script without arguments opens a menu:

```
1) Install tools
2) Install missing tools
3) Uninstall tools
4) Update tools
5) Update all
6) Check installation status
7) List missing tools
8) List all tools
9) Detect system
10) Exit
```

---

## Notes

### Go
Installed to `/usr/local/go`. The script appends the following to the invoking user's `~/.bashrc` if not already present:

```bash
export PATH="$PATH:/usr/local/go/bin:$HOME/go/bin"
```

Source your shell or open a new terminal after installation:
```bash
source ~/.bashrc
```

### Google Cloud CLI
Installed to `~/google-cloud-sdk` under the invoking user's home directory. PATH is updated automatically in the user's shell rc file by the gcloud `install.sh` script.

### Jenkins
Installs via the official Jenkins APT repository (Debian/Ubuntu only). Both the current (2025) and previous (2023) GPG signing keys are imported from `keyserver.ubuntu.com`.

### Grafana
Installs via the official Grafana APT repository (Debian/Ubuntu only).

### Azure CLI
Automatic installation is supported on Debian/Ubuntu only. For RHEL-family distributions, refer to the [official Azure CLI documentation](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux).

---

## Binary Install Location

All upstream binaries (kubectl, helm, trivy, etc.) are installed to `/usr/local/bin`.
