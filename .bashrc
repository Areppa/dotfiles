#!/usr/bin/env bash
iatest=$(expr index "$-" i)

#######################################################
# SOURCED ALIASES AND SCRIPTS BY zachbrowne.me
#######################################################
if command -v fastfetch &> /dev/null; then
    # Only run fastfetch if we're in an interactive shell
    if [[ $- == *i* ]]; then
        fastfetch
    fi
fi

# Enable bash programmable completion features in interactive shells
if [ -f /usr/share/bash-completion/bash_completion ]; then
	. /usr/share/bash-completion/bash_completion
elif [ -f /etc/bash_completion ]; then
	. /etc/bash_completion
fi

#######################################################
# EXPORTS
#######################################################

# Expand the history size
export HISTFILESIZE=10000
export HISTSIZE=500
export HISTTIMEFORMAT="%F %T" # add timestamp to history

# Don't put duplicate lines in the history and do not add lines that start with a space
export HISTCONTROL=erasedups:ignoredups:ignorespace

# set up XDG folders
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

#######################################################
# ALIASES
#######################################################

# aliases to modified commands
alias cp='cp -i'
alias mv='mv -i'
alias mkdir='mkdir -p'
alias ps='ps auxf'
alias less='less -R'
alias vi='nvim'

# Change directory aliases
alias home='cd ~'

# Check if eza is installed and set alias accordingly
if command -v eza &> /dev/null; then
    alias ls='eza -l --group-directories-first --git'
fi

# Enable or disable tailscale
alias tailup='sudo tailscale up'
alias taildown='sudo tailscale down'

# Connect to phones hotspot
alias ah='~/.config/scripts/auto_hotspot.sh'

# Show weather
alias weather='curl wttr.in'

# aliases to show disk space and space used in a folder
alias diskspace="du -S | sort -n -r |more"
alias folders='du -h --max-depth=1'
alias folderssort='find . -maxdepth 1 -type d -print0 | xargs -0 du -sk | sort -rn'
alias tree='tree -CAhF --dirsfirst'
alias treed='tree -CAFd'
alias mountedinfo='df -hT'

# IP address lookup
alias whatismyip="whatsmyip"
function whatsmyip () {
    # Internal IP Lookup.
    if command -v ip &> /dev/null; then
        echo -n "Internal IP: "
        ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1
    else
        echo -n "Internal IP: "
        ifconfig wlan0 | grep "inet " | awk '{print $2}'
    fi

    # External IP Lookup
    echo -n "External IP: "
    curl -s ifconfig.me
}

#######################################################
# Customization
#######################################################

# Add prompt theme
eval "$(starship init bash)"

#######################################################
# Other
#######################################################

# Scan AUR Packages when installing using aur-scanner
source /usr/share/aur-scan/integration.bash
