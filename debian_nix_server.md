# Setting Up a New Debian Server with Nix and Home Manager

This guide provides instructions for setting up a new Debian server with Nix package manager, automating user creation, and using Home Manager for user-specific configurations.

## 1. Initial Server Setup

1. Spin up a new Debian server on AWS.
2. SSH into your new server using the provided key pair.

## 2. Install Nix Package Manager

1. Install Nix (as a non-root user):
   ```
   sh <(curl -L https://nixos.org/nix/install) --daemon
   ```

2. Source the Nix profile script:
   ```
   . ~/.nix-profile/etc/profile.d/nix.sh
   ```

## 3. Install Home Manager System-Wide

1. Add the Home Manager channel:
   ```
   sudo nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
   sudo nix-channel --update
   ```

2. Install Home Manager:
   ```
   sudo nix-shell '<home-manager>' -A install
   ```

## 4. Create a Script for Automated User Setup

Create a script named `setup_user.sh` with the following content:

```bash
#!/bin/bash

# Check if the script is run as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# Check if a username was provided
if [ $# -eq 0 ]
  then echo "Please provide a username"
  exit
fi

USERNAME=$1

# Create the user
adduser --disabled-password --gecos "" $USERNAME

# Add user to sudo group
usermod -aG sudo $USERNAME

# Set up SSH for the new user
mkdir -p /home/$USERNAME/.ssh
touch /home/$USERNAME/.ssh/authorized_keys
chmod 700 /home/$USERNAME/.ssh
chmod 600 /home/$USERNAME/.ssh/authorized_keys
chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh

# Add your SSH public key to the new user's authorized_keys file
echo "your_ssh_public_key" >> /home/$USERNAME/.ssh/authorized_keys

# Create Home Manager configuration
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
}
EOF

# Run home-manager switch for the new user
sudo -u $USERNAME home-manager switch

echo "User $USERNAME has been set up with Home Manager configuration."
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
