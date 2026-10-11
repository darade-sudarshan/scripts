#!/usr/bin/env bash

###############################################################################
# Universal Linux DevOps Tool Installer
#
# Supports:
#   Debian/Ubuntu/Mint/Kali/Pop!_OS       - APT
#   RHEL/Fedora/Rocky/Alma/CentOS/Amazon  - DNF/YUM
#   Arch/Manjaro/EndeavourOS              - Pacman
#   openSUSE/SUSE                         - Zypper
#   Alpine                                - APK
#   Void                                  - XBPS
#   Gentoo                                - Portage
#   Solus                                 - EOPKG
#   NixOS                                 - Nix
#
# Actions:
#   install       Install selected tools
#   uninstall     Uninstall selected tools
#   update        Update selected tools
#   update-all    Update all installed tools
#   list          List available tools
#   detect        Show OS/package-manager information
#
# Usage:
#   sudo ./devops-tools.sh
#   ./devops-tools.sh install docker kubectl helm terraform
#   ./devops-tools.sh update-all
#   ./devops-tools.sh uninstall kubectl
#
###############################################################################

set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
BIN_DIR="/usr/local/bin"
TMP_DIR="$(mktemp -d)"

trap 'rm -rf "$TMP_DIR"' EXIT

###############################################################################
# Colors
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

###############################################################################
# Logging
###############################################################################

info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

warning() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

die() {
    error "$*"
    exit 1
}

###############################################################################
# Root / sudo
###############################################################################

if [[ $EUID -eq 0 ]]; then
    SUDO=""
else
    command -v sudo >/dev/null 2>&1 ||
        die "sudo is required. Run as root or install sudo."

    SUDO="sudo"
fi

###############################################################################
# Architecture
###############################################################################

ARCH_RAW="$(uname -m)"

case "$ARCH_RAW" in
    x86_64|amd64)
        ARCH="amd64"
        ;;

    aarch64|arm64)
        ARCH="arm64"
        ;;

    armv7l|armv7)
        ARCH="arm"
        ;;

    *)
        die "Unsupported CPU architecture: $ARCH_RAW"
        ;;
esac

###############################################################################
# OS Detection
###############################################################################

detect_os() {

    [[ -f /etc/os-release ]] ||
        die "/etc/os-release not found. Unsupported Linux system."

    # shellcheck disable=SC1091
    source /etc/os-release

    OS_ID="${ID:-unknown}"
    OS_VERSION="${VERSION_ID:-unknown}"
    OS_NAME="${PRETTY_NAME:-$OS_ID}"

    info "Operating system : $OS_NAME"
    info "Architecture     : $ARCH_RAW"

    detect_package_manager
}

###############################################################################
# Package manager detection
###############################################################################

detect_package_manager() {

    if command -v apt-get >/dev/null 2>&1; then
        PKG_MANAGER="apt"

    elif command -v dnf >/dev/null 2>&1; then
        PKG_MANAGER="dnf"

    elif command -v yum >/dev/null 2>&1; then
        PKG_MANAGER="yum"

    elif command -v pacman >/dev/null 2>&1; then
        PKG_MANAGER="pacman"

    elif command -v zypper >/dev/null 2>&1; then
        PKG_MANAGER="zypper"

    elif command -v apk >/dev/null 2>&1; then
        PKG_MANAGER="apk"

    elif command -v xbps-install >/dev/null 2>&1; then
        PKG_MANAGER="xbps"

    elif command -v emerge >/dev/null 2>&1; then
        PKG_MANAGER="emerge"

    elif command -v eopkg >/dev/null 2>&1; then
        PKG_MANAGER="eopkg"

    elif command -v nix-env >/dev/null 2>&1; then
        PKG_MANAGER="nix"

    elif command -v brew >/dev/null 2>&1; then
        PKG_MANAGER="brew"

    else
        PKG_MANAGER="none"
    fi

    info "Package manager  : $PKG_MANAGER"
}

###############################################################################
# Package update
###############################################################################

pkg_update() {

    case "$PKG_MANAGER" in

        apt)
            $SUDO apt-get update
            ;;

        dnf)
            $SUDO dnf makecache
            ;;

        yum)
            $SUDO yum makecache
            ;;

        pacman)
            $SUDO pacman -Sy --noconfirm
            ;;

        zypper)
            $SUDO zypper refresh
            ;;

        apk)
            $SUDO apk update
            ;;

        xbps)
            $SUDO xbps-install -S
            ;;

        emerge)
            $SUDO emerge --sync
            ;;

        eopkg)
            $SUDO eopkg update-repo
            ;;

        nix)
            nix-channel --update 2>/dev/null || true
            ;;

        brew)
            brew update
            ;;

        none)
            warning "No supported package manager."
            ;;

        *)
            warning "Unknown package manager: $PKG_MANAGER"
            ;;
    esac
}

###############################################################################
# Package install
###############################################################################

pkg_install() {

    [[ $# -gt 0 ]] || return 0

    case "$PKG_MANAGER" in

        apt)
            $SUDO apt-get install -y "$@"
            ;;

        dnf)
            $SUDO dnf install -y "$@"
            ;;

        yum)
            $SUDO yum install -y "$@"
            ;;

        pacman)
            $SUDO pacman -S --needed --noconfirm "$@"
            ;;

        zypper)
            $SUDO zypper --non-interactive install "$@"
            ;;

        apk)
            $SUDO apk add "$@"
            ;;

        xbps)
            $SUDO xbps-install -y "$@"
            ;;

        emerge)
            $SUDO emerge --ask=n "$@"
            ;;

        eopkg)
            $SUDO eopkg install -y "$@"
            ;;

        nix)
            nix profile install "$@"
            ;;

        brew)
            brew install "$@"
            ;;

        none)
            die "No supported package manager."
            ;;

        *)
            die "Unsupported package manager: $PKG_MANAGER"
            ;;
    esac
}

###############################################################################
# Package uninstall
###############################################################################

pkg_remove() {

    [[ $# -gt 0 ]] || return 0

    case "$PKG_MANAGER" in

        apt)
            $SUDO apt-get remove -y "$@" || true
            ;;

        dnf)
            $SUDO dnf remove -y "$@" || true
            ;;

        yum)
            $SUDO yum remove -y "$@" || true
            ;;

        pacman)
            $SUDO pacman -Rns --noconfirm "$@" || true
            ;;

        zypper)
            $SUDO zypper --non-interactive remove "$@" || true
            ;;

        apk)
            $SUDO apk del "$@" || true
            ;;

        xbps)
            $SUDO xbps-remove -y "$@" || true
            ;;

        emerge)
            $SUDO emerge --unmerge "$@" || true
            ;;

        eopkg)
            $SUDO eopkg remove -y "$@" || true
            ;;

        nix)
            nix profile remove "$@" || true
            ;;

        brew)
            brew uninstall "$@" || true
            ;;

        none)
            warning "No package manager available."
            ;;

        *)
            warning "Unsupported package manager."
            ;;
    esac
}

###############################################################################
# Package upgrade
###############################################################################

pkg_upgrade() {

    case "$PKG_MANAGER" in

        apt)
            $SUDO apt-get update
            $SUDO apt-get upgrade -y
            ;;

        dnf)
            $SUDO dnf upgrade -y
            ;;

        yum)
            $SUDO yum update -y
            ;;

        pacman)
            $SUDO pacman -Syu --noconfirm
            ;;

        zypper)
            $SUDO zypper update -y
            ;;

        apk)
            $SUDO apk upgrade
            ;;

        xbps)
            $SUDO xbps-install -Su
            ;;

        emerge)
            $SUDO emerge --ask=n --update --deep --newuse @world
            ;;

        eopkg)
            $SUDO eopkg upgrade -y
            ;;

        nix)
            nix-channel --update
            nix-env -u
            ;;

        brew)
            brew update
            brew upgrade
            ;;

        *)
            warning "No package-manager upgrade available."
            ;;
    esac
}

###############################################################################
# Download helper
###############################################################################

download() {

    local url="$1"
    local output="$2"

    info "Downloading: $url"

    curl \
        --fail \
        --location \
        --retry 3 \
        --retry-delay 2 \
        --silent \
        --show-error \
        "$url" \
        -o "$output"
}

###############################################################################
# GitHub latest release API
###############################################################################

github_latest_tag() {

    local repo="$1"

    curl \
        --fail \
        --silent \
        --show-error \
        "https://api.github.com/repos/${repo}/releases/latest" |
        sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' |
        head -n1
}

###############################################################################
# Install binary from GitHub release asset
###############################################################################

install_github_binary() {

    local repo="$1"
    local asset_pattern="$2"
    local binary_name="$3"

    local tag
    local version
    local url
    local archive
    local workdir

    tag="$(github_latest_tag "$repo")"

    [[ -n "$tag" ]] ||
        die "Unable to determine latest release for $repo"

    version="${tag#v}"

    info "Latest $repo version: $version"

    case "$ARCH" in
        amd64)
            ;;
        arm64)
            ;;
        arm)
            ;;
    esac

    url="$(curl \
        --fail \
        --silent \
        --show-error \
        "https://api.github.com/repos/${repo}/releases/latest" |
        grep '"browser_download_url"' |
        sed 's/.*"browser_download_url": *"\([^"]*\)".*/\1/' |
        grep -E "$asset_pattern" |
        head -n1 || true)"

    [[ -n "$url" ]] ||
        die "Could not find release asset matching '$asset_pattern' for $repo"

    archive="$TMP_DIR/$(basename "$url")"
    workdir="$TMP_DIR/${binary_name}"

    rm -rf "$workdir"
    mkdir -p "$workdir"

    download "$url" "$archive"

    case "$archive" in

        *.tar.gz|*.tgz)
            tar -xzf "$archive" -C "$workdir"
            ;;

        *.tar.xz)
            tar -xJf "$archive" -C "$workdir"
            ;;

        *.zip)
            unzip -q "$archive" -d "$workdir"
            ;;

        *)
            cp "$archive" "$workdir/$binary_name"
            ;;
    esac

    local binary

    binary="$(find "$workdir" \
        -type f \
        -name "$binary_name" \
        -perm -u+x \
        -print -quit || true)"

    if [[ -z "$binary" ]]; then
        binary="$(find "$workdir" \
            -type f \
            -name "$binary_name" \
            -print -quit || true)"
    fi

    [[ -n "$binary" ]] ||
        die "Could not find binary '$binary_name' in release archive."

    $SUDO install -m 0755 "$binary" "$BIN_DIR/$binary_name"

    success "$binary_name $version installed."
}

###############################################################################
# Docker
###############################################################################

install_docker() {

    if command -v docker >/dev/null 2>&1; then
        info "Docker already installed."
        docker --version
        return
    fi

    case "$PKG_MANAGER" in

        apt)
            $SUDO apt-get update
            pkg_install docker.io
            ;;

        dnf|yum)
            pkg_install docker
            ;;

        pacman)
            pkg_install docker
            ;;

        zypper)
            pkg_install docker
            ;;

        apk)
            pkg_install docker
            ;;

        *)
            die "Docker installation is not supported on $PKG_MANAGER."
            ;;
    esac

    $SUDO systemctl enable --now docker 2>/dev/null || true

    success "Docker installed."
}

uninstall_docker() {

    case "$PKG_MANAGER" in
        apt|dnf|yum|pacman|zypper|apk)
            pkg_remove docker docker-ce docker.io
            ;;
        *)
            warning "Remove Docker manually on this distribution."
            ;;
    esac
}

###############################################################################
# Docker Compose
###############################################################################

install_docker_compose() {

    local version
    local asset_arch
    local plugin_dir="/usr/local/lib/docker/cli-plugins"
    local url

    case "$ARCH" in
        amd64) asset_arch="x86_64" ;;
        arm64) asset_arch="aarch64" ;;
        arm) asset_arch="armv7" ;;
    esac

    version="$(github_latest_tag docker/compose)"
    [[ -n "$version" ]] || die "Unable to determine latest Docker Compose release."

    url="https://github.com/docker/compose/releases/download/${version}/docker-compose-linux-${asset_arch}"
    download "$url" "$TMP_DIR/docker-compose"

    $SUDO install -d -m 0755 "$plugin_dir"
    $SUDO install -m 0755 "$TMP_DIR/docker-compose" "$plugin_dir/docker-compose"

    success "Docker Compose $version installed."
}

uninstall_docker_compose() {
    $SUDO rm -f /usr/local/lib/docker/cli-plugins/docker-compose
}

###############################################################################
# Kubernetes tools
###############################################################################

install_kubectl() {

    local version
    local url

    version="$(
        curl -fsSL \
        https://dl.k8s.io/release/stable.txt
    )"

    url="https://dl.k8s.io/release/${version}/bin/linux/${ARCH}/kubectl"

    download "$url" "$TMP_DIR/kubectl"

    $SUDO install -m 0755 "$TMP_DIR/kubectl" "$BIN_DIR/kubectl"

    success "kubectl $version installed."
}

uninstall_kubectl() {
    remove_binary kubectl
}

install_helm() {

    local version
    local url

    version="$(github_latest_tag helm/helm)"
    url="https://get.helm.sh/helm-${version}-linux-${ARCH}.tar.gz"

    download "$url" "$TMP_DIR/helm.tar.gz"

    tar -xzf "$TMP_DIR/helm.tar.gz" -C "$TMP_DIR"

    $SUDO install \
        -m 0755 \
        "$TMP_DIR/linux-${ARCH}/helm" \
        "$BIN_DIR/helm"

    success "Helm $version installed."
}

uninstall_helm() {
    remove_binary helm
}

install_kustomize() {

    local tag
    local version
    local url

    tag="$(github_latest_tag kubernetes-sigs/kustomize)"

    # tag format is "kustomize/vX.Y.Z" — strip the prefix to get "vX.Y.Z"
    version="${tag#kustomize/}"

    url="https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${version}/kustomize_${version}_linux_${ARCH}.tar.gz"

    download "$url" "$TMP_DIR/kustomize.tar.gz"

    tar -xzf "$TMP_DIR/kustomize.tar.gz" -C "$TMP_DIR"

    $SUDO install \
        -m 0755 \
        "$TMP_DIR/kustomize" \
        "$BIN_DIR/kustomize"

    success "Kustomize $version installed."
}

uninstall_kustomize() {
    remove_binary kustomize
}

###############################################################################
# Terraform
###############################################################################

install_terraform() {

    local version
    local url

    version="$(github_latest_tag hashicorp/terraform)"
    version="${version#v}"

    url="https://releases.hashicorp.com/terraform/${version}/terraform_${version}_linux_${ARCH}.zip"

    download "$url" "$TMP_DIR/terraform.zip"

    unzip -oq "$TMP_DIR/terraform.zip" -d "$TMP_DIR/terraform"

    $SUDO install \
        -m 0755 \
        "$TMP_DIR/terraform/terraform" \
        "$BIN_DIR/terraform"

    success "Terraform $version installed."
}

uninstall_terraform() {
    remove_binary terraform
}

###############################################################################
# Hashicorp tools
###############################################################################

install_vault() {

    local version
    local url

    version="$(github_latest_tag hashicorp/vault)"
    version="${version#v}"

    url="https://releases.hashicorp.com/vault/${version}/vault_${version}_linux_${ARCH}.zip"

    download "$url" "$TMP_DIR/vault.zip"

    unzip -oq "$TMP_DIR/vault.zip" -d "$TMP_DIR/vault"

    $SUDO install \
        -m 0755 \
        "$TMP_DIR/vault/vault" \
        "$BIN_DIR/vault"

    success "Vault $version installed."
}

uninstall_vault() {
    remove_binary vault
}

install_consul() {

    local version
    local url

    version="$(github_latest_tag hashicorp/consul)"
    version="${version#v}"

    url="https://releases.hashicorp.com/consul/${version}/consul_${version}_linux_${ARCH}.zip"

    download "$url" "$TMP_DIR/consul.zip"

    unzip -oq "$TMP_DIR/consul.zip" -d "$TMP_DIR/consul"

    $SUDO install \
        -m 0755 \
        "$TMP_DIR/consul/consul" \
        "$BIN_DIR/consul"

    success "Consul $version installed."
}

uninstall_consul() {
    remove_binary consul
}

install_packer() {

    local version
    local url

    version="$(github_latest_tag hashicorp/packer)"
    version="${version#v}"

    url="https://releases.hashicorp.com/packer/${version}/packer_${version}_linux_${ARCH}.zip"

    download "$url" "$TMP_DIR/packer.zip"

    unzip -oq "$TMP_DIR/packer.zip" -d "$TMP_DIR/packer"

    $SUDO install \
        -m 0755 \
        "$TMP_DIR/packer/packer" \
        "$BIN_DIR/packer"

    success "Packer $version installed."
}

uninstall_packer() {
    remove_binary packer
}

###############################################################################
# GitHub / Kubernetes ecosystem
###############################################################################

install_k9s() {

    install_github_binary \
        "derailed/k9s" \
        "Linux_${ARCH}\\.tar\\.gz" \
        "k9s"
}

uninstall_k9s() {
    remove_binary k9s
}

install_argocd() {

    local version
    local url

    version="$(github_latest_tag argoproj/argo-cd)"

    url="https://github.com/argoproj/argo-cd/releases/download/${version}/argocd-linux-${ARCH}"

    download "$url" "$TMP_DIR/argocd"

    $SUDO install \
        -m 0755 \
        "$TMP_DIR/argocd" \
        "$BIN_DIR/argocd"

    success "Argo CD $version installed."
}

uninstall_argocd() {
    remove_binary argocd
}

install_flux() {

    local version
    local url

    version="$(github_latest_tag fluxcd/flux2)"

    url="https://github.com/fluxcd/flux2/releases/download/${version}/flux_${version#v}_linux_${ARCH}.tar.gz"

    download "$url" "$TMP_DIR/flux.tar.gz"

    tar -xzf "$TMP_DIR/flux.tar.gz" -C "$TMP_DIR"

    local binary

    binary="$(find "$TMP_DIR" -type f -name flux -print -quit)"

    [[ -n "$binary" ]] ||
        die "Flux binary not found."

    $SUDO install -m 0755 "$binary" "$BIN_DIR/flux"

    success "Flux $version installed."
}

uninstall_flux() {
    remove_binary flux
}

###############################################################################
# Cloud tools
###############################################################################

install_awscli() {

    local url

    case "$ARCH" in
        amd64)
            url="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
            ;;
        arm64)
            url="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip"
            ;;
        *)
            die "AWS CLI does not support architecture $ARCH."
            ;;
    esac

    download "$url" "$TMP_DIR/awscli.zip"

    unzip -oq "$TMP_DIR/awscli.zip" -d "$TMP_DIR"

    if command -v aws >/dev/null 2>&1; then
        $SUDO "$TMP_DIR/aws/install" --update
    else
        $SUDO "$TMP_DIR/aws/install"
    fi

    success "AWS CLI installed/updated."
}

uninstall_awscli() {

    if [[ -x /usr/local/aws-cli/v2/current/bin/aws ]]; then
        $SUDO /usr/local/aws-cli/v2/current/dist/aws uninstall
    else
        $SUDO rm -f /usr/local/bin/aws
        $SUDO rm -rf /usr/local/aws-cli
    fi
}

install_azurecli() {

    case "$PKG_MANAGER" in
        apt)
            curl -sL https://aka.ms/InstallAzureCLIDeb | $SUDO bash
            ;;

        dnf|yum)
            warning "Azure CLI repository setup differs between RHEL-family distributions."
            warning "Use the official Azure CLI installer for this distribution."
            ;;

        *)
            warning "Azure CLI automatic installation is unavailable for $PKG_MANAGER."
            ;;
    esac
}

uninstall_azurecli() {
    pkg_remove azure-cli
}

install_gcloud() {

    local url
    local real_home
    local real_user

    case "$ARCH" in
        amd64)
            url="https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz"
            ;;

        arm64)
            url="https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-arm.tar.gz"
            ;;

        *)
            die "Google Cloud CLI architecture unsupported."
            ;;
    esac

    real_user="${SUDO_USER:-$USER}"
    real_home="$(getent passwd "$real_user" | cut -d: -f6)"

    download "$url" "$TMP_DIR/gcloud.tar.gz"

    tar -xzf "$TMP_DIR/gcloud.tar.gz" -C "$real_home"

    # Run install.sh as the real user so PATH is written to their shell rc
    sudo -u "$real_user" \
        "$real_home/google-cloud-sdk/install.sh" \
        --quiet \
        --path-update=true

    success "Google Cloud CLI installed/updated."
}

uninstall_gcloud() {
    local real_home
    real_home="$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)"
    rm -rf "$real_home/google-cloud-sdk"
}

###############################################################################
# Ansible
###############################################################################

install_ansible() {

    case "$PKG_MANAGER" in

        apt|dnf|yum|pacman|zypper|apk|xbps|eopkg)
            pkg_install ansible
            ;;

        *)
            if command -v pipx >/dev/null 2>&1; then
                pipx install ansible
            else
                python3 -m pip install --user ansible
            fi
            ;;
    esac

    success "Ansible installed."
}

uninstall_ansible() {

    case "$PKG_MANAGER" in
        apt|dnf|yum|pacman|zypper|apk|xbps|eopkg)
            pkg_remove ansible
            ;;
        *)
            pipx uninstall ansible 2>/dev/null || true
            ;;
    esac
}

###############################################################################
# Minikube
###############################################################################

install_minikube() {

    local url

    url="https://storage.googleapis.com/minikube/releases/latest/minikube-linux-${ARCH}"

    download "$url" "$TMP_DIR/minikube"

    $SUDO install \
        -m 0755 \
        "$TMP_DIR/minikube" \
        "$BIN_DIR/minikube"

    success "Minikube installed."
}

uninstall_minikube() {
    remove_binary minikube
}

###############################################################################
# kind
###############################################################################

install_kind() {

    local version
    local url

    version="$(github_latest_tag kubernetes-sigs/kind)"

    url="https://kind.sigs.k8s.io/dl/${version}/kind-linux-${ARCH}"

    download "$url" "$TMP_DIR/kind"

    $SUDO install \
        -m 0755 \
        "$TMP_DIR/kind" \
        "$BIN_DIR/kind"

    success "kind $version installed."
}

uninstall_kind() {
    remove_binary kind
}

###############################################################################
# eksctl
###############################################################################

install_eksctl() {

    local version
    local url

    version="$(github_latest_tag eksctl-io/eksctl)"

    url="https://github.com/eksctl-io/eksctl/releases/download/${version}/eksctl_Linux_${ARCH}.tar.gz"

    download "$url" "$TMP_DIR/eksctl.tar.gz"

    tar -xzf "$TMP_DIR/eksctl.tar.gz" -C "$TMP_DIR"

    $SUDO install \
        -m 0755 \
        "$TMP_DIR/eksctl" \
        "$BIN_DIR/eksctl"

    success "eksctl $version installed."
}

uninstall_eksctl() {
    remove_binary eksctl
}

###############################################################################
# OpenShift
###############################################################################

install_oc() {

    local url

    case "$ARCH" in
        amd64)
            url="https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-linux.tar.gz"
            ;;

        arm64)
            url="https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-linux-arm64.tar.gz"
            ;;

        *)
            die "OpenShift client unsupported on $ARCH."
            ;;
    esac

    download "$url" "$TMP_DIR/openshift-client.tar.gz"

    tar -xzf "$TMP_DIR/openshift-client.tar.gz" -C "$TMP_DIR"

    $SUDO install -m 0755 "$TMP_DIR/oc" "$BIN_DIR/oc"

    if [[ -f "$TMP_DIR/kubectl" ]]; then
        $SUDO install -m 0755 "$TMP_DIR/kubectl" "$BIN_DIR/kubectl"
    fi

    success "OpenShift CLI installed."
}

uninstall_oc() {
    remove_binary oc
}

###############################################################################
# Istio
###############################################################################

install_istio() {

    local version
    local url

    version="$(github_latest_tag istio/istio)"

    url="https://github.com/istio/istio/releases/download/${version}/istio-${version#v}-linux-${ARCH}.tar.gz"

    download "$url" "$TMP_DIR/istio.tar.gz"

    tar -xzf "$TMP_DIR/istio.tar.gz" -C "$TMP_DIR"

    local istio_dir

    istio_dir="$TMP_DIR/istio-${version#v}"

    if [[ -f "$istio_dir/bin/istioctl" ]]; then
        $SUDO install \
            -m 0755 \
            "$istio_dir/bin/istioctl" \
            "$BIN_DIR/istioctl"
    else
        die "istioctl not found."
    fi

    success "Istio $version installed."
}

uninstall_istio() {
    remove_binary istioctl
}

###############################################################################
# Trivy
###############################################################################

install_trivy() {

    local trivy_arch

    case "$ARCH" in
        amd64) trivy_arch="64bit" ;;
        arm64) trivy_arch="ARM64" ;;
        arm)   trivy_arch="ARM"   ;;
        *)     die "Trivy: unsupported architecture $ARCH" ;;
    esac

    install_github_binary \
        "aquasecurity/trivy" \
        "Linux-${trivy_arch}\\.tar\\.gz" \
        "trivy"
}

uninstall_trivy() {
    remove_binary trivy
}

###############################################################################
# Cosign
###############################################################################

install_cosign() {

    local version
    local url

    version="$(github_latest_tag sigstore/cosign)"

    url="https://github.com/sigstore/cosign/releases/download/${version}/cosign-linux-${ARCH}"

    download "$url" "$TMP_DIR/cosign"

    $SUDO install \
        -m 0755 \
        "$TMP_DIR/cosign" \
        "$BIN_DIR/cosign"

    success "Cosign $version installed."
}

uninstall_cosign() {
    remove_binary cosign
}

###############################################################################
# SOPS
###############################################################################

install_sops() {

    local version
    local url

    version="$(github_latest_tag getsops/sops)"

    url="https://github.com/getsops/sops/releases/download/${version}/sops-${version}.linux.${ARCH}"

    download "$url" "$TMP_DIR/sops"

    $SUDO install \
        -m 0755 \
        "$TMP_DIR/sops" \
        "$BIN_DIR/sops"

    success "SOPS $version installed."
}

uninstall_sops() {
    remove_binary sops
}

###############################################################################
# kubectx / kubens
###############################################################################

install_kubectx() {
    info "Installing: kubectx"

    case "$PKG_MANAGER" in

        apt)
            sudo apt-get update
            sudo apt-get install -y kubectx
            ;;

        dnf)
            if sudo dnf install -y kubectx; then
                :
            else
                install_kubectx_upstream
            fi
            ;;

        yum)
            if sudo yum install -y kubectx; then
                :
            else
                install_kubectx_upstream
            fi
            ;;

        pacman)
            sudo pacman -Sy --noconfirm kubectx
            ;;

        zypper)
            if sudo zypper --non-interactive install kubectx; then
                :
            else
                install_kubectx_upstream
            fi
            ;;

        apk)
            if sudo apk add kubectx; then
                :
            else
                install_kubectx_upstream
            fi
            ;;

        *)
            install_kubectx_upstream
            ;;
    esac

    command -v kubectx >/dev/null 2>&1 ||
        die "kubectx installation failed."

    success "kubectx installed successfully."
}
install_kubectx_upstream() {
    info "Installing kubectx from upstream GitHub..."

    require_cmd curl

    local tmpdir
    tmpdir="$(mktemp -d)"

    curl -fsSL \
        "https://raw.githubusercontent.com/ahmetb/kubectx/master/kubectx" \
        -o "$tmpdir/kubectx"

    chmod +x "$tmpdir/kubectx"

    sudo install -m 0755 \
        "$tmpdir/kubectx" \
        /usr/local/bin/kubectx

    rm -rf "$tmpdir"
}

uninstall_kubectx() {
    remove_binary kubectx
}

###############################################################################
# Stern
###############################################################################

install_stern() {

    install_github_binary \
        "stern/stern" \
        "linux_${ARCH}\\.tar\\.gz" \
        "stern"
}

uninstall_stern() {
    remove_binary stern
}

###############################################################################
# Podman / Buildah / Skopeo
###############################################################################

install_container_tools() {

    case "$PKG_MANAGER" in

        apt)
            pkg_install podman buildah skopeo
            ;;

        dnf|yum)
            pkg_install podman buildah skopeo
            ;;

        pacman)
            pkg_install podman buildah skopeo
            ;;

        zypper)
            pkg_install podman buildah skopeo
            ;;

        apk)
            pkg_install podman
            ;;

        *)
            warning "Container package installation unsupported on $PKG_MANAGER."
            ;;
    esac

    success "Container tools installed."
}

uninstall_container_tools() {
    pkg_remove podman buildah skopeo
}

###############################################################################
# Jenkins
###############################################################################

install_jenkins() {

    case "$PKG_MANAGER" in

        apt)

            pkg_install fontconfig openjdk-17-jre

            # Import current signing key (2025) and the previous key (2023)
            for key_id in 7198F4B714ABFC68 5BA31D57EF5975CA; do
                gpg \
                    --batch \
                    --keyserver hkps://keyserver.ubuntu.com \
                    --recv-keys "$key_id" 2>/dev/null || true
            done

            gpg --export 7198F4B714ABFC68 5BA31D57EF5975CA |
                $SUDO tee /usr/share/keyrings/jenkins-keyring.gpg >/dev/null

            echo \
                "deb [signed-by=/usr/share/keyrings/jenkins-keyring.gpg] https://pkg.jenkins.io/debian-stable binary/" |
                $SUDO tee /etc/apt/sources.list.d/jenkins.list >/dev/null

            pkg_update
            pkg_install jenkins

            $SUDO systemctl enable --now jenkins
            ;;

        *)
            warning "Jenkins automatic repository setup is currently implemented for Debian/Ubuntu."
            ;;
    esac
}

uninstall_jenkins() {

    $SUDO systemctl disable --now jenkins 2>/dev/null || true

    pkg_remove jenkins
}

###############################################################################
# Grafana
###############################################################################

install_grafana() {

    case "$PKG_MANAGER" in

        apt)

            $SUDO mkdir -p /etc/apt/keyrings

            curl -fsSL \
                https://apt.grafana.com/gpg.key |
                $SUDO gpg --dearmor \
                -o /etc/apt/keyrings/grafana.gpg

            echo \
                "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" |
                $SUDO tee /etc/apt/sources.list.d/grafana.list >/dev/null

            pkg_update
            pkg_install grafana

            $SUDO systemctl enable --now grafana-server
            ;;

        *)
            warning "Grafana repository setup currently implemented for APT."
            ;;
    esac
}

uninstall_grafana() {

    $SUDO systemctl disable --now grafana-server 2>/dev/null || true

    pkg_remove grafana
}

###############################################################################
# Node.js
###############################################################################

install_nodejs() {

    case "$PKG_MANAGER" in

        apt)
            pkg_install nodejs npm
            ;;

        dnf|yum)
            pkg_install nodejs npm
            ;;

        pacman)
            pkg_install nodejs npm
            ;;

        zypper)
            pkg_install nodejs npm
            ;;

        apk)
            pkg_install nodejs npm
            ;;

        xbps)
            pkg_install nodejs npm
            ;;

        brew)
            brew install node
            ;;

        *)
            warning "Node.js package installation unavailable."
            ;;
    esac

    success "Node.js installed."
}

uninstall_nodejs() {
    pkg_remove nodejs npm
}

###############################################################################
# Go
###############################################################################

install_go() {

    local version
    local url
    local real_home

    version="$(
        curl -fsSL \
        https://go.dev/VERSION?m=text |
        head -n1
    )"

    version="${version#go}"

    case "$ARCH" in
        amd64|arm64)
            ;;
        *)
            die "Go installer currently supports amd64/arm64."
            ;;
    esac

    url="https://go.dev/dl/go${version}.linux-${ARCH}.tar.gz"

    download "$url" "$TMP_DIR/go.tar.gz"

    $SUDO rm -rf /usr/local/go
    $SUDO tar -C /usr/local -xzf "$TMP_DIR/go.tar.gz"

    # Write PATH to the real invoking user's .bashrc, not root's
    real_home="$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)"

    if [[ -n "$real_home" ]] && \
       ! grep -q '/usr/local/go/bin' "$real_home/.bashrc" 2>/dev/null; then
        echo 'export PATH="$PATH:/usr/local/go/bin:$HOME/go/bin"' >> "$real_home/.bashrc"
    fi

    success "Go $version installed."
}

uninstall_go() {
    $SUDO rm -rf /usr/local/go
}

###############################################################################
# Java
###############################################################################

install_java() {

    case "$PKG_MANAGER" in

        apt)
            pkg_install openjdk-17-jdk
            ;;

        dnf|yum)
            pkg_install java-17-openjdk-devel
            ;;

        pacman)
            pkg_install jdk17-openjdk
            ;;

        zypper)
            pkg_install java-17-openjdk-devel
            ;;

        apk)
            pkg_install openjdk17
            ;;

        *)
            warning "Java package name is not configured for $PKG_MANAGER."
            ;;
    esac
}

uninstall_java() {

    case "$PKG_MANAGER" in

        apt)
            pkg_remove openjdk-17-jdk
            ;;

        dnf|yum)
            pkg_remove java-17-openjdk-devel
            ;;

        pacman)
            pkg_remove jdk17-openjdk
            ;;

        zypper)
            pkg_remove java-17-openjdk-devel
            ;;

        apk)
            pkg_remove openjdk17
            ;;

        *)
            warning "Java removal is not configured for $PKG_MANAGER."
            ;;
    esac
}

###############################################################################
# Generic binary removal
###############################################################################

remove_binary() {

    local binary="$1"

    if [[ -e "$BIN_DIR/$binary" ]]; then
        $SUDO rm -f "$BIN_DIR/$binary"
        success "$binary removed."
    else
        warning "$binary is not installed in $BIN_DIR."
    fi
}

###############################################################################
# Common tools
###############################################################################

install_common() {

    info "Installing common DevOps dependencies..."

    pkg_update

    case "$PKG_MANAGER" in

        apt)

            pkg_install \
                curl \
                wget \
                git \
                unzip \
                zip \
                tar \
                gzip \
                ca-certificates \
                gnupg \
                jq \
                tree \
                tmux \
                fzf \
                ripgrep \
                fd-find \
                netcat-openbsd \
                dnsutils \
                python3 \
                python3-pip \
                python3-venv \
                make \
                gcc \
                g++ \
                build-essential
            ;;

        dnf|yum)

            pkg_install \
                curl \
                wget \
                git \
                unzip \
                zip \
                tar \
                gzip \
                ca-certificates \
                gnupg2 \
                jq \
                tree \
                tmux \
                fzf \
                ripgrep \
                fd-find \
                nmap-ncat \
                bind-utils \
                python3 \
                python3-pip \
                make \
                gcc \
                gcc-c++
            ;;

        pacman)

            pkg_install \
                curl \
                wget \
                git \
                unzip \
                zip \
                tar \
                gzip \
                ca-certificates \
                gnupg \
                jq \
                tree \
                tmux \
                fzf \
                ripgrep \
                fd \
                openbsd-netcat \
                bind \
                python \
                python-pip \
                base-devel
            ;;

        zypper)

            pkg_install \
                curl \
                wget \
                git \
                unzip \
                zip \
                tar \
                gzip \
                ca-certificates \
                git \
                jq \
                tree \
                tmux \
                fzf \
                ripgrep \
                fd \
                netcat-openbsd \
                bind-utils \
                python3 \
                python3-pip \
                make \
                gcc \
                gcc-c++
            ;;

        apk)

            pkg_install \
                curl \
                wget \
                git \
                unzip \
                zip \
                tar \
                gzip \
                ca-certificates \
                gnupg \
                jq \
                tree \
                tmux \
                fzf \
                ripgrep \
                fd \
                netcat-openbsd \
                bind-tools \
                python3 \
                py3-pip \
                make \
                gcc \
                g++ \
                musl-dev
            ;;

        xbps)

            pkg_install \
                curl \
                wget \
                git \
                unzip \
                zip \
                tar \
                gzip \
                ca-certificates \
                gnupg \
                jq \
                tree \
                tmux \
                fzf \
                ripgrep \
                fd \
                python3 \
                python3-pip \
                make \
                gcc
            ;;

        emerge)

            pkg_install \
                net-misc/curl \
                net-misc/wget \
                dev-vcs/git \
                app-arch/unzip \
                app-arch/zip \
                app-misc/jq \
                app-text/tree \
                app-misc/tmux \
                app-shells/fzf \
                dev-lang/python \
                sys-devel/gcc \
                sys-devel/make
            ;;

        eopkg)

            pkg_install \
                curl \
                wget \
                git \
                unzip \
                zip \
                jq \
                tree \
                tmux \
                fzf \
                python3 \
                make \
                gcc
            ;;

        nix)

            warning "NixOS detected."
            warning "Install common packages through your Nix configuration/profile."
            ;;

        *)

            warning "No common package set defined for $PKG_MANAGER."
            ;;
    esac

    success "Common dependencies installed."
}

###############################################################################
# Tool definitions
###############################################################################

declare -a TOOLS=(
    common
    docker
    docker-compose
    kubectl
    helm
    kustomize
    k9s
    kind
    minikube
    eksctl
    argocd
    flux
    kubectx
    stern
    istio
    oc
    terraform
    vault
    consul
    packer
    ansible
    awscli
    azurecli
    gcloud
    trivy
    cosign
    sops
    jenkins
    grafana
    nodejs
    go
    java
    container-tools
)

###############################################################################
# Tool description
###############################################################################

description() {

    case "$1" in
        common)          echo "Common Linux/DevOps utilities" ;;
        docker)          echo "Docker container engine" ;;
        docker-compose)  echo "Docker Compose plugin" ;;
        kubectl)         echo "Kubernetes CLI" ;;
        helm)            echo "Kubernetes package manager" ;;
        kustomize)       echo "Kubernetes configuration customization" ;;
        k9s)             echo "Kubernetes terminal UI" ;;
        kind)            echo "Kubernetes in Docker" ;;
        minikube)        echo "Local Kubernetes" ;;
        eksctl)           echo "Amazon EKS CLI" ;;
        argocd)          echo "Argo CD CLI" ;;
        flux)            echo "Flux CD CLI" ;;
        kubectx)          echo "kubectl context/namespace helper" ;;
        stern)           echo "Kubernetes multi-pod log tailing" ;;
        istio)            echo "Istio CLI" ;;
        oc)               echo "OpenShift CLI" ;;
        terraform)        echo "Infrastructure as Code" ;;
        vault)            echo "HashiCorp Vault" ;;
        consul)           echo "HashiCorp Consul" ;;
        packer)           echo "HashiCorp Packer" ;;
        ansible)          echo "Configuration management / automation" ;;
        awscli)           echo "AWS CLI" ;;
        azurecli)         echo "Azure CLI" ;;
        gcloud)           echo "Google Cloud CLI" ;;
        trivy)            echo "Container/IaC vulnerability scanner" ;;
        cosign)           echo "Container signing and verification" ;;
        sops)             echo "Secrets encryption" ;;
        jenkins)          echo "Jenkins CI server" ;;
        grafana)          echo "Grafana monitoring/visualization" ;;
        nodejs)           echo "Node.js" ;;
        go)               echo "Go programming language" ;;
        java)             echo "OpenJDK" ;;
        container-tools)  echo "Podman/Buildah/Skopeo" ;;
        *)                echo "Unknown tool" ;;
    esac
}

###############################################################################
# Tool install dispatcher
###############################################################################

install_tool() {

    local tool="$1"

    info "Installing: $tool"

    case "$tool" in

        common)          install_common ;;
        docker)          install_docker ;;
        docker-compose)  install_docker_compose ;;
        kubectl)         install_kubectl ;;
        helm)            install_helm ;;
        kustomize)       install_kustomize ;;
        k9s)             install_k9s ;;
        kind)             install_kind ;;
        minikube)        install_minikube ;;
        eksctl)           install_eksctl ;;
        argocd)          install_argocd ;;
        flux)             install_flux ;;
        kubectx)          install_kubectx ;;
        stern)            install_stern ;;
        istio)            install_istio ;;
        oc)               install_oc ;;
        terraform)        install_terraform ;;
        vault)            install_vault ;;
        consul)           install_consul ;;
        packer)           install_packer ;;
        ansible)          install_ansible ;;
        awscli)           install_awscli ;;
        azurecli)         install_azurecli ;;
        gcloud)           install_gcloud ;;
        trivy)            install_trivy ;;
        cosign)            install_cosign ;;
        sops)              install_sops ;;
        jenkins)          install_jenkins ;;
        grafana)          install_grafana ;;
        nodejs)           install_nodejs ;;
        go)               install_go ;;
        java)             install_java ;;
        container-tools)  install_container_tools ;;

        *)
            error "Unknown tool: $tool"
            return 1
            ;;
    esac
}

###############################################################################
# Tool uninstall dispatcher
###############################################################################

uninstall_tool() {

    local tool="$1"

    info "Uninstalling: $tool"

    case "$tool" in

        common)
            warning "Common tools are not automatically removed."
            ;;

        docker)          uninstall_docker ;;
        docker-compose)  uninstall_docker_compose ;;
        kubectl)         uninstall_kubectl ;;
        helm)            uninstall_helm ;;
        kustomize)       uninstall_kustomize ;;
        k9s)              uninstall_k9s ;;
        kind)             uninstall_kind ;;
        minikube)         uninstall_minikube ;;
        eksctl)            uninstall_eksctl ;;
        argocd)           uninstall_argocd ;;
        flux)             uninstall_flux ;;
        kubectx)           uninstall_kubectx ;;
        stern)             uninstall_stern ;;
        istio)             uninstall_istio ;;
        oc)                uninstall_oc ;;
        terraform)         uninstall_terraform ;;
        vault)             uninstall_vault ;;
        consul)            uninstall_consul ;;
        packer)            uninstall_packer ;;
        ansible)           uninstall_ansible ;;
        awscli)            uninstall_awscli ;;
        azurecli)          uninstall_azurecli ;;
        gcloud)            uninstall_gcloud ;;
        trivy)             remove_binary trivy ;;
        cosign)             uninstall_cosign ;;
        sops)               uninstall_sops ;;
        jenkins)            uninstall_jenkins ;;
        grafana)            uninstall_grafana ;;
        nodejs)             uninstall_nodejs ;;
        go)                 uninstall_go ;;
        java)               uninstall_java ;;
        container-tools)    uninstall_container_tools ;;

        *)
            error "Unknown tool: $tool"
            return 1
            ;;
    esac
}
###############################################################################
# Tool installation/status checking
###############################################################################

# Return the command used to check a tool.
tool_command() {

    case "$1" in
        common)          echo "git" ;;
        docker)          echo "docker" ;;
        docker-compose)  echo "docker-compose" ;;
        kubectl)         echo "kubectl" ;;
        helm)            echo "helm" ;;
        kustomize)       echo "kustomize" ;;
        k9s)             echo "k9s" ;;
        kind)             echo "kind" ;;
        minikube)         echo "minikube" ;;
        eksctl)           echo "eksctl" ;;
        argocd)           echo "argocd" ;;
        flux)             echo "flux" ;;
        kubectx)          echo "kubectx" ;;
        stern)            echo "stern" ;;
        istio)            echo "istioctl" ;;
        oc)               echo "oc" ;;
        terraform)        echo "terraform" ;;
        vault)            echo "vault" ;;
        consul)           echo "consul" ;;
        packer)           echo "packer" ;;
        ansible)          echo "ansible" ;;
        awscli)           echo "aws" ;;
        azurecli)         echo "az" ;;
        gcloud)           echo "gcloud" ;;
        trivy)            echo "trivy" ;;
        cosign)            echo "cosign" ;;
        sops)              echo "sops" ;;
        jenkins)           echo "jenkins" ;;
        grafana)           echo "grafana-server" ;;
        nodejs)            echo "node" ;;
        go)                echo "go" ;;
        java)              echo "java" ;;
        container-tools)   echo "podman" ;;
        *)                 echo "" ;;
    esac
}

# Return the known absolute path for tools not on PATH by default.
tool_fallback_path() {

    case "$1" in
        docker-compose) echo "/usr/local/lib/docker/cli-plugins/docker-compose" ;;
        go)     echo "/usr/local/go/bin/go" ;;
        gcloud)
            local real_home
            real_home="$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)"
            echo "$real_home/google-cloud-sdk/bin/gcloud"
            ;;
        *)      echo "" ;;
    esac
}


# Get installed version of a tool.
get_tool_version() {

    local tool="$1"
    local command

    command="$(tool_command "$tool")"

    [[ -n "$command" ]] || return 1

    if ! command -v "$command" >/dev/null 2>&1; then
        local fallback
        fallback="$(tool_fallback_path "$tool")"
        [[ -n "$fallback" && -x "$fallback" ]] || return 1
    fi

    case "$tool" in

        docker)
            docker --version 2>/dev/null
            ;;

        docker-compose)
            if command -v docker-compose >/dev/null 2>&1; then
                docker-compose version 2>/dev/null
            else
                "$(tool_fallback_path docker-compose)" version 2>/dev/null
            fi
            ;;

        kubectl)
            kubectl version --client 2>/dev/null |
                head -n1
            ;;

        helm)
            helm version --short 2>/dev/null
            ;;

        kustomize)
            kustomize version 2>/dev/null |
                head -n1
            ;;

        k9s)
            k9s version --short 2>/dev/null |
                head -n1
            ;;

        kind)
            kind version 2>/dev/null
            ;;

        minikube)
            minikube version --short 2>/dev/null
            ;;

        eksctl)
            eksctl version 2>/dev/null
            ;;

        argocd)
            argocd version --client --short 2>/dev/null
            ;;

        flux)
            flux --version 2>/dev/null
            ;;

        kubectx)
              if command -v kubectx >/dev/null 2>&1; then
                  kubectx --version 2>&1 | head -n1
              fi
              ;;

        stern)
            stern --version 2>/dev/null
            ;;

        istio)
            istioctl version --remote=false 2>/dev/null |
                head -n1
            ;;

        oc)
            oc version --client 2>/dev/null |
                head -n1
            ;;

        terraform)
            terraform version 2>/dev/null |
                head -n1
            ;;

        vault)
            vault version 2>/dev/null
            ;;

        consul)
            consul version 2>/dev/null |
                head -n1
            ;;

        packer)
            packer version 2>/dev/null |
                head -n1
            ;;

        ansible)
            ansible --version 2>/dev/null |
                head -n1
            ;;

        awscli)
            aws --version 2>/dev/null
            ;;

        azurecli)
            az version 2>/dev/null |
                jq -r '.\"azure-cli\"' 2>/dev/null ||
                az version 2>/dev/null |
                head -n1
            ;;

        gcloud)
            local gcloud_bin
            gcloud_bin="$(tool_fallback_path gcloud)"
            "${gcloud_bin}" version 2>/dev/null | head -n1
            ;;

        trivy)
            trivy version 2>/dev/null |
                head -n1
            ;;

        cosign)
            cosign version 2>/dev/null |
                head -n1
            ;;

        sops)
            sops --version --no-check-for-updates 2>/dev/null
            ;;

        jenkins)
            if command -v jenkins >/dev/null 2>&1; then
                jenkins --version 2>/dev/null
            else
                echo "Jenkins service installed"
            fi
            ;;

        grafana)
            grafana-server -v 2>/dev/null
            ;;

        nodejs)
            node --version 2>/dev/null
            ;;

        go)
            /usr/local/go/bin/go version 2>/dev/null
            ;;

        java)
            java -version 2>&1 |
                head -n1
            ;;

        container-tools)
            podman --version 2>/dev/null
            ;;

        common)
            git --version 2>/dev/null
            ;;

        *)
            return 1
            ;;
    esac
}


###############################################################################
# Check one tool
###############################################################################

check_tool() {

    local tool="$1"
    local command
    local binary

    command="$(tool_command "$tool")"

    if [[ -z "$command" ]]; then
        printf "%-18s ${YELLOW}UNKNOWN${NC}\n" "$tool"
        return 1
    fi

    if command -v "$command" >/dev/null 2>&1; then
        binary="$command"
    else
        local fallback
        fallback="$(tool_fallback_path "$tool")"
        if [[ -n "$fallback" && -x "$fallback" ]]; then
            binary="$fallback"
        fi
    fi

    if [[ -n "${binary:-}" ]]; then

        local version

        version="$(get_tool_version "$tool" 2>/dev/null || true)"

        if [[ -z "$version" ]]; then
            version="installed"
        fi

        printf "${GREEN}[INSTALLED]${NC} %-18s %s\n" \
            "$tool" \
            "$version"

        return 0

    else

        printf "${RED}[MISSING]${NC}   %-18s %s\n" \
            "$tool" \
            "not installed"

        return 1
    fi
}


###############################################################################
# Check all tools
###############################################################################

check_all_tools() {

    echo
    echo -e "${BOLD}DevOps Tool Installation Status${NC}"
    echo "==============================================================================="

    local installed=0
    local missing=0
    local unknown=0

    for tool in "${TOOLS[@]}"; do

        if check_tool "$tool"; then
            ((installed+=1))
        else
            command="$(tool_command "$tool")"

            if [[ -z "$command" ]]; then
                ((unknown+=1))
            else
                ((missing+=1))
            fi
        fi

    done

    echo "==============================================================================="

    echo
    echo -e "${GREEN}Installed : $installed${NC}"
    echo -e "${RED}Missing   : $missing${NC}"
    echo -e "${YELLOW}Unknown   : $unknown${NC}"
    echo

    if (( missing == 0 )); then
        echo -e "${GREEN}${BOLD}All supported tools are installed.${NC}"
    else
        echo -e "${YELLOW}${BOLD}Some tools are missing.${NC}"
        echo
        echo "Run:"
        echo
        echo "  $SCRIPT_NAME install <tool>"
        echo
        echo "or use the interactive installer."
    fi

    echo
}


###############################################################################
# List only missing tools
###############################################################################

list_missing_tools() {

    echo
    echo -e "${BOLD}Missing DevOps tools:${NC}"
    echo "==============================================================================="

    local missing=0

    for tool in "${TOOLS[@]}"; do

        local command fallback
        command="$(tool_command "$tool")"
        fallback="$(tool_fallback_path "$tool")"

        if [[ -n "$command" ]] &&
           ! command -v "$command" >/dev/null 2>&1 &&
           ! { [[ -n "$fallback" ]] && [[ -x "$fallback" ]]; }; then

            echo "  $tool"
            ((missing+=1))
        fi

    done

    echo "==============================================================================="

    if (( missing == 0 )); then
        echo -e "${GREEN}No supported tools are missing.${NC}"
    else
        echo
        echo "Install missing tools with:"
        echo
        echo "  $SCRIPT_NAME install <tool>"
    fi

    echo
}


###############################################################################
# Install missing tools
###############################################################################

install_missing_tools() {

    echo
    echo -e "${BOLD}Checking for missing tools...${NC}"
    echo

    local missing_tools=()

    for tool in "${TOOLS[@]}"; do

        local command fallback
        command="$(tool_command "$tool")"
        fallback="$(tool_fallback_path "$tool")"

        if [[ -n "$command" ]] &&
           ! command -v "$command" >/dev/null 2>&1 &&
           ! { [[ -n "$fallback" ]] && [[ -x "$fallback" ]]; }; then

            missing_tools+=("$tool")
        fi

    done

    if [[ ${#missing_tools[@]} -eq 0 ]]; then
        success "All supported tools are already installed."
        return 0
    fi

    echo "The following tools are missing:"
    echo

    printf '  %s\n' "${missing_tools[@]}"

    echo
    read -r -p "Install all missing tools? (y/N): " answer

    if [[ "$answer" =~ ^[Yy]$ ]]; then

        for tool in "${missing_tools[@]}"; do

            echo
            echo "-------------------------------------------------------------------------------"
            echo "Installing $tool"
            echo "-------------------------------------------------------------------------------"

            if install_tool "$tool"; then
                success "$tool installed."
            else
                warning "Failed to install $tool."
            fi

        done

        echo
        check_all_tools

    else
        info "Installation cancelled."
    fi
}

###############################################################################
# Install latest versions
###############################################################################

update_tool() {

    local tool="$1"

    info "Updating: $tool"

    # For upstream binary tools, install_tool automatically resolves
    # the latest release.
    case "$tool" in

        docker-compose|kubectl|helm|kustomize|k9s|kind|minikube|eksctl|argocd|flux|kubectx|stern|istio|oc|terraform|vault|consul|packer|awscli|gcloud|trivy|cosign|sops|go)
            install_tool "$tool"
            ;;

        *)
            case "$PKG_MANAGER" in
                none)
                    warning "Cannot update $tool: no package manager."
                    ;;
                *)
                    pkg_update
                    ;;
            esac
            ;;
    esac
}

###############################################################################
# List tools
###############################################################################

list_tools() {

    echo
    echo -e "${BOLD}Available DevOps tools:${NC}"
    echo

    for tool in "${TOOLS[@]}"; do
        printf "  %-18s %s\n" \
            "$tool" \
            "$(description "$tool")"
    done

    echo
}

###############################################################################
# Detect
###############################################################################

show_detect() {

    echo
    echo -e "${BOLD}System information${NC}"
    echo "---------------------------------------------"
    echo "OS              : $OS_NAME"
    echo "OS ID           : $OS_ID"
    echo "OS version      : $OS_VERSION"
    echo "Architecture    : $ARCH_RAW"
    echo "Package manager : $PKG_MANAGER"
    echo "Binary directory: $BIN_DIR"
    echo
}

###############################################################################
# Interactive selection
###############################################################################

interactive_install() {

    list_tools

    echo "Enter tools separated by spaces."
    echo "Example:"
    echo
    echo "  docker kubectl helm terraform awscli"
    echo

    read -r -p "Tools: " selected

    [[ -n "$selected" ]] ||
        die "No tools selected."

    for tool in $selected; do
        install_tool "$tool"
    done
}

interactive_uninstall() {

    list_tools

    read -r -p "Tools to uninstall: " selected

    [[ -n "$selected" ]] ||
        die "No tools selected."

    for tool in $selected; do
        uninstall_tool "$tool"
    done
}

interactive_update() {

    list_tools

    read -r -p "Tools to update: " selected

    [[ -n "$selected" ]] ||
        die "No tools selected."

    for tool in $selected; do
        update_tool "$tool"
    done
}

###############################################################################
# Interactive menu
###############################################################################

menu() {

    while true; do

        clear

        echo
        echo -e "${CYAN}${BOLD}"
        echo "###############################################################################"
        echo "#                                                                             #"
        echo "#                Universal Linux DevOps Tool Installer                       #"
        echo "#                                                                             #"
        echo "###############################################################################"
        echo -e "${NC}"

        echo "OS              : $OS_NAME"
        echo "Architecture    : $ARCH_RAW"
        echo "Package manager : $PKG_MANAGER"
        echo

        echo "1) Install tools"
        echo "2) Install missing tools"
        echo "3) Uninstall tools"
        echo "4) Update tools"
        echo "5) Update all"
        echo "6) Check installation status"
        echo "7) List missing tools"
        echo "8) List all tools"
        echo "9) Detect system"
        echo "10) Exit"
        echo

        read -r -p "Select option: " choice

        case "$choice" in

            1)
                interactive_install
                ;;

            2)
                install_missing_tools
                ;;

            3)
                interactive_uninstall
                ;;

            4)
                interactive_update
                ;;

            5)
                pkg_upgrade

                for tool in \
                    docker-compose \
                    kubectl \
                    helm \
                    kustomize \
                    k9s \
                    kind \
                    minikube \
                    eksctl \
                    argocd \
                    flux \
                    kubectx \
                    stern \
                    istio \
                    terraform \
                    vault \
                    consul \
                    packer \
                    trivy \
                    cosign \
                    sops \
                    go
                do
                    update_tool "$tool" ||
                        warning "Failed to update $tool"
                done
                ;;

            6)
                check_all_tools
                ;;

            7)
                list_missing_tools
                ;;

            8)
                list_tools
                ;;

            9)
                show_detect
                ;;

            10)
                echo "Bye."
                exit 0
                ;;

            *)
                warning "Invalid option."
                ;;
        esac

        echo
        read -r -p "Press Enter to continue..."
    done
}

###############################################################################
# CLI
###############################################################################


main() {

    detect_os

    if [[ $# -eq 0 ]]; then
        menu
        return
    fi

    local action="$1"
    shift || true

    case "$action" in

        install)

            [[ $# -gt 0 ]] ||
                die "Usage: $SCRIPT_NAME install <tool> [tool...]"

            for tool in "$@"; do
                install_tool "$tool"
            done

            echo
            check_all_tools
            ;;

        install-missing)

            install_missing_tools
            ;;

        uninstall)

            [[ $# -gt 0 ]] ||
                die "Usage: $SCRIPT_NAME uninstall <tool> [tool...]"

            for tool in "$@"; do
                uninstall_tool "$tool"
            done

            echo
            check_all_tools
            ;;

        update)

            [[ $# -gt 0 ]] ||
                die "Usage: $SCRIPT_NAME update <tool> [tool...]"

            for tool in "$@"; do
                update_tool "$tool"
            done

            echo
            check_all_tools
            ;;

        update-all)

            info "Updating system packages..."
            pkg_upgrade

            info "Updating DevOps tools..."

            for tool in \
                docker-compose \
                kubectl \
                helm \
                kustomize \
                k9s \
                kind \
                minikube \
                eksctl \
                argocd \
                flux \
                kubectx \
                stern \
                istio \
                terraform \
                vault \
                consul \
                packer \
                trivy \
                cosign \
                sops \
                go
            do
                update_tool "$tool" ||
                    warning "Failed to update $tool"
            done

            echo
            check_all_tools
            ;;

        check|status)

            check_all_tools
            ;;

        missing)

            list_missing_tools
            ;;

        list)

            list_tools
            ;;

        detect)

            show_detect
            ;;

        help|-h|--help)

            cat <<EOF

Usage:

  $SCRIPT_NAME

  $SCRIPT_NAME install <tool> [tool...]

  $SCRIPT_NAME install-missing

  $SCRIPT_NAME uninstall <tool> [tool...]

  $SCRIPT_NAME update <tool> [tool...]

  $SCRIPT_NAME update-all

  $SCRIPT_NAME check
  $SCRIPT_NAME status

  $SCRIPT_NAME missing

  $SCRIPT_NAME list

  $SCRIPT_NAME detect


Examples:

  # Check every supported DevOps tool
  $SCRIPT_NAME check

  # Show only missing tools
  $SCRIPT_NAME missing

  # Install every missing tool
  $SCRIPT_NAME install-missing

  # Install selected tools
  $SCRIPT_NAME install docker kubectl helm terraform

  # Update selected tools
  $SCRIPT_NAME update kubectl helm terraform

  # Update all supported tools
  $SCRIPT_NAME update-all

  # Remove tools
  $SCRIPT_NAME uninstall terraform vault

EOF
            ;;

        *)

            die "Unknown action: $action. Use --help."

            ;;
    esac
}

main "$@"

###############################################################################
# Start
###############################################################################

main "$@"
