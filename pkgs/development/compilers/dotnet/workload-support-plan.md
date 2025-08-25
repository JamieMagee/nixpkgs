# Plan for .NET Workload Support in NixOS

## Background

.NET workloads (e.g., Android, MAUI, wasm-tools) are optional components that extend the .NET SDK. On NixOS, installing workloads via `dotnet workload install` fails because the SDK is installed in the read-only Nix store. There are partial workarounds, but a robust, declarative, and reproducible solution is needed.

## Current State

- **Workload install fails**: Attempts to install workloads write to the Nix store, causing errors.
- **Partial workarounds**: Some users manually create marker files or use specific SDK packages, but these are fragile and break with SDK changes.
- **Recent improvements**: PR #396181 improved support for workloads in combined SDKs by linking `metadata` directories.
- **Missing workloads**: Some workloads are not available in source-built SDKs.

## Goals

- Enable declarative, reproducible .NET workload support in NixOS and nixpkgs.
- Support both system-wide and per-project workload configuration.
- Ensure compatibility with multiple SDK versions and combined SDKs.

## Implementation Plan

### Phase 1: Foundation Infrastructure ✅ COMPLETED

**Status**: Both steps completed successfully

1. ✅ **Standardize userlocal marker files**
   - Ensure all SDK packages (binary and source-built) include `metadata/workloads/<feature-band>/userlocal`.
   - **Implementation**: Modified `build-dotnet.nix` to create userlocal files during SDK installation
   - **Result**: All SDK types now have proper userlocal marker files

2. ✅ **Create workload package infrastructure**
   - Define `buildWorkload` function for creating workload packages.
   - Define workload manifest parsing and dependency resolution logic.
   - **Implementation**: Created `build-workload.nix` with complete workload building system
   - **Result**: `dotnetCorePackages.buildWorkload`, `fetchWorkloadPack`, and `mkWorkloadManifest` available

### Phase 2: Implement Actual Workloads (2-3 weeks) - ✅ STEP 1 COMPLETED

**Step 1**: ✅ COMPLETED - WASM tools workload

- ✅ Research actual NuGet package names and versions for WASM workload
- ✅ Found Microsoft.NET.Runtime.WebAssembly.Sdk and Microsoft.NETCore.App.Runtime.Mono.browser-wasm packages
- ✅ Implement actual fetchWorkloadPack calls with real NuGet hashes
- ✅ Updated wasm-tools.nix with actual NuGet packages and correct hashes
- ✅ Fixed buildWorkload installation script to properly handle fetchWorkloadPack derivations
- ✅ **Fixed fetchNuGet issue**: Switched to fetchNupkg and implemented proper pack structure
- ✅ **Resolved pack directory structure**: Fixed naming from PackageName-Version to PackageName/Version
- ✅ **Working WASM workload**: Complete wasm-tools workload builds and contains proper .NET targets and tools

**Step 2**: 🔄 NEXT - Implement Android workload

- 📋 Research Android workload NuGet package names and versions
- 📋 Create android.nix workload definition with proper manifest and packs
- 📋 Test Android workload functionality with sample projects

**Step 3**: 📋 TODO - Implement additional workloads

- 📋 MAUI workload (depends on Android workload)
- 📋 iOS workload (if supported)
- 📋 Other platform-specific workloads

## Phase 3: User Experience

1. **Declarative workload configuration**
   - Enable specifying workloads in configuration.nix.
   - Create helper functions for common workload combinations.

2. **Development environment integration**
   - Integration with development shells and environments.
   - Documentation and examples for common use cases.

## Phase 4: Advanced Features

1. **Auto-discovery and dependency management**
   - Implement workload dependency resolution.
   - Auto-detection of required workloads from project files.

2. **Comprehensive workload coverage**
   - Support for all available .NET workloads.
   - Regular updates and maintenance automation.

## Implementation Details

```text

### Phase 4: Advanced Features & Completeness

7. **Auto-discovery and dependency management**
   - Implement workload dependency resolution.
   - Add tools for discovering required workloads from project files.
   - Support workload version constraints.

8. **Comprehensive workload coverage**
   - Package all available workloads for supported .NET versions.
   - Ensure compatibility between workload combinations.
   - Add tests to verify workload functionality.

## File Structure Changes

```

pkgs/development/compilers/dotnet/
├── build-workload.nix          # New: Build function for workloads
├── workloads/                  # New: Directory for workload definitions
│   ├── android.nix
│   ├── maui.nix
│   ├── wasm-tools.nix
│   └── ...
├── workload-manifests/         # New: Workload manifest definitions
└── with-workloads.nix          # New: Helper for combining SDKs with workloads

```

## Key Functions to Implement

- `buildWorkload` — Build workload packages from NuGet
- `withWorkloads` — Helper for adding workloads to SDKs
- `fetchWorkloadManifest` — Fetch and parse workload manifests
- `resolveWorkloadDependencies` — Resolve workload dependencies

## NixOS Module Example

```nix
# Example configuration
services.dotnet = {
  enable = true;
  sdks = [ "8.0" "9.0" ];
  workloads = [
    "android"
    "maui-android"
    "wasm-tools"
  ];
};
```

## Backward Compatibility

- Maintain existing workarounds during transition
- Ensure `combinePackages` continues to work
- Support both imperative (`dotnet workload install`) and declarative approaches
- Provide migration path from existing solutions

## Benefits

- **Reproducible builds**: Workloads defined declaratively in Nix
- **No network access required**: All dependencies fetched at build time
- **Version pinning**: Explicit control over workload versions
- **Composition**: Easy to combine workloads and SDKs
- **NixOS integration**: System-wide workload management
- **Development environment support**: Per-project workload configuration

---

This plan builds on the current infrastructure and aims for robust, declarative .NET workload support in NixOS and nixpkgs.
