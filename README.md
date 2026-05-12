# nix-styles

Declarative colorscheme helper for NixOS and Home Manager.

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

2. Create a `nix-styles` directory in your dotfiles:

```
nix-styles/
| themes/
| | kanagawa-lotus.nix
| | kanagawa-wave.nix
| active-theme
| default.nix
| nix-styles.nix
```

### nix-styles.nix

```nix
{ ... }:
{
  nix-styles = {
    enable = true;

    # "light" or "dark" (whitespace is trimmed automatically)
    activeTheme = builtins.readFile ./active-theme;

    lightTheme = "kanagawa-lotus";
    darkTheme = "kanagawa-wave";

    # Optional: allow invalid/legacy colors without failing evaluation.
    strictColors = true;
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
    theme.dark = true;

    colors = {
      fg = "#FFFFFF";
      bg = "#000000";
    };
  };
}
```

### active-theme

```
dark
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
  border.color = config.nix-styles.colors.bg.rgb.inner;
}
```

Each color supports:

* `config.nix-styles.colors.<name>` (raw value as declared)
* `config.nix-styles.colors.<name>.hex`
* `config.nix-styles.colors.<name>.rgb`
* `config.nix-styles.colors.<name>.hsl`
* `config.nix-styles.colors.<name>.<format>.inner` (numeric portion)

Format accessors coerce to strings in string contexts (for example, `"${config.nix-styles.colors.bg.rgb}"`).

## Notes

* `activeTheme` must be `"light"` or `"dark"`. Any other value triggers a warning and falls back to `"dark"`.
* `lightTheme` and `darkTheme` must reference existing entries in `nix-styles.themes`.
* Extra attributes inside `nix-styles.themes` are ignored with a warning.
* Invalid color strings fail evaluation when `strictColors = true`; set it to `false` to keep raw values.
