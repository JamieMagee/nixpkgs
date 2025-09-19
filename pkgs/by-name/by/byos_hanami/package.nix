{
  lib,
  stdenv,
  bundlerEnv,
  ruby,
  fetchFromGitHub,
  defaultGemConfig,
  libpq,
  imagemagick,
  chromium,
  nodejs,
  makeWrapper,
}:

let
  pname = "byos_hanami";
  version = "unstable-2025-01-08";

  src = fetchFromGitHub {
    owner = "usetrmnl";
    repo = "byos_hanami";
    rev = "main";
    hash = "sha256-ROFPFzmoodV40YZs0hrAHDB7vZxJNy1tlpc+78BFXWM=";
  };

  rubyEnv = bundlerEnv {
    name = "${pname}-env";
    inherit ruby;
    gemfile = "${src}/Gemfile";
    lockfile = "${src}/Gemfile.lock";
    gemset = ./gemset.nix;
    gemConfig = defaultGemConfig;
  };
in
stdenv.mkDerivation {
  inherit pname version src;

  buildInputs = [
    rubyEnv
    makeWrapper
    nodejs
  ];
  nativeBuildInputs = [ ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/${pname}
    cp -r . $out/share/${pname}/

    # Create wrapper scripts
    makeWrapper ${rubyEnv}/bin/ruby $out/bin/${pname} \
      --set PATH "${
        lib.makeBinPath [
          libpq
          nodejs
          imagemagick
          chromium
        ]
      }" \
      --set BUNDLE_GEMFILE "$out/share/${pname}/Gemfile" \
      --chdir "$out/share/${pname}" \
      --add-flags "$out/share/${pname}/config.ru"

    makeWrapper ${rubyEnv}/bin/hanami $out/bin/hanami \
      --set PATH "${
        lib.makeBinPath [
          libpq
          nodejs
          imagemagick
          chromium
        ]
      }" \
      --chdir "$out/share/${pname}"

    runHook postInstall
  '';

  meta = {
    description = "A TRMNL BYOS (Bring Your Own Server) application built with Hanami";
    homepage = "https://github.com/usetrmnl/byos_hanami";
    license = lib.licenses.mit;
    maintainers = [ ];
    platforms = lib.platforms.unix;
    mainProgram = pname;
  };
}
