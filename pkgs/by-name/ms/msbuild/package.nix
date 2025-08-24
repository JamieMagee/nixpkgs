{
  lib,
  buildDotnetModule,
  fetchFromGitHub,
  dotnetCorePackages,
  stdenv,
}:

buildDotnetModule rec {
  pname = "msbuild";
  version = "17.14.8";

  src = fetchFromGitHub {
    owner = "dotnet";
    repo = "msbuild";
    rev = "v${version}";
    hash = "sha256-hi79m8FEXv8agRgg/gCe9AiNcu/jRy2sk74r9cvO1JY=";
  };

  nugetDeps = ./deps.json;

  dotnet-sdk = dotnetCorePackages.sdk_9_0;
  dotnet-runtime = dotnetCorePackages.runtime_9_0;

  projectFile = [
    "src/Framework/Microsoft.Build.Framework.csproj"
    "src/Build/Microsoft.Build.csproj"
    "src/Utilities/Microsoft.Build.Utilities.csproj"
    "src/Tasks/Microsoft.Build.Tasks.csproj"
  ];
  buildType = "Release";

  dotnetBuildFlags = [
    "-p:DotNetBuildOffline=true"
    "-p:DotNetBuildSourceOnly=true"
    "-p:DisableImplicitNuGetFallbackFolder=true"
    "-p:RepositoryCommit=unknown"
    "-p:EnableApiCheck=false"
    "-p:RunApiCompat=false"
    "-p:IsPackable=false"
    "-p:TargetFramework=net9.0"
    "-p:UseAppHost=false"
    "-p:PublishSingleFile=false"
    "-p:SelfContained=false"
    "-maxcpucount:1"
  ];

  dotnetInstallFlags = [
    "-p:TargetFramework=net9.0"
  ];

  postPatch = ''
    # Fix executable permissions for shell scripts
    chmod +x eng/cibuild_bootstrapped_msbuild.sh
    chmod +x eng/common/*.sh

    # Substitute shell paths
    substituteInPlace eng/cibuild_bootstrapped_msbuild.sh \
      --replace '/bin/bash' '${stdenv.shell}'

    find eng/ -name "*.sh" -exec sed -i 's|#!/bin/bash|#!${stdenv.shell}|g' {} \;

    # Remove problematic AddRefAssemblies target that requires netstandard.library package
    sed -i '/<Target Name="AddRefAssemblies"/,/<\/Target>/d' src/MSBuild/MSBuild.csproj

    # Remove PackageDownload for netstandard.library since we're not using AddRefAssemblies
    sed -i '/<PackageDownload Include="netstandard.library">/,/<\/PackageDownload>/d' src/MSBuild/MSBuild.csproj

    # Remove GetCustomPackageFiles target that tries to use AddRefAssemblies output
    sed -i '/<Target Name="GetCustomPackageFiles"/,/<\/Target>/d' src/MSBuild/MSBuild.csproj
  '';

  postInstall = ''
    # Build MSBuild CLI separately to avoid apphost conflicts
    pushd src/MSBuild

    # First restore packages for MSBuild project - specify linux runtime to avoid Windows packages
    dotnet restore MSBuild.csproj \
      --packages ../../../nuget_pkgs \
      --force-evaluate \
      --no-cache \
      -r linux-x64

    dotnet build -c Release --no-restore -f net9.0 \
      -p:DotNetBuildOffline=true \
      -p:UseAppHost=false \
      -p:PublishSingleFile=false \
      -p:SelfContained=false \
      -r linux-x64

    # Copy MSBuild.dll and dependencies from artifacts directory
    mkdir -p $out/lib/msbuild
    if [ -f "../../artifacts/bin/MSBuild/Release/linux-x64/net9.0/MSBuild.dll" ]; then
      cp -r ../../artifacts/bin/MSBuild/Release/linux-x64/net9.0/* $out/lib/msbuild/
    elif [ -f "../../artifacts/bin/MSBuild/Release/net9.0/MSBuild.dll" ]; then
      cp -r ../../artifacts/bin/MSBuild/Release/net9.0/* $out/lib/msbuild/
    else
      echo "Could not find MSBuild.dll in artifacts directory"
      find ../../artifacts -name "MSBuild.dll" -type f
      exit 1
    fi

    # Create MSBuild wrapper script
    mkdir -p $out/bin
    cat > $out/bin/MSBuild << EOF
#!/bin/bash
exec "${dotnet-runtime}/bin/dotnet" "$out/lib/msbuild/MSBuild.dll" "\$@"
EOF
    chmod +x $out/bin/MSBuild

    # Create lowercase wrapper for consistency with other build tools
    ln -s $out/bin/MSBuild $out/bin/msbuild

    popd
  '';

  # Disable tests as they require specific Microsoft testing infrastructure
  doCheck = false;

  meta = with lib; {
    description = "Microsoft Build Engine (MSBuild) - the build platform for .NET and Visual Studio";
    mainProgram = "msbuild";
    homepage = "https://github.com/dotnet/msbuild";
    changelog = "https://github.com/dotnet/msbuild/releases/tag/v${version}";
    sourceProvenance = with sourceTypes; [
      fromSource
    ];
    license = licenses.mit;
    maintainers = with maintainers; [ jdanek ];
    platforms = platforms.linux ++ platforms.darwin;
  };
}
