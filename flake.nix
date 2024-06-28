{
  inputs = {
    nixpkgs-23-05 = {
      url = "github:nixos/nixpkgs/nixos-23.05";
    };
    nixpkgs-23-11 = {
      url = "github:nixos/nixpkgs/nixos-23.11";
    };
    nixpkgs-24-05 = {
      url = "github:nixos/nixpkgs/nixos-24.05";
    };
    nixpkgs-unstable = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };
    zig = {
      url = "github:mitchellh/zig-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs-unstable";
        flake-compat.follows = "";
      };
    };
  };
  outputs = {
    self,
    nixpkgs-unstable,
    zig,
    ...
  } @ inputs:
    builtins.foldl' nixpkgs-unstable.lib.recursiveUpdate {} (builtins.map (system: let
      versions = ["23.05" "23.11" "24.05" "unstable"];
      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
      };
      # ghostty-source = pkgs-unstable.stdenvNoCC.mkDerivation {
      #   name = "ghostty-source";
      #   src = ./.;
      #   dontPatch = true;
      #   dontConfgure = true;
      #   dontBuild = true;
      #   doTest = false;
      #   installPhase = ''
      #     cp -rv $src $out
      #   '';
      # };
      ghostty-sshkeys = pkgs-unstable.runCommand "ghostty-sshkeys" {} ''
        mkdir -p $out
        ${pkgs-unstable.openssh}/bin/ssh-keygen -C "" -N "" -t ed25519 -f $out/id_ed25519
      '';
    in {
      overlay = final: prev: {
        inherit ghostty-sshkeys;
        zig = zig.packages.${prev.system}."0.13.0";
      };
      packages.${system} =
        {
          vm-ssh = pkgs-unstable.writeScriptBin "ssh" ''
            ${pkgs-unstable.openssh}/bin/ssh -F none -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=ERROR -i ${ghostty-sshkeys}/id_ed25519 ssh://root@localhost:2222  "$@"
          '';
        }
        // (
          builtins.listToAttrs
          (
            builtins.map (
              version: let
                v = builtins.replaceStrings ["."] ["-"] version;
              in {
                name = "vm-${v}";
                value = self.nixosConfigurations."vm-${v}-${system}".config.system.build.vm;
              }
            )
            versions
          )
        );
      nixosConfigurations =
        builtins.listToAttrs
        (
          builtins.map (
            version: let
              v = builtins.replaceStrings ["."] ["-"] version;
            in {
              name = "vm-${v}-${system}";
              value = inputs."nixpkgs-${v}".lib.nixosSystem {
                specialArgs = {
                  stateVersion = version;
                  hostPlatform = system;
                  flake = self;
                };
                modules = [./vm.nix];
              };
            }
          )
          versions
        );
    }) (builtins.attrNames zig.packages));
}
