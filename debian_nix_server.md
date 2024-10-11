# Setting Up a New Debian Server with Nix and SSH Configuration

This guide provides step-by-step instructions for setting up a new Debian server with Nix package manager and configuring SSH for passwordless access.

## 1. Initial Server Setup

1. Spin up a new Debian server on AWS.
2. SSH into your new server using the provided key pair.

## 2. Install Nix Package Manager

1. Install the required dependencies:
   ```
   sudo apt-get update
   sudo apt-get install -y curl xz-utils
   ```

2. Install Nix (as a non-root user):
   ```
   sh <(curl -L https://nixos.org/nix/install) --daemon
   ```

3. Source the Nix profile script:
   ```
   . ~/.nix-profile/etc/profile.d/nix.sh
   ```

## 3. Configure SSH for Passwordless Access

1. On your local machine, ensure you have an SSH key pair. If not, create one:
   ```
   ssh-keygen -t ed25519 -C "your_email@example.com"
   ```

2. Copy your public key to the server:
   ```
   ssh-copy-id -i ~/.ssh/id_ed25519.pub user@your_server_ip
   ```

3. On the server, edit the SSH configuration file:
   ```
   sudo nano /etc/ssh/sshd_config
   ```
   Ensure the following lines are present and uncommented:
   ```
   PubkeyAuthentication yes
   PasswordAuthentication no
   ```

4. Restart the SSH service:
   ```
   sudo systemctl restart sshd
   ```

## 4. Install and Configure Home Manager

1. Add the Home Manager channel:
   ```
   nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
   nix-channel --update
   ```

2. Install Home Manager:
   ```
   nix-shell '<home-manager>' -A install
   ```

3. Create or edit your Home Manager configuration file:
   ```
   nano ~/.config/nixpkgs/home.nix
   ```

4. Add the following content to `home.nix`:
   ```nix
   { config, pkgs, ... }:

   {
     home.username = "your_username";
     home.homeDirectory = "/home/your_username";
     home.stateVersion = "21.11";

     programs.home-manager.enable = true;

     home.packages = with pkgs; [
       neovim
       git
       tmux
     ];

     programs.keychain = {
       enable = true;
       keys = [ "id_ed25519" ];
       agents = [ "ssh" ];
       extraFlags = [ "--quiet" ];
     };

     programs.ssh = {
       enable = true;
       extraConfig = ''
         Host *
           AddKeysToAgent yes
           UseKeychain yes
           IdentityFile ~/.ssh/id_ed25519
       '';
     };

     programs.bash = {
       enable = true;
       initExtra = ''
         eval $(keychain --eval --quiet id_ed25519)
       '';
     };
   }
   ```

5. Apply the configuration:
   ```
   home-manager switch
   ```

## 5. Configure Local Machine

1. On your local machine, edit your SSH config file:
   ```
   nano ~/.ssh/config
   ```

2. Add the following content:
   ```
   Host your_server_name
       HostName your_server_ip
       User your_username
       ForwardAgent yes

   Host *
       AddKeysToAgent yes
       UseKeychain yes
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

## 6. Final Steps

1. Restart your local terminal or run:
   ```
   source ~/.bashrc
   ```

2. Test the connection:
   ```
   ssh your_server_name
   ```

3. Verify that neovim, git, and tmux are installed:
   ```
   nvim --version
   git --version
   tmux -V
   ```

You should now be able to SSH into your server without entering a passphrase, and Git operations should work seamlessly. Additionally, you'll have neovim, git, and tmux available for use.

Remember to replace placeholders like `your_username`, `your_server_ip`, and `your_server_name` with your actual values.
