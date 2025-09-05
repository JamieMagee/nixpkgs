{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "material-you-theme";
  version = "5.0.1";

  src = fetchFromGitHub {
    owner = "Nerwyn";
    repo = "material-you-theme";
    tag = version;
    hash = "sha256-xJXhvKwp/l08/ZWi3OcGPmCdsUiMjBDwrKz5OIpD2t8=";
  };

  npmDepsHash = "sha256-g133Je2Md4nKLZucSeM6TVEdaCsR2Ja1Aj2kf7JQk6w=";

  npmBuildScript = "build";

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r themes/* $out/
    cp -r css $out/ 2>/dev/null || true
    cp hacs.json $out/ 2>/dev/null || true

    runHook postInstall
  '';

  # This package produces theme YAML files, not a JavaScript module
  # The package is placed in custom-lovelace-modules for convenience
  # but it's actually a Home Assistant theme
  passthru.entrypoint = "material_you.yaml";

  meta = {
    description = "A Material You and Google Home app influenced theme for Home Assistant";
    homepage = "https://github.com/Nerwyn/material-you-theme";
    changelog = "https://github.com/Nerwyn/material-you-theme/releases/tag/v${version}";
    license = lib.licenses.asl20;
    maintainers = [ lib.maintainers.jamiemagee ];
  };
}
