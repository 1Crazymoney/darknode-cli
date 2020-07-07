#!/bin/bash

set -u

main() {
    # Update this when minimum terraform version is changed.
    terraform_ver="0.12.24"

    # Exit if `darknode` is already installed
    if check_cmd darknode; then
        err "darknode-cli already installed on this machine"
    fi

    # Start installing
    echo "Installing Darknode CLI..."
    ProgressBar 0 100

    # Check prerequisites
    prerequisites $terraform_ver || return 1

    # Check system information
    ostype="$(uname -s | tr '[:upper:]' '[:lower:]')"
    cputype="$(uname -m | tr '[:upper:]' '[:lower:]')"
    check_architecture "$ostype" "$cputype"
    ProgressBar 10 100

    # Initialization
    ensure mkdir -p "$HOME/.darknode/darknodes"
    ensure mkdir -p "$HOME/.darknode/bin"

    # Install terraform
    if ! check_cmd terraform; then
        if [ $cputype = "x86_64" ];then
          cputype="amd64"
        fi
        terraform_url="https://releases.hashicorp.com/terraform/${terraform_ver}/terraform_${terraform_ver}_${ostype}_${cputype}.zip"
        ensure downloader "$terraform_url" "$HOME/.darknode/bin/terraform.zip"
        ensure unzip -qq "$HOME/.darknode/bin/terraform.zip" -d "$HOME/.darknode/bin"
        ensure chmod +x "$HOME/.darknode/bin/terraform"
    fi
    ProgressBar 50 100

    # Download nodectl binary
    nodectl_url="https://www.github.com/renproject/darknode-cli/releases/latest/download/darknode_${ostype}_${cputype}"
    ensure downloader "$nodectl_url" "$HOME/.darknode/bin/darknode"
    ensure chmod +x "$HOME/.darknode/bin/darknode"
    ProgressBar 90 100

    # Check shell type and set PATH variable.
    add_path
    ProgressBar 100 100

    # Output success message
    printf "\n\n"
    printf "Done! Restart terminal and run the command below to begin.\n"
    printf "\n"
    printf "darknode up --help\n"
}

# Check prerequisites for installing darknode-cli.
prerequisites() {
    # Check commands
    need_cmd uname
    need_cmd chmod
    need_cmd mkdir
    need_cmd rm
    need_cmd rmdir
    need_cmd unzip

    # Install unzip for user if not installed
    if ! check_cmd unzip; then
        if ! sudo apt-get install unzip ; then
             err "need 'unzip' (command not found)"
        fi
    fi

    # Check either curl or wget is installed.
    if ! check_cmd curl; then
        if ! check_cmd wget; then
          err "need 'curl' or 'wget' (command not found)"
        fi
    fi

    # Check if terraform has been installed.
    # If so, make sure it's newer than required version
    if check_cmd terraform; then
        version="$(terraform --version | grep 'Terraform v')"
        minor="$(echo $version | cut -d. -f2)"
        patch="$(echo $version | cut -d. -f3)"
        requiredMinor="$(echo $1 | cut -d. -f2)"
        requiredPatch="$(echo $1 | cut -d. -f3)"

        if [ "$minor" -lt "$requiredMinor" ]; then
          err "Please upgrade your terraform to version above 0.12.24"
        fi

        if [ "$patch" -lt "$requiredPatch" ]; then
          err "Please upgrade your terraform to version above 0.12.24"
        fi
    fi
}

# Check if darknode-cli supports given system and architecture.
check_architecture() {
    ostype="$1"
    cputype="$2"

    if [ "$ostype" = 'linux' -a "$cputype" = 'x86_64' ]; then
        :
    elif [ "$ostype" = 'linux' -a "$cputype" = 'aarch64' ]; then
        :
    elif [ "$ostype" = 'darwin' -a "$cputype" = 'x86_64' ]; then
        # Making sure OS-X is newer than 10.13
        if check_cmd sw_vers; then
            if [ "$(sw_vers -productVersion | cut -d. -f2)" -lt 13 ]; then
                err "Warning: Detected OS X platform older than 10.13"
            fi
        fi
    else
        echo 'unsupported OS type or architecture'
        exit 1
    fi
}

# Add the binary path to $PATH.
add_path(){
    if ! check_cmd darknode; then
      path=$SHELL
      shell=${path##*/}

      if [ "$shell" = 'zsh' ] ; then
        if [ -f "$HOME/.zprofile" ] ; then
          echo '\nexport PATH=$PATH:$HOME/.darknode/bin' >> $HOME/.zprofile
        elif [ -f "$HOME/.zshrc" ] ; then
          echo '\nexport PATH=$PATH:$HOME/.darknode/bin' >> $HOME/.zshrc
        elif [ -f "$HOME/.profile" ] ; then
          echo '\nexport PATH=$PATH:$HOME/.darknode/bin' >> $HOME/.profile
        fi
      elif  [ "$shell" = 'bash' ] ; then
        if [ -f "$HOME/.bash_profile" ] ; then
          echo '\nexport PATH=$PATH:$HOME/.darknode/bin' >> $HOME/.bash_profile
        elif [ -f "$HOME/.bashrc" ] ; then
          echo '\nexport PATH=$PATH:$HOME/.darknode/bin' >> $HOME/.bashrc
        elif [ -f "$HOME/.profile" ] ; then
          echo '\nexport PATH=$PATH:$HOME/.darknode/bin' >> $HOME/.profile
        else
          echo '\nexport PATH=$PATH:$HOME/.darknode/bin' >> $HOME/.bash_profile
        fi
      elif [ -f "$HOME/.profile" ] ; then
        echo '\nexport PATH=$PATH:$HOME/.darknode/bin' >> $HOME/.profile
      else
        echo '\nexport PATH=$PATH:$HOME/.darknode/bin' >> $HOME/.profile
      fi

      echo ''
      echo 'If you are using a custom shell, make sure you update your PATH.'
      echo "${GREEN}export PATH=\$PATH:\$HOME/.darknode/bin ${NC}"
    fi
}

# Source: https://sh.rustup.rs
check_cmd() {
    command -v "$1" > /dev/null 2>&1
}

# Source: https://sh.rustup.rs
need_cmd() {
    if ! check_cmd "$1"; then
        err "need '$1' (command not found)"
    fi
}

# Source: https://sh.rustup.rs
err() {
    echo "$1" >&2
    exit 1
}

# Source: https://sh.rustup.rs
ensure() {
    if ! "$@"; then err "command failed: $*"; fi
}

# This wraps curl or wget. Try curl first, if not installed, use wget instead.
# Source: https://sh.rustup.rs
downloader() {
    if check_cmd curl; then
        if ! check_help_for curl --proto --tlsv1.2; then
            echo "Warning: Not forcing TLS v1.2, this is potentially less secure"
            curl --silent --show-error --fail --location "$1" --output "$2"
        else
            curl --proto '=https' --tlsv1.2 --silent --show-error --fail --location "$1" --output "$2"
        fi
    elif check_cmd wget; then
        if ! check_help_for wget --https-only --secure-protocol; then
            echo "Warning: Not forcing TLS v1.2, this is potentially less secure"
            wget "$1" -O "$2"
        else
            wget --https-only --secure-protocol=TLSv1_2 "$1" -O "$2"
        fi
    else
        echo "Unknown downloader"   # should not reach here
    fi
}

# Source: https://sh.rustup.rs
check_help_for() {
    local _cmd
    local _arg
    local _ok
    _cmd="$1"
    _ok="y"
    shift

    for _arg in "$@"; do
        if ! "$_cmd" --help | grep -q -- "$_arg"; then
            _ok="n"
        fi
    done

    test "$_ok" = "y"
}

# Source: https://github.com/fearside/ProgressBar
function ProgressBar(){
    _progress=$((($1*100/$2)))
    _done=$(((_progress*4)/10))
    _left=$((40-_done))
    _done=$(printf "%${_done}s")
    _left=$(printf "%${_left}s")
    printf "\rProgress : [${_done// /#}${_left// /-}] ${_progress}%%"
}

main "$@" || exit 1
