{ ... }:

{
  imports = [
    ./modules/base-system.nix
    ./modules/security.nix
    ./modules/docker-host.nix
    ./modules/users/app-user.nix
  ];
}
