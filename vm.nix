{
  flake,
  modulesPath,
  stateVersion,
  hostPlatform,
  pkgs,
  ...
}: {
  imports = ["${modulesPath}/virtualisation/qemu-vm.nix"];
  # These values are tuned such that the VM performs on Github Actions runners.
  virtualisation = {
    forwardPorts = [
      {
        from = "host";
        host.port = 2222;
        guest.port = 22;
      }
    ];
    sharedDirectories = {
      workspace = {
        source = "$GITHUB_WORKSPACE";
        target = "/src";
      };
    };
    cores = 2;
    memorySize = 5120;
    diskSize = 10240;
  };

  system.stateVersion = stateVersion;
  nixpkgs.hostPlatform = hostPlatform;
  nixpkgs.overlays = [flake.outputs.overlay];

  nix = {
    settings = {
      substituters = [
        "https://ghostty.cachix.org/"
      ];
      trusted-public-keys = [
        "ghostty.cachix.org-1:QB389yTa6gTyneehvqG58y0WnHjQOqgnA+wBnpWWxns="
      ];
    };
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  # Root user without password and enabled SSH for playing around
  networking.firewall.enable = false;
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
    };
  };

  users.users = {
    root = {
      password = "password";
      openssh = {
        authorizedKeys = {
          keyFiles = [
            "${pkgs.ghostty-sshkeys}/id_ed25519.pub"
          ];
        };
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /src - - - - -"
  ];

  environment.systemPackages = [
    pkgs.git
    pkgs.zig
  ];
}
