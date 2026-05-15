{ lib, config, pkgs, options, ... }:
let
  inherit (lib) mkIf mkOption types;
  cfg = config.nix-styles;

  hexRegex = "^#?([0-9A-Fa-f]{6}|[0-9A-Fa-f]{3})$";
  rgbRegex = "^rgb[ \\t]*\\([ \\t]*([0-9]{1,3})[ \\t]*,[ \\t]*([0-9]{1,3})[ \\t]*,[ \\t]*([0-9]{1,3})[ \\t]*\\)$";
  hslRegex = "^hsl[ \\t]*\\([ \\t]*([0-9]{1,3})[ \\t]*,[ \\t]*([0-9]{1,3})%[ \\t]*,[ \\t]*([0-9]{1,3})%[ \\t]*\\)$";
  defaultTheme = { colors = { }; };

  stringToCharList = value:
    builtins.genList
      (index: builtins.substring index 1 value)
      (builtins.stringLength value);

  clamp = minValue: maxValue: value:
    if value < minValue then minValue else if value > maxValue then maxValue else value;

  roundInt = value: builtins.floor (value + 0.5);

  min = a: b: if a < b then a else b;
  max = a: b: if a > b then a else b;
  normalizeHue = hue:
    let
      scaled = hue - (builtins.floor (hue / 360.0) * 360);
    in
      if scaled < 0 then builtins.floor (scaled + 360) else builtins.floor scaled;

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
        h = normalizeHue hueDeg;
        s = satPct;
        l = lightPct;
      };

  hslToRgb = hsl:
    let
      hue = (normalizeHue hsl.h) / 360.0;
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
          if rValue < 0 || gValue < 0 || bValue < 0 || rValue > 255 || gValue > 255 || bValue > 255 then
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
          if hValue < 0 || sValue < 0 || lValue < 0 || hValue > 360 || sValue > 100 || lValue > 100 then
            {
              valid = false;
              reason = "HSL values must be h: 0-360 (360 treated as 0), s/l: 0-100.";
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

  # Build a format value with:
  # - value: formatted string (e.g. "rgb(1,2,3)")
  # - inner: numeric payload (e.g. "1,2,3")
  mkFormat = formattedValue: innerValue:
    rec {
      value = formattedValue;
      inner = innerValue;
      __toString = _: value;
    };

  # Build normalized color data:
  # - raw: raw declared string
  # - hex/rgb/hsl: { value, inner }
  mkColor = name: raw:
    let
      parsed = parseColor raw;
      fallback = {
        raw = raw;
        hex = mkFormat raw raw;
        rgb = mkFormat raw raw;
        hsl = mkFormat raw raw;
        __toString = _: raw;
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
          {
            raw = raw;
            hex = mkFormat hexValue parsed.hexInner;
            rgb = mkFormat rgbValue rgbInner;
            hsl = mkFormat hslValue hslInner;
            __toString = _: raw;
          }
      else if cfg.strictColors then
        throw "nix-styles: invalid color '${raw}' for '${name}'. ${parsed.reason}"
      else
        lib.warn
          "nix-styles: invalid color '${raw}' for '${name}' (${parsed.reason}); leaving unconverted."
          fallback;

  mkColors = colors:
    let
      normalized = lib.attrsets.mapAttrs mkColor colors;
      # Extract one field from each normalized color into an attrset keyed by color name.
      project = selector: lib.attrsets.mapAttrs (_: color: selector color) normalized;
    in
      {
        raw = project (color: color.raw);
        hex = project (color: color.hex.value);
        rgb = project (color: color.rgb.value);
        hsl = project (color: color.hsl.value);
        inner = {
          hex = project (color: color.hex.inner);
          rgb = project (color: color.rgb.inner);
          hsl = project (color: color.hsl.inner);
        };
      };

  themeModule = { name, ... }:
    {
      options = {
        name = mkOption {
          type = types.str;
          readOnly = true;
          default = name;
          description = "Theme name derived from the attribute key.";
        };

        colors = mkOption {
          type = types.attrsOf types.str;
          default = { };
          description = "Theme color definitions.";
        };
      };
      freeformType = types.attrs;
    };

  activeThemeName = if cfg.isDark then cfg.darkTheme else cfg.lightTheme;
  selectedTheme =
    lib.attrsets.attrByPath
      [ activeThemeName ]
      defaultTheme
      cfg.themes;

  extraThemeWarnings =
    lib.concatLists (lib.attrsets.mapAttrsToList
      (themeName: themeConfig:
        let
          extraTop =
            builtins.attrNames
              (lib.attrsets.removeAttrs themeConfig [ "name" "theme" "colors" "_module" ]);
        in
          (map
            (field: "nix-styles.themes.${themeName}.${field} is not supported and will be ignored.")
            extraTop))
      cfg.themes);

  # --- write helpers ---

  mkFormatFileContent = format:
    lib.concatStringsSep "\n"
      (lib.mapAttrsToList
        (key: value: ''${key}: "${value}"'')
        cfg.colors.${format})
    + "\n";

  themesFileContent =
    ''active: "${cfg.activeTheme}"'' + "\n" +
    ''light: "${cfg.lightTheme}"'' + "\n" +
    ''dark: "${cfg.darkTheme}"'' + "\n";

  writeStoreFiles =
    lib.genAttrs cfg.write.formats
      (format: pkgs.writeText format (mkFormatFileContent format));

  themesStoreFile = pkgs.writeText "themes" themesFileContent;

  mkSymlinkScript =
    let
      formatLines =
        lib.concatMapStringsSep "\n"
          (format:
            "ln -sf '${writeStoreFiles.${format}}' '${cfg.write.directory}/${format}'")
          cfg.write.formats;
      themesLine =
        lib.optionalString cfg.write.themes
          "ln -sf '${themesStoreFile}' '${cfg.write.directory}/themes'";
    in
      ''
        mkdir -p '${cfg.write.directory}'
        ${formatLines}
        ${themesLine}
      '';
in
{
  options.nix-styles = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable nix-styles output values.";
    };

    isDark = mkOption {
      type = types.bool;
      default = true;
      description = "Whether the active theme is dark.";
    };

    lightTheme = mkOption {
      type = types.str;
      default = "";
      description = "Theme name used when isDark is false.";
    };

    darkTheme = mkOption {
      type = types.str;
      default = "";
      description = "Theme name used when isDark is true.";
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

# --- read only ---

    activeTheme = mkOption {
      type = types.str;
      default = activeThemeName;
      readOnly = true;
      description = "Name of the active theme.";
    };

    colors = mkOption {
      type = types.attrs;
      default = mkColors selectedTheme.colors;
      readOnly = true;
      description = "Resolved colors for the active theme, grouped by format.";
    };

    write = mkOption {
      description = "Options for writing color theme files to disk.";
      default = { };
      type = types.submodule {
        options = {
          enabled = mkOption {
            type = types.bool;
            default = false;
            description = "Whether to write color theme files.";
          };

          formats = mkOption {
            type = types.listOf (types.enum [ "hex" "rgb" "hsl" ]);
            default = [ "hex" "rgb" "hsl" ];
            description = "Formats to write. Valid values: \"hex\", \"rgb\", \"hsl\".";
          };

          directory = mkOption {
            type = types.str;
            default = "";
            description = "Directory to symlink the generated files into.";
          };

          themes = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to write a file containing the active, light, and dark theme names.";
          };
        };
      };
    };

  };

  config = lib.mkIf (cfg.enable && cfg.write.enabled) (
    let
      warnIfNoDir =
        lib.warnIf (cfg.write.directory == "")
          "nix-styles: write.enabled is true but write.directory is empty; no files will be symlinked.";
      isHomeManager = builtins.hasAttr "home" options;
      activationEntry =
        if isHomeManager then
          {
            home.activation.nix-styles-write =
              lib.hm.dag.entryAfter [ "writeBoundary" ] mkSymlinkScript;
          }
        else
          {
            system.activationScripts.nix-styles-write.text = mkSymlinkScript;
          };
    in
      warnIfNoDir (
        lib.mkIf (cfg.write.directory != "") activationEntry
      )
  );
}
