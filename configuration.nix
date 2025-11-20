{ ... }:

{
  imports = [
    ./modules/common/system.nix
    ./modules/common/security.nix
    ./modules/common/docker.nix
    ./modules/common/caddy-stack.nix
    ./modules/users/app-user.nix
  ];
}
