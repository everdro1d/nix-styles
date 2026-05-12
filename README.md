# nix-styles

Colorscheme helper for NixOS and Home Manager.

## Setup

1. Add the flake input and module:

```nix
{
  inputs.nix-styles.url = "github:everdro1d/nix-styles";

  outputs = { self, nixpkgs, nix-styles, ... }: {
    nixosConfigurations.my-host = nixpkgs.lib.nixosSystem {
      modules = [
        nix-styles.nixosModules.default
        ./nix-styles/default.nix
      ];
    };
  };
}
```

2. Recommended Setup - Create a `nix-styles` directory:

```
nix-styles/
| themes/
| | kanagawa-lotus.nix
| | kanagawa-wave.nix
| is-dark
| default.nix
| nix-styles.nix
```

### nix-styles.nix

```nix
{ ... }:
{
  nix-styles = {
    enable = true;

    # boolean - accepts true or false (recommended to use a file for easy scripting).
    isDark = (lib.strings.trim (builtins.readFile ./is-dark) == "dark");

    lightTheme = "kanagawa-lotus";
    darkTheme = "kanagawa-wave";

    # Optional: allow invalid/legacy colors without failing evaluation.
    strictColors = false;
  };
}
```

### default.nix

```nix
{
  imports = [
    ./nix-styles.nix

    ./themes/kanagawa-lotus.nix
    ./themes/kanagawa-wave.nix
  ];
}
```

### Theme file

```nix
{ ... }:
{
  nix-styles.themes.kanagawa-wave = {
    colors = {
      fg = "#FFFFFF";
      bg = "rgb(255,255,255)";
      # and more...
    };
  };
}
```
## Usage

Access colors from the active theme:

```nix
{
  # Raw declared value:
  background.color = config.nix-styles.colors.bg;

  # Converted value:
  border.color = config.nix-styles.colors.bg.rgb;

  # Numeric-only accessor:
  border.color = "rgb(${config.nix-styles.colors.bg.rgb.inner})";
}
```

Each color supports:

* `config.nix-styles.colors.<name>` (raw value as declared)
* `config.nix-styles.colors.<name>.hex`
* `config.nix-styles.colors.<name>.rgb`
* `config.nix-styles.colors.<name>.hsl`
* `config.nix-styles.colors.<name>.<format>.inner` (numeric portion)

## Notes

* `activeTheme` returns the name of the active theme.
* `lightTheme` and `darkTheme` must reference existing entries in `nix-styles.themes`.
* Extra attributes inside `nix-styles.themes` are ignored.
* Invalid color strings cause evaluation to fail when `strictColors = true`; set it to `false` to keep raw values.
