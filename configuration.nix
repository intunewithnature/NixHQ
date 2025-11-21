{ inputs, ... }:

{
  imports = [
    inputs.sops-nix.nixosModules.sops
    ./modules/common/system.nix
    ./modules/common/security.nix
    ./modules/common/docker.nix
    ./modules/common/impious-stack.nix
    ./modules/users/app-user.nix
  ];

  ################################ System State Version ################################
  system.stateVersion = "25.05";
}
