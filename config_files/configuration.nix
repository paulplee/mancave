# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "ae86"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Asia/Hong_Kong";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_HK.UTF-8";

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Set environment variables
  environment.variables = {
    CHROME_EXECUTABLE = "/run/current-system/sw/bin/chromium";
    JAVA_HOME = "/run/current-system/sw";
    STUDIO_JDK = "/run/current-system/sw";
  };

  # Add JAVA_HOME to PATH
  environment.shellInit = ''
    export PATH=$JAVA_HOME/bin:$PATH
  '';

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.paulplee = {
    isNormalUser = true;
    description = "Paul Lee";
    extraGroups = [ "networkmanager" "wheel" "adbusers"];
    packages = with pkgs; [
      kdePackages.kate
    #  thunderbird
    ];
  };

  # Mount /data
  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/bcb5f873-0bbb-4bd9-ba25-0daefd88dd45";
    fsType = "auto";
  };

  # Install firefox.
  programs.firefox.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # System Level Tools
    direnv
    kitty
    openssh
    tmux
    cowsay

    # Development
    jdk
    git
    python3
    flutter
    android-studio
    neovim
    vscode

    # Browsers
    ungoogled-chromium
    microsoft-edge

    # Messaging
    telegram-desktop
    whatsapp-for-linux
    zoom-us

    # Productivity
    obsidian 
  ];


  programs = {
    adb.enable = true;
    ssh.startAgent = true;
  };

  system.userActivationScripts = {
    stdio = {
      text = ''
        rm -f ~/Android/Sdk/platform-tools/adb
        ln -s /run/current-system/sw/bin/adb ~/Android/Sdk/platform-tools/adb
      '';
      deps = [
      ];
    };
  };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; 
}
