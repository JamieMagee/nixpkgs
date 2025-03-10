{
  lib,
  stdenv,
  darwin,
  fetchFromGitHub,
  rustPlatform,
  versionCheckHook,
}:

rustPlatform.buildRustPackage rec {
  pname = "rustcat";
  version = "3.0.0";

  src = fetchFromGitHub {
    owner = "robiot";
    repo = "rustcat";
    tag = "v${version}";
    hash = "sha256-/6vNFh7n6WvYerrL8m9sgUKsO2KKj7/f8xc4rzHy9Io=";
  };

  useFetchCargoVendor = true;
  cargoHash = "sha256-76/JK9IKYD6mxMddUyTgKAw53GM4EUhC0NbKFKdg8CI=";

  buildInputs = lib.optional stdenv.hostPlatform.isDarwin [ darwin.apple_sdk.frameworks.Security ];

  nativeInstallCheckInputs = [ versionCheckHook ];

  doInstallCheck = true;

  versionCheckProgram = [ "${placeholder "out"}/bin/rcat" ];

  meta = with lib; {
    description = "Port listener and reverse shell";
    homepage = "https://github.com/robiot/rustcat";
    changelog = "https://github.com/robiot/rustcat/releases/tag/v${version}";
    license = licenses.mit;
    maintainers = with maintainers; [ fab ];
    mainProgram = "rcat";
  };
}
