# Setting Up a New Debian Server with Nix and Home Manager

This guide provides instructions for setting up a new Debian server with Nix package manager, automating user creation, and using Home Manager for user-specific configurations.

## 1. Initial Server Setup

1. Spin up a new Debian server on AWS.
2. SSH into your new server using the provided key pair.

## 2. Install Nix Package Manager

1. Install Nix (as a root user):
   ```
   sh <(curl -L https://nixos.org/nix/install) --daemon
   ```

2. Source the Nix profile script:
   ```
   . /etc/profile.d/nix.sh
   ```

## 3. Install Home Manager System-Wide

1. Add the Home Manager channel:
   ```
   nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
   nix-channel --update
   ```

2. Install Home Manager:
   ```
   nix-shell '<home-manager>' -A install
   ```

## 4. Create a Script for Automated User Setup

Create a script named `setup_user.sh` with the following content:

```bash
#!/bin/bash

set -e

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Check if a username was provided
if [ $# -lt 3 ]; then
  echo "Usage: $0 <username> <git_user_name> <git_user_email>"
  exit 1
fi

USERNAME=$1
GIT_USER_NAME=$2
GIT_USER_EMAIL=$3

# Create the user if it doesn't exist
if ! id "$USERNAME" &>/dev/null; then
  adduser --disabled-password --gecos "" $USERNAME
  usermod -aG sudo $USERNAME
else
  echo "User $USERNAME already exists. Skipping user creation."
fi

# Configure sudo access without password for the new user
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" | EDITOR='tee -a' visudo

# Set up SSH for the new user
mkdir -p /home/$USERNAME/.ssh
chmod 700 /home/$USERNAME/.ssh
cp /home/admin/.ssh/authorized_keys /home/$USERNAME/.ssh/authorized_keys
chmod 600 /home/$USERNAME/.ssh/authorized_keys
chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh

# Ensure the user is in the necessary groups for Nix
usermod -aG nixbld $USERNAME

# Source Nix environment
. /etc/profile.d/nix.sh

# Install home-manager
echo "Installing home-manager..."
sudo -i -u $USERNAME bash << EOF
  . /etc/profile.d/nix.sh
  nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
  nix-channel --update
  export NIX_PATH=\$HOME/.nix-defexpr/channels\${NIX_PATH:+:}\$NIX_PATH
  nix-shell '<home-manager>' -A install
EOF

# Create Home Manager configuration
echo "Creating Home Manager configuration..."
sudo -u $USERNAME mkdir -p /home/$USERNAME/.config/nixpkgs
sudo -u $USERNAME tee /home/$USERNAME/.config/nixpkgs/home.nix << EOF
{ config, pkgs, ... }:

{
  home.username = "$USERNAME";
  home.homeDirectory = "/home/$USERNAME";
  home.stateVersion = "21.11";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    neovim
    git
    tmux
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  home.sessionPath = [
    "\$HOME/.nix-profile/bin"
  ];
}
EOF

# Run home-manager switch for the new user
echo "Running home-manager switch..."
sudo -i -u $USERNAME bash << EOF
  set -x
  . /etc/profile.d/nix.sh
  export NIX_PATH=\$HOME/.nix-defexpr/channels\${NIX_PATH:+:}\$NIX_PATH
  home-manager switch
  set +x
  echo "Home Manager switch completed."
  echo "Installed packages:"
  ls -l \$HOME/.nix-profile/bin
EOF

echo "User $USERNAME has been set up with Home Manager configuration."

# Manually link packages if they're not available
echo "Ensuring packages are linked..."
sudo -i -u $USERNAME bash << EOF
  set -x
  . /etc/profile.d/nix.sh
  for pkg in neovim git tmux; do
    if ! command -v \$pkg &> /dev/null; then
      echo "\$pkg not found, attempting to link..."
      nix-env -iA nixpkgs.\$pkg
    fi
  done
  set +x
EOF

# Update .profile
sudo -u $USERNAME tee /home/$USERNAME/.profile << EOF
# ~/.profile: executed by the command interpreter for login shells.

# Nix
if [ -e /etc/profile.d/nix.sh ]; then
  . /etc/profile.d/nix.sh
fi

# set PATH so it includes user's private bin if it exists
if [ -d "\$HOME/bin" ] ; then
    PATH="\$HOME/bin:\$PATH"
fi

# set PATH so it includes user's private .local/bin if it exists
if [ -d "\$HOME/.local/bin" ] ; then
    PATH="\$HOME/.local/bin:\$PATH"
fi

# Home Manager
export NIX_PATH=\$HOME/.nix-defexpr/channels\${NIX_PATH:+:}\$NIX_PATH
export PATH=\$HOME/.nix-profile/bin:\$PATH

EOF

# Update .bashrc
sudo -u $USERNAME tee /home/$USERNAME/.bashrc << EOF
# ~/.bashrc: executed by bash(1) for non-login shells.

# If not running interactively, don't do anything
case \$- in
    *i*) ;;
      *) return;;
esac

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# Source .profile if it exists
if [ -f "\$HOME/.profile" ]; then
  . "\$HOME/.profile"
fi

# Initialize Home Manager
if [ -f "\$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
  . "\$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
fi

EOF

# Configure git
echo "Configuring git..."
sudo -i -u $USERNAME bash << EOF
  . /etc/profile.d/nix.sh
  export PATH=\$HOME/.nix-profile/bin:\$PATH
  git config --global user.name "$GIT_USER_NAME"
  git config --global user.email "$GIT_USER_EMAIL"
  git config --global core.editor "nvim"
  git config --global color.ui true
  echo "Git configuration:"
  git config --list --global
EOF

# Configure tmux
echo "Configuring tmux..."
sudo -i -u $USERNAME bash << EOF
  . /etc/profile.d/nix.sh
  export PATH=\$HOME/.nix-profile/bin:\$PATH
  
  # Create .tmux.conf file
  cat > ~/.tmux.conf << EOT
set -g default-terminal "screen-256color"

unbind %
bind | split-window -h

unbind '"'
bind - split-window -v

unbind r
bind r source-file ~/.tmux.conf

bind -r j resize-pane -D 5
bind -r k resize-pane -U 5
bind -r l resize-pane -R 5
bind -r h resize-pane -L 5

bind -r m resize-pane -Z

set -g mouse on

set-window-option -g mode-keys vi

bind-key -T copy-mode-vi 'v' send -X begin-selection # start selecting text with "v"
bind-key -T copy-mode-vi 'y' send -X copy-selection # copy text with "y"

unbind -T copy-mode-vi MouseDragEnd1Pane # don't exit copy mode after dragging with mouse

# tpm plugin
set -g @plugin 'tmux-plugins/tpm'

# list of tmux plugins
set -g @plugin 'christoomey/vim-tmux-navigator' # for navigating panes and vim/nvim with Ctrl-hjkl
set -g @plugin 'jimeh/tmux-themepack' # to configure tmux theme
set -g @plugin 'tmux-plugins/tmux-resurrect' # persist tmux sessions after computer restart
set -g @plugin 'tmux-plugins/tmux-continuum' # automatically saves sessions for you every 15 minutes

set -g @themepack 'powerline/default/cyan' # use this theme for tmux

set -g @resurrect-capture-pane-contents 'on' # allow tmux-ressurect to capture pane contents
set -g @continuum-restore 'on' # enable tmux-continuum functionality

# Initialize TMUX plugin manager (keep this line at the very bottom of tmux.conf)
run '~/.tmux/plugins/tpm/tpm'
EOT

  echo "Tmux configuration file created at ~/.tmux.conf"
EOF

# Install tmux plugin manager (tpm)
echo "Checking and installing tmux plugin manager (tpm) if necessary..."
sudo -i -u $USERNAME bash << EOF
  set -e
  . /etc/profile.d/nix.sh
  export PATH=\$HOME/.nix-profile/bin:\$PATH
  if [ ! -d ~/.tmux/plugins/tpm ]; then
    if command -v git &> /dev/null; then
      git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
      echo "Tmux plugin manager (tpm) installed."
    else
      echo "Error: git command not found. Please ensure git is installed and in the PATH."
      exit 1
    fi
  else
    echo "Tmux plugin manager (tpm) is already installed."
  fi
EOF

echo "Nix and Home Manager have been added to $USERNAME's profile and bashrc."
echo "Setup completed successfully."
echo "Note: The user may need to restart their tmux session or run 'tmux source ~/.tmux.conf' to apply the changes."
echo "To install tmux plugins, the user should open a tmux session and press prefix + I."

```

Make the script executable:
```
chmod +x setup_user.sh
```

## 5. Use the Script to Create and Set Up a New User

To create a new user and set up their environment, run:

```
sudo ./setup_user.sh newusername
```

Replace "newusername" with the desired username.

## 6. Configure SSH on the Server

1. Edit the SSH configuration file:
   ```
   sudo nano /etc/ssh/sshd_config
   ```

2. Ensure the following lines are present and uncommented:
   ```
   PubkeyAuthentication yes
   PasswordAuthentication no
   ```

3. Restart the SSH service:
   ```
   sudo systemctl restart sshd
   ```

## 7. Configure Local Machine

1. On your local machine, edit your SSH config file:
   ```
   nano ~/.ssh/config
   ```

2. Add the following content:
   ```
   Host your_server_name
       HostName your_server_ip
       User newusername
       ForwardAgent yes

   Host *
       AddKeysToAgent yes
       IdentityFile ~/.ssh/id_ed25519
   ```

3. If you're using VSCode, update your workspace settings:
   ```json
   {
       "terminal.integrated.env.osx": {
           "SSH_AUTH_SOCK": "${env:SSH_AUTH_SOCK}"
       },
       "remote.SSH.useLocalServer": false,
       "remote.SSH.showLoginTerminal": true,
       "remote.SSH.enableAgentForwarding": true
   }
   ```

## 8. Final Steps

1. Test the connection from your local machine:
   ```
   ssh your_server_name
   ```

2. Verify that neovim, git, and tmux are installed:
   ```
   nvim --version
   git --version
   tmux -V
   ```

You should now be able to SSH into your server without entering a passphrase, and Git operations should work seamlessly. Additionally, you'll have neovim, git, and tmux available for use.

Remember to replace placeholders like `newusername`, `your_server_ip`, `your_server_name`, and `your_ssh_public_key` with your actual values.

## 9. Updating Home Manager Configuration

If you need to make changes to your Home Manager setup:

1. Edit the `~/.config/nixpkgs/home.nix` file.
2. Apply the changes with:
   ```
   home-manager switch
   ```

This will update your user-specific configuration managed by Home Manager.

Note: While Home Manager is installed system-wide, each user maintains their own configuration in their home directory. The `home-manager switch` command applies these user-specific configurations.
