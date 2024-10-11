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
if [ $# -eq 0 ]; then
  echo "Please provide a username"
  exit 1
fi

USERNAME=$1

# Create the user if it doesn't exist
if ! id "$USERNAME" &>/dev/null; then
  adduser --disabled-password --gecos "" $USERNAME
  usermod -aG sudo $USERNAME
else
  echo "User $USERNAME already exists. Skipping user creation."
fi

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

  programs.git = {
    enable = true;
    userName = "Your Name";
    userEmail = "your.email@example.com";
  };

  programs.tmux = {
    enable = true;
  };

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

echo "Nix and Home Manager have been added to $USERNAME's profile and bashrc."
echo "Setup completed successfully."

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
