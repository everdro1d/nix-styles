# nix-styles

Colorscheme helper for NixOS and Home Manager.

This tool allows you to create colorschemes/ themes, select a light & dark theme, switch between them very easily, and have a "one source of truth" for all your coloring needs.

> Why this? All I needed was a simple way to switch colorschemes, Stylix (among others) is good but did way too much for my needs. As such, nix-styles now exists to serve the purpose.

## Overview & TOC

Start by creating a colorscheme and defining colors in said scheme. Then call upon the color variables in your needed format from your configuration.

- [Setup](#setup)
  - [1. Add the flake input and module:](#1-add-the-flake-input-and-module)
    - [As a nixos module](#as-a-nixos-module)
    - [Or via home-manager](#or-via-home-manager)
  - [2. (Recommended Setup) Create a `nix-styles` directory:](#2-recommended-setup-create-a-nix-styles-directory)
    - [nix-styles.nix](#nix-stylesnix)
    - [default.nix](#defaultnix)
    - [theme-file.nix](#theme-filenix)
  - [(Optional) Theme Switching Script](#optional-theme-switching-script)
  - [(Extra) Write color info to file](#extra-write-color-info-to-file)
- [Usage](#usage)
- [Additional Accessors & Notes](#additional-accessors--notes)

## Setup

### 1. Add the flake input and module:

#### As a nixos module

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

#### Or via home-manager

```nix
{
  inputs = {
    home-manager.url = "github:nix-community/home-manager";
    nix-styles.url = "github:everdro1d/nix-styles";
  };

  outputs = { home-manager, nix-styles, ... }: {
    homeConfigurations.my-user = home-manager.lib.homeManagerConfiguration {
      modules = [
        nix-styles.homeModules.default
        ./nix-styles/default.nix
      ];
    };
  };
}
```

### 2. (Recommended Setup) Create a `nix-styles` directory:

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

### theme-file.nix

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

### (Optional) Theme Switching Script

```bash
#!/usr/bin/env bash

THEME_FILE="$NIX_DOTFILES/home-manager/nix-styles/is-dark"
CURRENT=$(cat "$THEME_FILE")

if [ "$CURRENT" == "dark" ]; then
    NEW="light"
else
    NEW="dark"
fi

echo "$NEW" > "$THEME_FILE"

notify-send "Theme Switching" "'$CURRENT' > '$NEW'\nReady for rebuild."

sudo nixos-rebuild switch --flake "$NIX_DOTFILES"

STATUS=$?

if [ $STATUS -eq 0 ]; then
    # tmux needs to re-source the config to update colors.
    pgrep "tmux" > /dev/null && tmux source-file ~/.config/tmux/tmux.conf
    notify-send "Theme Switched" "New theme is: '$NEW'"
else
    echo "$CURRENT" > "$THEME_FILE"
    notify-send "Theme Switch Cancelled" "'$NEW' > '$CURRENT'\nRebuild failed."
fi

```

### (Extra) Write color info to file
Example home-manager configuration for writing the active colors and theme information to a file.

```nix
{ self, config, lib, pkgs, ... }:
let
  darkFileContent = lib.strings.trim (builtins.readFile ./is-dark);

  theme-switch = pkgs.writeScriptBin "theme-switch" (builtins.readFile (self + /utils/theme-switch));

  mkColorFileContent = format:
    lib.concatStringsSep "\n"
      (lib.mapAttrsToList
        (key: value: ''${key}: "${value}"'')
        config.nix-styles.colors.${format})
    + "\n";

  themesFileContent =
    ''active: "${config.nix-styles.activeTheme}"'' + "\n" +
    ''light: "${config.nix-styles.lightTheme}"'' + "\n" +
    ''dark: "${config.nix-styles.darkTheme}"'' + "\n";

  colorFiles =
    lib.genAttrs [ "hex" "rgb" "hsl"] (format: pkgs.writeText format (mkColorFileContent format));
in
{
  nix-styles = {
    enable = true;

    isDark = (darkFileContent == "dark");

    lightTheme = "kanagawa-lotus";
    darkTheme = "kanagawa-wave";

    strictColors = true;
  };

  home = {
    packages = [
      theme-switch
    ];

    file = {
      ".config/nix-styles/is-dark".source = pkgs.writeText "is-dark" darkFileContent;
      ".config/nix-styles/themes".source = pkgs.writeText "themes" themesFileContent;
    } // (lib.mapAttrs' (format: derivation:
      lib.nameValuePair ".config/nix-styles/${format}" { source = derivation; }
    ) colorFiles);
  };
}

```


## Usage

Access colors from the active theme:

```nix
{
  # Raw declared value:
  background.color = config.nix-styles.colors.raw.bg;

  # Converted value:
  border.color = config.nix-styles.colors.rgb.bg;

  # Numeric-only accessor:
  border.color = "rgb(${config.nix-styles.colors.inner.rgb.bg})";
}
```

Available accessors:

* `config.nix-styles.colors.raw.<name>` (raw value as declared)
* `config.nix-styles.colors.hex.<name>`
* `config.nix-styles.colors.rgb.<name>`
* `config.nix-styles.colors.hsl.<name>`
* `config.nix-styles.colors.inner.<format>.<name>` (numeric portion)

## Additional Accessors & Notes

* `activeTheme` returns the name of the active theme.
* `lightTheme` and `darkTheme` must reference existing entries in `nix-styles.themes`.
* Invalid color strings cause evaluation to fail when `strictColors = true`; set it to `false` to keep raw values.
