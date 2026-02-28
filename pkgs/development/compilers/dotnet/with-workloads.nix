# Compose a .NET SDK with workload packs pre-installed.
#
# Usage:
#   withWorkloads sdk ["wasm-tools"]
#
# This fetches the required NuGet packs for each workload and layers them
# on top of the SDK using buildEnv, then wraps the result.
sdk: workloadIds:

{
  stdenvNoCC,
  lib,
  buildEnv,
  makeWrapper,
  fetchurl,
  unzip,
  callPackage,
  systemToDotnetRid,
}:

let
  mkWrapper = callPackage ./wrapper.nix { };
  hostRid = systemToDotnetRid stdenvNoCC.hostPlatform.system;

  # Determine the SDK band from the SDK version.
  # SDK version like "9.0.114" -> band "9.0.100"
  sdkVersion =
    let
      v = sdk.version;
      parts = lib.splitVersion v;
      major = builtins.elemAt parts 0;
      minor = builtins.elemAt parts 1;
      patch = builtins.elemAt parts 2;
      # Band = major.minor.X00 where X is the first digit of patch
      bandPatch = builtins.substring 0 1 patch + "00";
    in
    "${major}.${minor}.${bandPatch}";

  # Load the workload data for this SDK band.
  # The data file is keyed by band and contains pack hashes + per-RID mappings.
  workloadData =
    let
      majorMinor = lib.concatStringsSep "." (lib.take 2 (lib.splitVersion sdk.version));
      dataFile = ./workloads/${majorMinor}.nix;
    in
    assert lib.assertMsg (builtins.pathExists dataFile)
      "No workload data for .NET ${majorMinor}. Only .NET 9.0 workloads are currently supported.";
    import dataFile;

  # Resolve the list of pack keys needed for the requested workloads on this RID.
  ridWorkloads =
    workloadData.workloadPackNames.${hostRid} or (throw "No workload data for RID ${hostRid}");

  resolvedPackKeys = lib.unique (
    lib.concatMap (
      wid:
      ridWorkloads.${wid}
        or (throw "Unknown workload '${wid}'. Available: ${builtins.concatStringsSep ", " (builtins.attrNames ridWorkloads)}")
    ) workloadIds
  );

  # Look up each pack's fetch info from the hash table.
  packInfos = map (key: workloadData.packHashes.${key}) resolvedPackKeys;

  # Fetch each pack as a nupkg and install it into the SDK directory layout.
  # Packs go into $out/share/dotnet/packs/<PackId>/<Version>/
  mkPack =
    {
      pname,
      version,
      hash,
    }:
    stdenvNoCC.mkDerivation {
      pname = "dotnet-workload-pack-${lib.toLower pname}";
      inherit version;

      src = fetchurl {
        name = "${lib.toLower pname}.${lib.toLower version}.nupkg";
        url = "https://www.nuget.org/api/v2/package/${pname}/${version}";
        inherit hash;
      };

      nativeBuildInputs = [ unzip ];

      sourceRoot = ".";

      unpackPhase = ''
        mkdir source
        unzip -nqd source "$src"
      '';

      installPhase = ''
        runHook preInstall

        local packDir="$out/share/dotnet/packs/${pname}/${version}"
        mkdir -p "$packDir"
        cp -r source/* "$packDir"/
        chmod -R +w "$packDir"

        # Remove signature files
        rm -rf "$packDir"/.signature.p7s

        # Mark native binaries as executable
        local dir
        for dir in "$packDir"/tools "$packDir"/runtimes/*/native; do
          [[ -d "$dir" ]] && chmod -R +x "$dir" || true
        done

        runHook postInstall
      '';

      dontFixup = true;
    };

  packDerivations = map mkPack packInfos;

  # Create the workload installation metadata so `dotnet workload list` works.
  workloadMetadata = stdenvNoCC.mkDerivation {
    pname = "dotnet-workload-metadata";
    version = sdk.version;

    dontUnpack = true;

    installPhase = ''
      runHook preInstall

      local metaDir="$out/share/dotnet/metadata/workloads/${sdkVersion}"
      mkdir -p "$metaDir/InstalledWorkloads"

      ${lib.concatMapStringsSep "\n" (wid: ''
        touch "$metaDir/InstalledWorkloads/${wid}"
      '') workloadIds}

      runHook postInstall
    '';

    dontFixup = true;
  };

in
assert lib.assertMsg (workloadIds != [ ]) "withWorkloads: must specify at least one workload ID";
assert lib.assertMsg (
  sdk ? unwrapped
) "withWorkloads: expected a wrapped SDK (with .unwrapped attribute)";
mkWrapper "sdk" (
  (buildEnv {
    name = "dotnet-sdk-with-workloads";
    paths = [
      sdk.unwrapped
      workloadMetadata
    ]
    ++ packDerivations;
    pathsToLink = map (x: "/share/dotnet/${x}") [
      "host"
      "metadata"
      "packs"
      "sdk"
      "sdk-manifests"
      "shared"
      "templates"
    ];
    ignoreCollisions = true;
    nativeBuildInputs = [ makeWrapper ];
    postBuild = ''
      mkdir -p "$out"/share/dotnet
      cp "${sdk.unwrapped}"/share/dotnet/dotnet "$out"/share/dotnet
      cp -R "${sdk.unwrapped}"/nix-support "$out"/ 2>/dev/null || true
      mkdir -p "$out"/bin
      ln -s "$out"/share/dotnet/dotnet "$out"/bin/dotnet

      # Resolve symlinks so the SDK is self-contained. Without this,
      # MSBuild targets resolve their paths through symlinks back to the
      # original SDK and can't find our workload packs.
      mv "$out"/share/dotnet{,~}
      cp -Lr "$out"/share/dotnet{~,}
      rm -r "$out"/share/dotnet~

      # Remove the userlocal sentinel — it tells the SDK to look in ~/.dotnet/
      # for workloads instead of DOTNET_ROOT. Since we pre-install workloads
      # into the store, we want the SDK to find them here.
      find "$out"/share/dotnet/metadata -name userlocal -delete 2>/dev/null || true
    '';

    passthru = {
      inherit (sdk)
        pname
        version
        icu
        packages
        targetPackages
        ;
      inherit (sdk.unwrapped) hasILCompiler;
      runtime = sdk.runtime or null;
      aspnetcore = sdk.aspnetcore or null;
      inherit workloadIds;
    };

    meta = sdk.meta // {
      description = "${
        sdk.meta.description or "dotnet"
      } (with workloads: ${builtins.concatStringsSep ", " workloadIds})";
    };
  }).overrideAttrs
    {
      propagatedSandboxProfile = toString (sdk.__propagatedSandboxProfile or [ ]);
    }
)
