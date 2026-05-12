{ lib, config, ... }:
let
  inherit (lib) mkIf mkOption types;
  cfg = config.nix-styles;

  defaultActiveThemeMode = "dark";
  validThemeModes = [ "light" "dark" ];

  hexRegex = "^#?([0-9A-Fa-f]{6}|[0-9A-Fa-f]{3})$";
  rgbRegex = "^rgb[ \\t]*\\([ \\t]*([0-9]{1,3})[ \\t]*,[ \\t]*([0-9]{1,3})[ \\t]*,[ \\t]*([0-9]{1,3})[ \\t]*\\)$";
  hslRegex = "^hsl[ \\t]*\\([ \\t]*([0-9]{1,3})[ \\t]*,[ \\t]*([0-9]{1,3})%[ \\t]*,[ \\t]*([0-9]{1,3})%[ \\t]*\\)$";

  stringToCharList = value:
    builtins.genList
      (index: builtins.substring index 1 value)
      (builtins.stringLength value);

  clamp = minValue: maxValue: value:
    if value < minValue then minValue else if value > maxValue then maxValue else value;

  roundInt = value: builtins.floor (value + 0.5);

  min = a: b: if a < b then a else b;
  max = a: b: if a > b then a else b;

  hexDigitValues = {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
    "a" = 10;
    "b" = 11;
    "c" = 12;
    "d" = 13;
    "e" = 14;
    "f" = 15;
    "A" = 10;
    "B" = 11;
    "C" = 12;
    "D" = 13;
    "E" = 14;
    "F" = 15;
  };

  decimalDigitValues = {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
  };

  decimalToInt = value:
    lib.lists.foldl'
      (acc: ch:
        acc * 10 + (decimalDigitValues.${ch} or (throw "nix-styles: invalid decimal digit '${ch}' in '${value}'.")))
      0
      (stringToCharList value);

  hexToInt = value:
    lib.lists.foldl'
      (acc: ch:
        acc * 16 + (hexDigitValues.${ch} or (throw "nix-styles: invalid hex digit '${ch}' in '${value}'.")))
      0
      (stringToCharList value);

  hexDigitsUpper = [
    "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "A" "B" "C" "D" "E" "F"
  ];

  intToHex2 = value:
    let
      normalized = clamp 0 255 value;
      high = builtins.floor (normalized / 16);
      low = normalized - high * 16;
    in
      "${builtins.elemAt hexDigitsUpper high}${builtins.elemAt hexDigitsUpper low}";

  rgbToHexInner = rgb:
    "${intToHex2 rgb.r}${intToHex2 rgb.g}${intToHex2 rgb.b}";

  rgbToHsl = rgb:
    let
      r = rgb.r / 255.0;
      g = rgb.g / 255.0;
      b = rgb.b / 255.0;
      maxValue = max (max r g) b;
      minValue = min (min r g) b;
      delta = maxValue - minValue;
      lightness = (maxValue + minValue) / 2.0;
      saturation =
        if delta == 0 then
          0.0
        else if lightness > 0.5 then
          delta / (2.0 - maxValue - minValue)
        else
          delta / (maxValue + minValue);
      huePrime =
        if delta == 0 then
          0.0
        else if maxValue == r then
          (g - b) / delta + (if g < b then 6.0 else 0.0)
        else if maxValue == g then
          (b - r) / delta + 2.0
        else
          (r - g) / delta + 4.0;
      hue = huePrime / 6.0;
      hueDeg = roundInt (hue * 360.0);
      satPct = roundInt (saturation * 100.0);
      lightPct = roundInt (lightness * 100.0);
    in
      {
        h = if hueDeg == 360 then 0 else hueDeg;
        s = satPct;
        l = lightPct;
      };

  hslToRgb = hsl:
    let
      hue = (if hsl.h == 360 then 0 else hsl.h) / 360.0;
      saturation = hsl.s / 100.0;
      lightness = hsl.l / 100.0;
      hueToRgb = p: q: t:
        let
          tAdjusted =
            if t < 0.0 then t + 1.0 else if t > 1.0 then t - 1.0 else t;
        in
          if tAdjusted < (1.0 / 6.0) then
            p + (q - p) * 6.0 * tAdjusted
          else if tAdjusted < 0.5 then
            q
          else if tAdjusted < (2.0 / 3.0) then
            p + (q - p) * (2.0 / 3.0 - tAdjusted) * 6.0
          else
            p;
      q =
        if lightness < 0.5 then
          lightness * (1.0 + saturation)
        else
          lightness + saturation - lightness * saturation;
      p = 2.0 * lightness - q;
      red =
        if saturation == 0.0 then
          lightness
        else
          hueToRgb p q (hue + (1.0 / 3.0));
      green =
        if saturation == 0.0 then
          lightness
        else
          hueToRgb p q hue;
      blue =
        if saturation == 0.0 then
          lightness
        else
          hueToRgb p q (hue - (1.0 / 3.0));
    in
      {
        r = clamp 0 255 (roundInt (red * 255.0));
        g = clamp 0 255 (roundInt (green * 255.0));
        b = clamp 0 255 (roundInt (blue * 255.0));
      };

  parseColor = raw:
    let
      hexMatch = builtins.match hexRegex raw;
      rgbMatch = builtins.match rgbRegex raw;
      hslMatch = builtins.match hslRegex raw;
    in
      if hexMatch != null then
        let
          rawHex = builtins.elemAt hexMatch 0;
          expandedHex =
            if builtins.stringLength rawHex == 3 then
              builtins.concatStringsSep "" (map (ch: ch + ch) (stringToCharList rawHex))
            else
              rawHex;
          hexInner = lib.strings.toUpper expandedHex;
          rgb = {
            r = hexToInt (builtins.substring 0 2 hexInner);
            g = hexToInt (builtins.substring 2 2 hexInner);
            b = hexToInt (builtins.substring 4 2 hexInner);
          };
          hsl = rgbToHsl rgb;
        in
          {
            valid = true;
            kind = "hex";
            hexInner = hexInner;
            rgb = rgb;
            hsl = hsl;
          }
      else if rgbMatch != null then
        let
          rValue = decimalToInt (builtins.elemAt rgbMatch 0);
          gValue = decimalToInt (builtins.elemAt rgbMatch 1);
          bValue = decimalToInt (builtins.elemAt rgbMatch 2);
          rgb = { r = rValue; g = gValue; b = bValue; };
        in
          if rValue > 255 || gValue > 255 || bValue > 255 then
            {
              valid = false;
              reason = "RGB values must be between 0 and 255.";
            }
          else
            let
              hsl = rgbToHsl rgb;
            in
              {
                valid = true;
                kind = "rgb";
                hexInner = rgbToHexInner rgb;
                rgb = rgb;
                hsl = hsl;
              }
      else if hslMatch != null then
        let
          hValue = decimalToInt (builtins.elemAt hslMatch 0);
          sValue = decimalToInt (builtins.elemAt hslMatch 1);
          lValue = decimalToInt (builtins.elemAt hslMatch 2);
          hsl = { h = hValue; s = sValue; l = lValue; };
        in
          if hValue > 360 || sValue > 100 || lValue > 100 then
            {
              valid = false;
              reason = "HSL values must be h: 0-360, s/l: 0-100.";
            }
          else
            let
              rgb = hslToRgb hsl;
            in
              {
                valid = true;
                kind = "hsl";
                hexInner = rgbToHexInner rgb;
                rgb = rgb;
                hsl = hsl;
              }
      else
        {
          valid = false;
          reason = "Unsupported color format (expected hex, rgb(), or hsl()).";
        };

  mkFormat = formattedValue: innerValue:
    rec {
      value = formattedValue;
      inner = innerValue;
      __toString = _: formattedValue;
    };

  # Build a color accessor set:
  # - value: raw string
  # - hex/rgb/hsl: { value, inner, __toString }
  # - __toString: raw string for string coercion
  mkColor = name: raw:
    let
      parsed = parseColor raw;
      fallback = rec {
        value = raw;
        hex = mkFormat raw raw;
        rgb = mkFormat raw raw;
        hsl = mkFormat raw raw;
        __toString = _: value;
      };
    in
      if parsed.valid then
        let
          rgbInner = "${toString parsed.rgb.r},${toString parsed.rgb.g},${toString parsed.rgb.b}";
          hslInner = "${toString parsed.hsl.h},${toString parsed.hsl.s}%,${toString parsed.hsl.l}%";
          hexValue = "#${parsed.hexInner}";
          rgbValue = "rgb(${rgbInner})";
          hslValue = "hsl(${hslInner})";
        in
          rec {
            value = raw;
            hex = mkFormat hexValue parsed.hexInner;
            rgb = mkFormat rgbValue rgbInner;
            hsl = mkFormat hslValue hslInner;
            __toString = _: value;
          }
      else if cfg.strictColors then
        throw "nix-styles: invalid color '${raw}' for '${name}'. ${parsed.reason}"
      else
        lib.warn
          "nix-styles: invalid color '${raw}' for '${name}' (${parsed.reason}); leaving unconverted."
          fallback;

  mkColors = colors:
    lib.attrsets.mapAttrs mkColor colors;

  themeModule = { name, ... }:
    {
      options = {
        name = mkOption {
          type = types.str;
          readOnly = true;
          default = name;
          description = "Theme name derived from the attribute key.";
        };

        theme = mkOption {
          type = types.submodule {
            options = {
              dark = mkOption {
                type = types.bool;
                description = "Whether this theme is a dark theme.";
              };
            };
            freeformType = types.attrs;
          };
          default = { };
          description = "Theme metadata.";
        };

        colors = mkOption {
          type = types.attrsOf types.str;
          default = { };
          description = "Theme color definitions.";
        };
      };
      freeformType = types.attrs;
    };

  activeThemeIsValid = builtins.elem cfg.activeTheme validThemeModes;
  resolvedThemeMode = if activeThemeIsValid then cfg.activeTheme else defaultActiveThemeMode;
  activeThemeName = if resolvedThemeMode == "light" then cfg.lightTheme else cfg.darkTheme;
  selectedTheme =
    lib.attrsets.attrByPath
      [ activeThemeName ]
      { colors = { }; theme = { dark = false; }; }
      cfg.themes;

  extraThemeWarnings =
    lib.concatLists (lib.attrsets.mapAttrsToList
      (themeName: themeConfig:
        let
          extraTop =
            builtins.attrNames
              (lib.attrsets.removeAttrs themeConfig [ "name" "theme" "colors" "_module" ]);
          extraTheme =
            builtins.attrNames
              (lib.attrsets.removeAttrs (themeConfig.theme or { }) [ "dark" "_module" ]);
        in
          (map
            (field: "nix-styles.themes.${themeName}.${field} is not supported and will be ignored.")
            extraTop)
          ++
          (map
            (field: "nix-styles.themes.${themeName}.theme.${field} is not supported and will be ignored.")
            extraTheme))
      cfg.themes);
in
{
  options.nix-styles = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable nix-styles output values.";
    };

    activeTheme = mkOption {
      type = types.str;
      default = defaultActiveThemeMode;
      apply = lib.strings.trim;
      description = "Active theme mode: \"light\" or \"dark\".";
    };

    lightTheme = mkOption {
      type = types.str;
      default = "";
      description = "Theme name used when activeTheme is \"light\".";
    };

    darkTheme = mkOption {
      type = types.str;
      default = "";
      description = "Theme name used when activeTheme is \"dark\".";
    };

    strictColors = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to error on invalid color values.";
    };

    themes = mkOption {
      type = types.attrsOf (types.submodule themeModule);
      default = { };
      description = "Theme definitions.";
    };

    colors = mkOption {
      type = types.attrs;
      default = { };
      readOnly = true;
      description = "Resolved colors for the active theme.";
    };

    theme = mkOption {
      type = types.submodule {
        options = {
          dark = mkOption {
            type = types.bool;
            default = false;
            readOnly = true;
            description = "Whether the active theme is dark.";
          };
        };
      };
      default = { };
      readOnly = true;
      description = "Resolved theme metadata.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.lightTheme != "" && builtins.hasAttr cfg.lightTheme cfg.themes;
        message = "nix-styles.lightTheme must reference an existing theme (got '${cfg.lightTheme}').";
      }
      {
        assertion = cfg.darkTheme != "" && builtins.hasAttr cfg.darkTheme cfg.themes;
        message = "nix-styles.darkTheme must reference an existing theme (got '${cfg.darkTheme}').";
      }
    ];

    warnings =
      (lib.optional (!activeThemeIsValid)
        "nix-styles.activeTheme must be \"light\" or \"dark\"; falling back to \"${defaultActiveThemeMode}\".")
      ++ extraThemeWarnings;

    nix-styles = {
      colors = mkColors selectedTheme.colors;
      theme.dark = selectedTheme.theme.dark;
    };
  };
}
