{
  lib,
  stdenv,
  buildDotnetModule,
  fetchFromGitHub,
  dotnetCorePackages,
  git,
}:
buildDotnetModule rec {
  pname = "sbom-tool";
  version = "1.5.2";

  src = fetchFromGitHub {
    owner = "microsoft";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-x8XJkrHvW89w6G1gp2/A/E0+sz+dwEnWaat0V8wt0DQ=";
  };

  dotnetFlags = [
    "-property:MinVerSkip=true"
    "-property:PackageVersion=${version}"
    "-property:AssemblyVersion=${version}.0"
    "-property:FileVersion=${version}.0"
  ];

  dotnet-runtime = dotnetCorePackages.runtime_6_0;

  nugetDeps = ./deps.nix;

  projectFile = "Microsoft.Sbom.sln";
  executables = ["Microsoft.Sbom.Tool"];

  doCheck = true;

  meta = with lib; {
    description = "A highly scalable and enterprise ready tool to create SPDX 2.2 compatible SBOMs for any variety of artifacts.";
    homepage = "https://github.com/microsoft/sbom-tool";
    license = licenses.mit;
    maintainers = [maintainers.jamiemagee];
  };
}
