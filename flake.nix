{
  description = "NixHQ VPS NixOS config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = inputs@{ nixpkgs, ... }:
    let
      inherit (nixpkgs) lib;
      system = "x86_64-linux";
      hosts = {
        vps = {
          hardware = ./hardware-vps.nix;
          role = ./hosts/vps.nix;
        };
        test-server = {
          hardware = ./hardware-test-server.nix;
          role = ./hosts/test-server.nix;
        };
      };
    in {
      nixosConfigurations =
        lib.mapAttrs
          (_: host:
            lib.nixosSystem {
              inherit system;
              modules = [
                ./configuration.nix
                host.hardware
                host.role
              ];
              specialArgs = { inherit inputs; };
            })
          hosts;
    };
}
