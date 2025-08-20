{ lib, systemdUtils, ... }:
let
  inherit (lib) types;
  inherit (systemdUtils.lib) unitOption;

  # Hardening preset library
  hardeningPresets = {
    # Fundamental isolation preset - recommended for all services
    isolation = {
      PrivateTmp = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      NoNewPrivileges = true;
      RestrictSUIDSGID = true;
      RestrictRealtime = true;
      SystemCallArchitectures = "native";
    };

    # Process and user isolation
    processIsolation = {
      PrivateUsers = true;
      PrivateDevices = true;
      ProtectHome = true;
      ProtectProc = "invisible";
      ProcSubset = "pid";
      LockPersonality = true;
      RemoveIPC = true;
    };

    # Comprehensive filesystem protection
    filesystemProtection = {
      ProtectSystem = "strict";
      NoExecPaths = [ "/" ];
      ExecPaths = [ "/nix/store" ];
      UMask = "0077";
      MemoryDenyWriteExecute = true;
    };

    # Network isolation (default: no network access)
    networkIsolation = {
      PrivateNetwork = true;
      RestrictAddressFamilies = [ "AF_UNIX" ];
      IPAddressDeny = [ "any" ];
    };

    # System protection against kernel modifications
    systemProtection = {
      ProtectKernelLogs = true;
      ProtectClock = true;
      ProtectHostname = true;
      RestrictNamespaces = true;
    };

    # Strict system call filtering
    systemCallRestriction = {
      SystemCallFilter = [
        "@system-service"
        "~@privileged"
      ];
      SystemCallErrorNumber = "EPERM";
    };

    # Remove all capabilities by default
    noCapabilities = {
      CapabilityBoundingSet = [ "" ];
    };

    # Predefined combinations for ease of use
    strict = lib.mergeAttrsList [
      hardeningPresets.isolation
      hardeningPresets.processIsolation
      hardeningPresets.filesystemProtection
      hardeningPresets.networkIsolation
      hardeningPresets.systemProtection
      hardeningPresets.systemCallRestriction
      hardeningPresets.noCapabilities
    ];

    moderate = lib.mergeAttrsList [
      hardeningPresets.isolation
      hardeningPresets.processIsolation
      hardeningPresets.systemProtection
      {
        # More permissive filesystem access
        ProtectSystem = "full";
        UMask = "0027";
        # Allow basic networking by default
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
        # Basic system call filtering
        SystemCallFilter = [ "@system-service" ];
      }
    ];

    minimal = hardeningPresets.isolation;

    # Functional presets with simplified parameters
    allowNetwork =
      {
        addressFamilies ? [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ],
        bindService ? false,
      }:
      {
        PrivateNetwork = false;
        RestrictAddressFamilies = addressFamilies;
        IPAddressDeny = null;
      }
      // lib.optionalAttrs bindService {
        CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
      };

    allowDevices = devices: {
      PrivateDevices = false;
      DeviceAllow = devices;
    };

    allowPaths =
      {
        readWrite ? [ ],
        readOnly ? [ ],
        exec ? [ ],
      }:
      {
        ReadWritePaths = readWrite;
        BindReadOnlyPaths = readOnly;
        ExecPaths = [ "/nix/store" ] ++ exec;
      };

    allowCapabilities = capabilities: {
      CapabilityBoundingSet = capabilities;
    };

    allowSyscalls = syscalls: {
      SystemCallFilter = [ "@system-service" ] ++ syscalls;
    };
  };

in
{
  options = {
    systemd.services = lib.mkOption {
      type = types.attrsOf (
        types.submodule (
          {
            name,
            config,
            ...
          }:
          {
            options.hardening = {
              enable = lib.mkOption {
                type = types.bool;
                default = false;
                description = "Enable systemd service hardening";
              };

              presets = lib.mkOption {
                type = types.listOf types.attrs;
                default = [ ];
                description = "Hardening presets to apply (later ones override earlier ones)";
              };

              settings = lib.mkOption {
                type = types.attrsOf unitOption;
                default = { };
                description = "Systemd hardening settings (see systemd.exec(5))";
              };
            };

            config.serviceConfig =
              let
                hardeningCfg = config.hardening;

                # Merge all presets and custom settings
                finalSettings = lib.filterAttrs (n: v: v != null) (
                  lib.mergeAttrsList (hardeningCfg.presets ++ [ hardeningCfg.settings ])
                );
              in
              lib.optionalAttrs hardeningCfg.enable (
                lib.mapAttrs (name: value: lib.mkDefault value) finalSettings
              );
          }
        )
      );
    };
  };

  config = {
    _module.args.hardeningPresets = hardeningPresets;
  };
}
