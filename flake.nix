{
  description = "nix-styles configuration helper";

  outputs = { self }:
    {
      nixosModules.default = import ./modules/nix-styles.nix;
      homeModules.default = import ./modules/nix-styles.nix;
    };
}
