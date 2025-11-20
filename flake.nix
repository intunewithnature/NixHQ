{
  description = "NixHQ VPS NixOS config";

  inputs = {
    # 25.05 pinned to the commit captured in flake.lock
    nixpkgs.url = "github:NixOS/nixpkgs/4c8cdd5b1a630e8f72c9dd9bf582b1afb3127d2c";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, sops-nix }:
    let
      lib = nixpkgs.lib;
      commonModules = [
        ./configuration.nix
        sops-nix.nixosModules.sops
      ];

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
              system = "x86_64-linux";
              modules = commonModules ++ [ host.hardware host.role ];
            })
          hosts;
    };
}
