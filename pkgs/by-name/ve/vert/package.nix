{
  stdenv,
  lib,
  fetchFromGitHub,
  fetchurl,
  bun,
  nodejs,
  nix-update-script,
}:
let
  pin = lib.importJSON ./pin.json;
  inherit (pin) version;

  pname = "vert";

  src = fetchFromGitHub {
    owner = "VERT-sh";
    repo = "VERT";
    rev = pin.rev;
    hash = pin.srcHash;
  };

  # Paraglide/inlang plugins fetched from CDN at build time — pre-downloaded for sandbox builds
  inlang-plugin-message-format = fetchurl {
    url = "https://cdn.jsdelivr.net/npm/@inlang/plugin-message-format@4/dist/index.js";
    hash = "sha256-lIZViAHAjrsBgiPFHCBEtsPCP8KowOeJSleIKzT+tso=";
  };
  inlang-plugin-m-function-matcher = fetchurl {
    url = "https://cdn.jsdelivr.net/npm/@inlang/plugin-m-function-matcher@2/dist/index.js";
    hash = "sha256-hYYvYwV5O1a/2a/lNosJbmP7Kuqzi3eZwFFRe+NJnAs=";
  };

  node_modules = stdenv.mkDerivation {
    pname = "${pname}-node_modules";
    inherit version src;

    dontConfigure = true;

    impureEnvVars = lib.fetchers.proxyImpureEnvVars ++ [
      "GIT_PROXY_COMMAND"
      "SOCKS_SERVER"
    ];

    nativeBuildInputs = [
      bun
    ];

    buildPhase = ''
      runHook preBuild

      bun install --frozen-lockfile --no-progress

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/node_modules
      rm -rf ./node_modules/.cache
      cp -R ./node_modules $out/lib
      cp package.json $out/lib

      runHook postInstall
    '';

    outputHash = pin."${stdenv.system}";
    outputHashMode = "recursive";
  };
in
stdenv.mkDerivation {
  inherit pname version src;

  nativeBuildInputs = [
    bun
    nodejs
  ];

  dontConfigure = true;

  postPatch = ''
    # Replace CDN plugin URLs with pre-fetched local copies for sandbox builds
    mkdir -p .inlang-plugins
    cp ${inlang-plugin-message-format} .inlang-plugins/plugin-message-format.js
    cp ${inlang-plugin-m-function-matcher} .inlang-plugins/plugin-m-function-matcher.js
    substituteInPlace project.inlang/settings.json \
      --replace-fail "https://cdn.jsdelivr.net/npm/@inlang/plugin-message-format@4/dist/index.js" \
        "./.inlang-plugins/plugin-message-format.js" \
      --replace-fail "https://cdn.jsdelivr.net/npm/@inlang/plugin-m-function-matcher@2/dist/index.js" \
        "./.inlang-plugins/plugin-m-function-matcher.js"
  '';

  buildPhase = ''
    runHook preBuild

    cp -R ${node_modules}/lib/node_modules ./node_modules
    chmod -R u+rw node_modules
    patchShebangs node_modules

    export PATH="$PWD/node_modules/.bin:$PATH"

    export SOURCE_COMMIT="${pin.rev}"
    export PUB_ENV=production
    export PUB_HOSTNAME=
    export PUB_PLAUSIBLE_URL=
    export PUB_VERTD_URL=
    export PUB_DISABLE_ALL_EXTERNAL_REQUESTS=true
    export PUB_DISABLE_FAILURE_BLOCKS=false
    export PUB_DONATION_URL=
    export PUB_STRIPE_KEY=

    bun run build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/vert
    cp -R ./build/* $out/share/vert

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--version"
      "branch=main"
    ];
  };

  meta = {
    description = "Privacy-focused file converter using WebAssembly";
    homepage = "https://vert.sh";
    license = lib.licenses.agpl3Only;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [
      jamieMagee
    ];
  };
}
