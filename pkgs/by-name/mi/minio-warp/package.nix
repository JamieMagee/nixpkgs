{
  lib,
  fetchFromGitHub,
  buildGoModule,
  versionCheckHook,
  nix-update-script,
}:

buildGoModule rec {
  pname = "minio-warp";
  version = "1.1.2";

  src = fetchFromGitHub {
    owner = "minio";
    repo = "warp";
    rev = "v${version}";
    hash = "sha256-loyEGnJ6ExWMUyArNNpQGzpagFgwlNzaNBO8EPXkMws=";
  };

  vendorHash = "sha256-/+vKs5NzzyP9Ihz+zbxGf/OEHD0kaf0wZzE0Sg++3bE=";

  # See .goreleaser.yml
  ldflags = [
    "-s"
    "-w"
    "-X github.com/minio/warp/pkg.ReleaseTag=v${version}"
    "-X github.com/minio/warp/pkg.CommitID=${src.rev}"
    "-X github.com/minio/warp/pkg.Version=${version}"
    "-X github.com/minio/warp/pkg.ShortCommitID=${src.rev}"
    "-X github.com/minio/warp/pkg.ReleaseTime=1970-01-01T00:00:00Z"
  ];

  postInstall = ''
    mv $out/bin/warp $out/bin/minio-warp
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "S3 benchmarking tool";
    homepage = "https://github.com/minio/warp";
    license = lib.licenses.agpl3Plus;
    maintainers = with lib.maintainers; [ christoph-heiss ];
    mainProgram = "minio-warp";
  };
}
