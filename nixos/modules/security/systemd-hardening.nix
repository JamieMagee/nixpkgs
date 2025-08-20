{ lib, ... }:
let
  inherit (lib) types;

  # Common address family sets
  basicAddressFamilies = [
    "AF_UNIX"
    "AF_INET"
    "AF_INET6"
  ];

  # Hardening profile definitions
  hardeningProfiles = {
    strict = {
      # Process isolation
      PrivateUsers = true;
      PrivateDevices = true;
      PrivateTmp = true;
      PrivateNetwork = true;
      ProtectHome = true;
      ProtectProc = "invisible";
      ProcSubset = "pid";

      # System protection
      ProtectSystem = "strict";
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      ProtectClock = true;
      ProtectHostname = true;

      # Capabilities and privileges
      NoNewPrivileges = true;
      CapabilityBoundingSet = [ "" ];
      LockPersonality = true;
      RemoveIPC = true;
      RestrictSUIDSGID = true;

      # System calls
      SystemCallFilter = [
        "@system-service"
        "~@privileged"
      ];
      SystemCallArchitectures = "native";
      SystemCallErrorNumber = "EPERM";

      # Network restrictions
      RestrictAddressFamilies = [ "AF_UNIX" ];
      IPAddressDeny = [ "any" ];

      # Execution restrictions
      NoExecPaths = [ "/" ];
      ExecPaths = [ "/nix/store" ];
      MemoryDenyWriteExecute = true;

      # Namespace restrictions
      RestrictNamespaces = true;
      RestrictRealtime = true;

      # File system
      UMask = "0077";
    };

    moderate = {
      # Basic isolation
      PrivateDevices = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectProc = "invisible";

      # System protection
      ProtectSystem = "full";
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      ProtectClock = true;

      # Basic privilege restrictions
      NoNewPrivileges = true;
      LockPersonality = true;
      RestrictSUIDSGID = true;

      # System calls
      SystemCallFilter = [ "@system-service" ];
      SystemCallArchitectures = "native";

      # Network (less restrictive)
      RestrictAddressFamilies = basicAddressFamilies;

      # Namespace restrictions
      RestrictNamespaces = true;
      RestrictRealtime = true;

      # File permissions
      UMask = "0027";
    };

    minimal = {
      # Basic protections
      PrivateTmp = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;

      # Basic restrictions
      NoNewPrivileges = true;
      RestrictSUIDSGID = true;
      RestrictRealtime = true;

      # System calls
      SystemCallArchitectures = "native";
    };
  };

in
{
  options.systemd.services = lib.mkOption {
    type = types.attrsOf (
      types.submodule (
        {
          name,
          config,
          ...
        }:
        {
          options.harden = {
            enable = lib.mkOption {
              type = types.bool;
              default = false;
              description = ''
                Enable systemd service hardening.
              '';
            };

            profile = lib.mkOption {
              type = types.enum [
                "strict"
                "moderate"
                "minimal"
              ];
              default = "moderate";
              description = ''
                Hardening profile to apply. Profiles provide different levels of security vs compatibility:
                - strict: Maximum security with potential compatibility trade-offs
                - moderate: Balanced security and compatibility (recommended)
                - minimal: Light hardening with maximum compatibility
              '';
            };

            allowNetwork = lib.mkOption {
              type = types.bool;
              default = false;
              description = ''
                Allow network access by disabling PrivateNetwork and enabling appropriate address families.
              '';
            };

            allowHome = lib.mkOption {
              type = types.bool;
              default = false;
              description = ''
                Allow access to user home directories by disabling ProtectHome.
              '';
            };

            allowDevices = lib.mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = ''
                List of device paths to allow access to. Disables PrivateDevices and sets DeviceAllow.
              '';
            };

            capabilities = lib.mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = ''
                List of capabilities to grant to the service. Overrides the default empty capability bounding set.
              '';
            };

            execPaths = lib.mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = ''
                Additional paths where executables are allowed. Always includes /nix/store.
              '';
            };

            readWritePaths = lib.mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = ''
                Additional directories that should be writable by the service.
              '';
            };

            bindReadOnlyPaths = lib.mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = ''
                Additional paths to bind-mount as read-only into the service's mount namespace.
              '';
            };

            additionalSyscalls = lib.mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = ''
                Additional system call groups or individual syscalls to allow.
                These are added to the base profile's SystemCallFilter.
              '';
            };

            systemCallFilter = lib.mkOption {
              type = types.nullOr (types.listOf types.str);
              default = null;
              description = ''
                Complete override of SystemCallFilter. When set, replaces the profile's default filter entirely.
              '';
            };

            addressFamilies = lib.mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = ''
                Additional address families to allow when allowNetwork is true.
              '';
            };
          };

          config.serviceConfig =
            let
              hardenCfg = config.harden;
              inherit (lib) mkDefault mkForce optionalAttrs;
            in
            lib.optionalAttrs hardenCfg.enable (
              let
                baseProfile = hardeningProfiles.${hardenCfg.profile};

                # Handle SystemCallFilter logic
                systemCallFilter =
                  if hardenCfg.systemCallFilter != null then
                    hardenCfg.systemCallFilter
                  else if hardenCfg.additionalSyscalls != [ ] then
                    (baseProfile.SystemCallFilter or [ ]) ++ hardenCfg.additionalSyscalls
                  else
                    baseProfile.SystemCallFilter or null;

                # Apply conditional overrides based on harden options
                overrides = lib.mergeAttrsList [
                  (optionalAttrs hardenCfg.allowNetwork {
                    PrivateNetwork = mkForce false;
                    RestrictAddressFamilies = mkForce (basicAddressFamilies ++ hardenCfg.addressFamilies);
                    IPAddressDeny = mkForce null;
                  })
                  (optionalAttrs hardenCfg.allowHome {
                    ProtectHome = mkForce false;
                  })
                  (optionalAttrs (hardenCfg.allowDevices != [ ]) {
                    PrivateDevices = mkForce false;
                    DeviceAllow = hardenCfg.allowDevices;
                  })
                  (optionalAttrs (hardenCfg.capabilities != [ ]) {
                    CapabilityBoundingSet = mkForce hardenCfg.capabilities;
                  })
                  (optionalAttrs (hardenCfg.execPaths != [ ]) {
                    ExecPaths = mkForce ([ "/nix/store" ] ++ hardenCfg.execPaths);
                  })
                  (optionalAttrs (hardenCfg.readWritePaths != [ ]) {
                    ReadWritePaths = hardenCfg.readWritePaths;
                  })
                  (optionalAttrs (hardenCfg.bindReadOnlyPaths != [ ]) {
                    BindReadOnlyPaths = hardenCfg.bindReadOnlyPaths;
                  })
                  (optionalAttrs
                    (systemCallFilter != null && systemCallFilter != (baseProfile.SystemCallFilter or null))
                    {
                      SystemCallFilter = mkForce systemCallFilter;
                    }
                  )
                ];

              in
              lib.mapAttrs (name: value: mkDefault value) baseProfile // overrides
            );
        }
      )
    );
  };
}
