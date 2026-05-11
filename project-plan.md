# Project Context: `nix-styles` Configuration Helper

**Overview:** `nix-styles` is a declarative module for NixOS and Home Manager designed to act as a colorscheme helper. It simplifies the definition, selection, and injection of color variables across system configurations.

**User Flow:** The end-user adds the flake input, creates a `nix-styles` directory, and defines colorschemes containing variables like `theme.dark` (boolean) and `colors` (hex, rgb, hsl strings). The user selects an active scheme, and the module evaluates these into read-only outputs (`config.nix-styles.colors` and `config.nix-styles.theme.dark`) to be used in configuration files (e.g., Hyprland, GTK, Neovim).

---

## Task 1: Core Module Architecture
**Context:** This task establishes the foundational Nix structures required to expose the module and define the schema for user inputs.

* **Task 1.1: Flake Initialization**
  * **Objective:** Create the base `flake.nix` that exports the module.
  * **Deliverables:** A `flake.nix` file exposing `outputs.nixosModules.default` and `outputs.homeManagerModules.default`.

* **Task 1.2: Module Options Definition**
  * **Objective:** Define the configuration options using standard Nix `lib` types to ensure type safety.
  * **Deliverables:** A Nix module containing:
    * `options.nix-styles.enable` (boolean, default false).
    * `options.nix-styles.activeTheme` (string, either of "light" or "dark").
    * `options.nix-styles.lightTheme` (string).
    * `options.nix-styles.darkTheme` (string).
    * A submodule schema for defining themes, strictly enforcing `name` (string, defaults to module name i.e. "nix-styles.themes.kanagawa" > theme name = "kanagawa"), `theme.dark` (boolean) and `colors` (attribute set of strings).
  * **Details to note:**
    * The `activeTheme` option must only accept the values "light" or "dark". This input will determine whether `lightTheme` or `darkTheme` is used to populate the exported color values. Users cannot select arbitrary themes; the active mode is always determined by this binary switch.
    * Only the selected (active) theme is loaded into the exported config. The theme’s name is automatically derived from the attribute key in `nix-styles.themes` and does not need to be repeated or explicitly declared inside the theme definition.
    * If the `activeTheme` value does not match "light" or "dark", a warning is issued and the system will fallback to "dark" mode.
    * The module checks that lightTheme and darkTheme refer to valid, existing themes in `nix-styles.themes`. If either reference is invalid, a configuration error is raised and evaluation fails.
    * Only the prescribed theme fields are supported; arbitrary extra fields or attributes are not required and will be ignored with warning.


## Task 2: User Implementation Flow & Logic
**Context:** This task focuses on the evaluation logic and the boilerplate configuration that end-users will interact with. The module must correctly read the user's selected theme and populate the output variables.

* **Task 2.1: Theme Evaluation Logic**
  * **Objective:** Write the Nix configuration block that evaluates the active theme based on user selection, binding the selected theme's values to the global config.
  * **Deliverables:**
    * Nix logic that populates `config.nix-styles.colors` and `config.nix-styles.theme.dark` based on the values of the active theme defined in `lightTheme` or `darkTheme`.
    * Values to access converted colors so that a user can call: `config.nix-styles.colors.my-color.[OPT]`, where OPT = [ "hex", "rgb", "hsl" ].
      OPT should be optional. If it is not included, then take the color as it was declared in the theme, else use the converted type.
      Ex: User declared `foreground = "#FFFFFF";` in theme colors. User calls `...colors.foreground.rgb`, it provides `rgb(255,255,255)`. User calls `...colors.foreground`, it provides `#FFFFFF`. The point is to make it accessible and flexible.
  * **Details to note:**
    * Per-color accessors are supported for both raw values and converted formats. Acceptable color definitions include hex, rgb, and hsl notation. Each color supports a special inner accessor (e.g., `...colors.bg.rgb.inner`) that returns just the numeric portion of the string (hex: "FFFFFF", rgb: "255,255,255", hsl: "0,0%,100%"). If a color cannot be converted, a Nix warning is issued. If the color is invalid (e.g. malformed hex), a configuration error is raised. An override can optionally allow bypassing strict error checks for legacy/flexible input.
    * Output variables are intended solely for use within declarative config.
    * The module’s logic-including theme evaluation, color conversion, validation, and output structure-is consistent and identical between Home Manager and NixOS module usage.

* **Task 2.2: User Boilerplate & Documentation**
  * **Objective:** Create the standard directory structure and file templates for the end-user in the readme.
  * **Deliverables:**
    * A sample `default.nix` that imports custom scheme files.
    * A template `nix-styles.nix` demonstrating how to enable the module and select themes.
    * A markdown `README.md` detailing the setup instructions.

## Example Usage:

User Config Directory Layout:
```
nix-styles/
| themes/
| | kanagawa.nix
| active-theme
| default.nix
| nix-styles.nix
```

nix-styles.nix:
```
{ ... }:
{
  nix-styles = {
    enable = true;

    activeTheme = builtins.readFile ./active-theme; #contains either "light" or "dark"

    lightTheme = "kanagawa-lotus";
    darkTheme = "kanagawa-wave";
  };
}
```

default.nix:
```
{
  imports = [
    ./nix-styles.nix

    ./themes/kanagawa-lotus.nix
    ./themes/kanagawa-wave.nix
  ];
}
```

themes/kanagawa-wave:
```
{ ... }:
{
  nix-styles.themes.kanagawa-wave = {
    theme.dark = true;

    colors = {
        fg = "#FFFFFF";
        bg = "#000000";
        ...
    };
  };
}
```

User calls upon a color from a config:
```
...

    background.color = config.nix-styles.colors.bg
...
```

Example theme switch script:
```
#!/usr/bin/env bash

THEME_FILE="$NIX_DOTFILES/nix-styles/active-theme"
CURRENT=$(cat "$THEME_FILE")

if [ "$CURRENT" == "dark" ]; then
    NEW="light"
else
    NEW="dark"
fi

echo "$NEW" > "$THEME_FILE"

notify-send "Theme Switched" "'$CURRENT' -> '$NEW'\nReady for rebuild."

rebuild-flake
```
