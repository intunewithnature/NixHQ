{
  description = "NixHQ VPS NixOS config";

  inputs = {
    # Pin to 25.05 release
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = { self, nixpkgs }: {
    nixosConfigurations = {
      vps = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [
          ./configuration.nix
          ./hardware-vps.nix
          ./modules/caddy-prod.nix
          { networking.hostName = "impious-vps"; }
        ];
      };

      test-server = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [
          ./configuration.nix
          ./hardware-test-server.nix
          ./modules/caddy-staging.nix
          { networking.hostName = "test-server"; }
        ];
      };
    };
  };
}
