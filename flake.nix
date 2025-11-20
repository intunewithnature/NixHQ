{
  description = "NixHQ VPS NixOS config";

  inputs = {
    # Pin to 25.05 release
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      commonModules = [ ./configuration.nix ];

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
