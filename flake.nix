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
          modules = [ ./hosts/vps.nix ];
        };

        test-server = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./hosts/test-server.nix ];
        };
    };
  };
}
