#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------
# Install script – skips already‑installed packages
# -------------------------------------------------

# Ensure we run as root for package management
if [[ $EUID -ne 0 ]]; then
    echo "Switching to root for privileged operations..."
    exec sudo "$0" "$@"
fi

# -------------------------
# Helper: install pacman packages only if missing
# -------------------------
install_pacman_pkgs() {
    local pkgs=("$@")
    local to_install=()
    for pkg in "${pkgs[@]}"; do
        if ! pacman -Qs "^${pkg}\$" > /dev/null 2>&1; then
            to_install+=("$pkg")
        else
            echo "✔ $pkg already installed"
        fi
    done
    if (( ${#to_install[@]} )); then
        echo "Installing: ${to_install[*]}"
        pacman -S --noconfirm "${to_install[@]}"
    fi
}

# -------------------------
# 1. Pull dotfiles from GitHub
# -------------------------
DOTFILES_DIR="${HOME}/dotfiles"
if [[ -d "$DOTFILES_DIR/.git" ]]; then
    echo "Updating existing dotfiles repository..."
    git -C "$DOTFILES_DIR" pull
else
    echo "Cloning dotfiles repository..."
    git clone "https://github.com/areppa/dotfiles" "$DOTFILES_DIR"
fi

# -------------------------
# 2. General terminal & system tools
# -------------------------
GENERAL_PKGS=(
    bluetui
    brightnessctl
    btop
    docker
    docker-compose
    exiftool
    eza
    flatpak
    zip
    yay
    fzf
    git
    grim
    nmap
    nvim
    nvtop
    pavucontrol
    pipewire
    power-profiles-daemon
    python
    python-pip
    rsync
    s-tui
    slurp
    sshpass
    stow
    stress-ng
    syncthing
    tailscale
    vim
    wavemon
    wget
    wireplumber
    xdg-desktop-portal-hyprland
)

install_pacman_pkgs "${GENERAL_PKGS[@]}"

# -------------------------
# 3. SMB components
# -------------------------
SMB_PKGS=(cifs-utils smbclient)
install_pacman_pkgs "${SMB_PKGS[@]}"

# -------------------------
# 4. Hyprland & supporting components
# -------------------------
HYPR_PKGS=(
    hyprland
    hyprshot
    hyprlock
    hypridle
    hyprpaper
    wofi
    waybar
    swaync
    kitty
)

install_pacman_pkgs "${HYPR_PKGS[@]}"

# -------------------------
# 5. Native desktop software
# -------------------------
DESKTOP_NATIVE_PKGS=(
    vlc
    audacity
    gimp
    papers
    discord
    libreoffice-still
    steam
)

install_pacman_pkgs "${DESKTOP_NATIVE_PKGS[@]}"

# -------------------------
# 6. Flatpak applications (skip if already installed)
# -------------------------
FLATPAK_REMOTE="flathub"
FLATPAK_APPS=(
    com.brave.Browser
    io.gitlab.librewolf-community
    com.github.tchx84.Flatseal
    com.vscodium.codium
    dev.vencord.Vesktop
    md.obsidian.Obsidian
    net.ankiweb.Anki
    org.gnome.Boxes
    com.heroicgameslauncher.hgl
    org.filezillaproject.Filezilla
    org.localsend.localsend_app
    org.gnome.gitlab.YaLTeR.VideoTrimmer
)

# Ensure the remote exists
if ! flatpak remote-list | grep -q "^$FLATPAK_REMOTE"; then
    echo "Adding Flatpak remote '$FLATPAK_REMOTE'..."
    flatpak remote-add --if-not-exists "$FLATPAK_REMOTE" "https://flathub.org/repo/flathub.flatpakrepo"
fi

for app in "${FLATPAK_APPS[@]}"; do
    if flatpak info "$app" > /dev/null 2>&1; then
        echo "✔ $app already installed via Flatpak"
    else
        echo "Installing Flatpak app: $app"
        flatpak install -y "$FLATPAK_REMOTE" "$app"
    fi
done

# -------------------------
# 7. Fonts
# -------------------------
FONT_PKGS=(ttf-cascadia-code-nerd)
install_pacman_pkgs "${FONT_PKGS[@]}"

echo "All tasks completed."
