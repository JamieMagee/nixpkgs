{
  lib,
  stdenv,
  fetchNupkg,
  callPackage,
}:

{
  # Build a workload package from manifest and pack definitions
  buildWorkload =
    {
      pname,
      version,
      manifestJson, # Content of WorkloadManifest.json
      packs ? [ ], # List of workload pack definitions
      platforms ? [ stdenv.hostPlatform.system ], # Supported platforms
      meta ? { },
    }:
    let
      # Convert platform names to .NET RID format
      nixToDotnetRid = {
        "x86_64-linux" = "linux-x64";
        "aarch64-linux" = "linux-arm64";
        "x86_64-darwin" = "osx-x64";
        "aarch64-darwin" = "osx-arm64";
        "x86_64-windows" = "win-x64";
        "aarch64-windows" = "win-arm64";
      };

      currentRid = nixToDotnetRid.${stdenv.hostPlatform.system} or stdenv.hostPlatform.system;

      # Filter packs for current platform
      platformPacks = lib.filter (pack: lib.elem currentRid (pack.platforms or [ currentRid ])) packs;
    in
    stdenv.mkDerivation {
      inherit pname version;

      dontUnpack = true;
      dontBuild = true;

      installPhase = ''
        runHook preInstall

        # Create manifest directory structure
        manifest_dir="$out/share/dotnet/sdk-manifests/$(echo "${version}" | sed -E 's/^([0-9]+\.[0-9]+)\.[0-9]+.*/\1.100/')/${pname}"
        mkdir -p "$manifest_dir/${version}"

        # Install manifest files
        echo '${builtins.toJSON manifestJson}' > "$manifest_dir/${version}/WorkloadManifest.json"

        # Create packs directory and install workload packs
        packs_dir="$out/share/dotnet/packs"
        mkdir -p "$packs_dir"

        ${lib.concatMapStringsSep "\n" (pack: ''
          # Install pack ${pack.name or pack.pname}
          pack_name="${pack.name or pack.pname}"
          pack_version="${pack.version}"
          
          # Extract actual package name without version suffix if present
          # fetchNupkg creates derivation names with -version suffix
          if [[ "$pack_name" == *"-$pack_version" ]]; then
            pack_name_clean="''${pack_name%-$pack_version}"
          else
            pack_name_clean="$pack_name"
          fi
          
          pack_dir="$packs_dir/$pack_name_clean/$pack_version"
          mkdir -p "$pack_dir"

          # Copy pack contents - pack is a fetchNupkg derivation
          # fetchNupkg creates packages in /share/nuget/packages/<lowercase-name>/<version>/ format
          pack_name_lower="$(echo "$pack_name_clean" | tr '[:upper:]' '[:lower:]')"
          source_dir="${pack}/share/nuget/packages/$pack_name_lower/$pack_version"
          
          if [[ -d "$source_dir" ]]; then
            cp -r "$source_dir"/* "$pack_dir/"
          else
            # Fallback: Try to find the correct directory name
            actual_dir=$(find "${pack}/share/nuget/packages/" -maxdepth 2 -name "$pack_version" -type d | head -1)
            if [[ -n "$actual_dir" && -d "$actual_dir" ]]; then
              cp -r "$actual_dir"/* "$pack_dir/"
            else
              echo "Error: Could not find package content for pack $pack_name_clean"
              exit 1
            fi
          fi
        '') platformPacks}

        runHook postInstall
      '';

      passthru = {
        inherit packs platforms;
        manifestJson = builtins.toJSON manifestJson;
      };

      meta = {
        description = manifestJson.workloads.${pname}.description or "Workload for ${pname}";
        platforms = platforms;
      }
      // meta;
    };

  # Fetch a workload pack from NuGet
  fetchWorkloadPack =
    {
      name,
      version,
      hash,
      platforms ? [ ],
      ...
    }@args:
    fetchNupkg (
      (builtins.removeAttrs args [ "name" "platforms" ])
      // {
        pname = name;
        inherit version hash;
      }
    );

  # Helper to create a workload manifest JSON structure
  mkWorkloadManifest =
    {
      version,
      workloadId,
      description,
      packs,
      platforms ? [
        "linux-x64"
        "osx-x64"
        "osx-arm64"
      ],
      extends ? [ ],
    }:
    {
      inherit version;
      workloads.${workloadId} = {
        inherit
          description
          packs
          platforms
          extends
          ;
      };
    };
}
