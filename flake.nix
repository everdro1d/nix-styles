{
  description = "nix-styles configuration helper";

  outputs = { self }:
    {
      nixosModules.default = import ./modules/nix-styles.nix;
      homeManagerModules.default = import ./modules/nix-styles.nix;
    };
}
