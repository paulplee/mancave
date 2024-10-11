# Setting Up a New Debian Server with Nix and SSH Configuration

This guide provides step-by-step instructions for setting up a new Debian server with Nix package manager and configuring SSH for passwordless access.

## 1. Initial Server Setup

1. Spin up a new Debian server on AWS.
2. SSH into your new server using the provided key pair.

## 2. Cleanup Existing User (If Necessary)

If you've previously created a user (e.g., 'paulplee') and want to start fresh, follow these steps to clean up the user account and associated Nix setup:

1. Switch to the root user:
   ```
   sudo su -
   ```

2. Remove the user from the system:
   ```
   sudo userdel paulplee
   ```

3. Manually remove the user's home directory:
   ```
   sudo rm -rf /home/paulplee
   ```

4. Remove the user from the sudo group (if necessary):
   ```
   sudo gpasswd -d paulplee sudo
   ```

5. Remove any Nix-related directories for the user:
   ```
   sudo rm -rf /nix/var/nix/profiles/per-user/paulplee
   sudo rm -rf /nix/var/nix/gcroots/per-user/paulplee
   ```

6. Clean up any remaining files or directories created by the user:
   ```
   sudo find / -user paulplee -delete
   ```

7. Optionally, if you want to remove Nix completely (only if you plan to reinstall):
   ```
   sudo rm -rf /nix
   sudo rm /etc/profile.d/nix.sh
   ```

After completing these steps, you can proceed with creating a new user and setting up Nix as described in the following sections.

## 3. Create a New User

1. Create a new user (replace 'newuser' with your desired username):
   ```
   sudo adduser newuser
   ```

2. Add the new user to the sudo group:
   ```
   sudo usermod -aG sudo newuser
   ```

3. Switch to the new user:
   ```
   su - newuser
   ```

4. Set up SSH for the new user:
   ```
   mkdir ~/.ssh
   chmod 700 ~/.ssh
   touch ~/.ssh/authorized_keys
   chmod 600 ~/.ssh/authorized_keys
   ```

5. Copy your SSH public key to the new user's authorized_keys file:
   ```
   echo "your_ssh_public_key" >> ~/.ssh/authorized_keys
   ```
   Replace "your_ssh_public_key" with the content of your local machine's ~/.ssh/id_ed25519.pub file.

6. Test SSH access with the new user from your local machine:
   ```
   ssh newuser@your_server_ip
   ```

7. If the SSH connection is successful, you can now use this new user for the rest of the setup process.

## 4. Install Nix Package Manager

1. Install the required dependencies:
   ```
   sudo apt-get update
   ```

2. Install Nix (as a non-root user):
   ```
   sh <(curl -L https://nixos.org/nix/install) --daemon
   ```

3. Source the Nix profile script:
   ```
   . ~/.nix-profile/etc/profile.d/nix.sh
   ```

## 5. Configure SSH for Passwordless Access

1. On your local machine, ensure you have an SSH key pair. If not, create one:
   ```
   ssh-keygen -t ed25519 -C "your_email@example.com"
   ```

2. Copy your public key to the server:
   ```
   ssh-copy-id -i ~/.ssh/id_ed25519.pub newuser@your_server_ip
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

## 6. Install and Configure Home Manager

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
     home.username = "newuser";
     home.homeDirectory = "/home/newuser";
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

## 7. Configure Local Machine

1. On your local machine, edit your SSH config file:
   ```
   nano ~/.ssh/config
   ```

2. Add the following content:
   ```
   Host your_server_name
       HostName your_server_ip
       User newuser
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

Remember to replace placeholders like `newuser`, `your_server_ip`, and `your_server_name` with your actual values.
