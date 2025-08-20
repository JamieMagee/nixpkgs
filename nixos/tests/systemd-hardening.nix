{ ... }:

{
  name = "systemd-hardening";

  meta.maintainers = [ ];

  nodes = {
    # Test basic hardening functionality with simple settings
    basic = {
      systemd.services.test-basic = {
        hardening = {
          enable = true;
          settings = {
            PrivateTmp = true;
            NoNewPrivileges = true;
            ProtectKernelTunables = true;
          };
        };
        serviceConfig = {
          ExecStart = "/bin/sh -c 'echo hello'";
          Type = "oneshot";
        };
      };
    };

    # Test using predefined presets from the module
    predefined-presets =
      { hardeningPresets, ... }:
      {
        systemd.services.test-predefined = {
          hardening = {
            enable = true;
            presets = [
              hardeningPresets.isolation
              hardeningPresets.processIsolation
            ];
          };
          serviceConfig = {
            ExecStart = "/bin/sh -c 'echo hello'";
            Type = "oneshot";
          };
        };
      };

    # Test settings override presets
    override-test =
      { hardeningPresets, ... }:
      {
        systemd.services.test-override = {
          hardening = {
            enable = true;
            presets = [
              hardeningPresets.isolation
              hardeningPresets.processIsolation
            ];
            settings = {
              ProtectHome = false; # Override preset value
            };
          };
          serviceConfig = {
            ExecStart = "/bin/sh -c 'echo hello'";
            Type = "oneshot";
          };
        };
      };

    # Test functional presets
    functional-presets =
      { hardeningPresets, ... }:
      {
        systemd.services.test-functional = {
          hardening = {
            enable = true;
            presets = [
              hardeningPresets.isolation
              (hardeningPresets.allowNetwork {
                addressFamilies = [
                  "AF_UNIX"
                  "AF_INET"
                ];
                bindService = true;
              })
              (hardeningPresets.allowPaths {
                readWrite = [ "/tmp" ];
                readOnly = [ "/etc" ];
              })
            ];
          };
          serviceConfig = {
            ExecStart = "/bin/sh -c 'echo hello'";
            Type = "oneshot";
          };
        };
      };

    # Test service without hardening (control group)
    no-hardening = {
      systemd.services.test-no-hardening = {
        serviceConfig = {
          ExecStart = "/bin/sh -c 'echo hello'";
          Type = "oneshot";
        };
      };
    };
  };

  testScript = ''
    # Test basic hardening functionality
    with subtest("Basic hardening settings are applied"):
      basic.start()

      service_config = basic.succeed("systemctl cat test-basic.service")
      print("Basic service configuration:")
      print(service_config)

      # Verify basic hardening settings
      assert "PrivateTmp=true" in service_config
      assert "NoNewPrivileges=true" in service_config
      assert "ProtectKernelTunables=true" in service_config

    # Test predefined presets
    with subtest("Predefined presets work correctly"):
      predefined_presets.start()

      service_config = predefined_presets.succeed("systemctl cat test-predefined.service")
      print("Predefined presets service configuration:")
      print(service_config)

      # Verify settings from isolation preset
      assert "PrivateTmp=true" in service_config
      assert "ProtectKernelTunables=true" in service_config
      assert "ProtectKernelModules=true" in service_config
      assert "ProtectControlGroups=true" in service_config
      assert "NoNewPrivileges=true" in service_config
      assert "RestrictSUIDSGID=true" in service_config
      assert "RestrictRealtime=true" in service_config
      assert "SystemCallArchitectures=native" in service_config

      # Verify settings from processIsolation preset
      assert "PrivateUsers=true" in service_config
      assert "PrivateDevices=true" in service_config
      assert "ProtectProc=invisible" in service_config
      assert "ProcSubset=pid" in service_config
      assert "LockPersonality=true" in service_config
      assert "RemoveIPC=true" in service_config

    # Test settings override presets
    with subtest("Settings override preset values"):
      override_test.start()

      service_config = override_test.succeed("systemctl cat test-override.service")
      print("Override test service configuration:")
      print(service_config)

      # Verify preset values
      assert "PrivateTmp=true" in service_config  # From preset
      assert "NoNewPrivileges=true" in service_config  # From settings
      # ProtectHome should be false (overridden in settings)
      assert "ProtectHome=false" in service_config

    # Test functional presets
    with subtest("Functional presets work correctly"):
      functional_presets.start()

      service_config = functional_presets.succeed("systemctl cat test-functional.service")
      print("Functional presets service configuration:")
      print(service_config)

      # Verify settings from isolation preset
      assert "PrivateTmp=true" in service_config
      assert "NoNewPrivileges=true" in service_config
      assert "ProtectKernelTunables=true" in service_config
      assert "ProtectKernelModules=true" in service_config
      assert "ProtectControlGroups=true" in service_config
      assert "RestrictRealtime=true" in service_config
      assert "RestrictSUIDSGID=true" in service_config
      assert "SystemCallArchitectures=native" in service_config

      # Verify settings from allowNetwork functional preset
      assert "PrivateNetwork=false" in service_config  # allowNetwork disables PrivateNetwork
      assert "RestrictAddressFamilies=AF_UNIX" in service_config
      assert "RestrictAddressFamilies=AF_INET" in service_config
      assert "CapabilityBoundingSet=CAP_NET_BIND_SERVICE" in service_config  # bindService = true

      # Verify settings from allowPaths functional preset
      assert "ReadWritePaths=/tmp" in service_config
      assert "BindReadOnlyPaths=/etc" in service_config
      assert "ExecPaths=/nix/store" in service_config  # Default exec path

    # Test service without hardening
    with subtest("Services without hardening are not affected"):
      no_hardening.start()

      service_config = no_hardening.succeed("systemctl cat test-no-hardening.service")
      print("No hardening service configuration:")
      print(service_config)

      # Hardening options should not be present
      hardening_options = [
        "NoNewPrivileges=true",
        "PrivateTmp=true",
        "ProtectKernelTunables=true"
      ]

      for option in hardening_options:
        assert option not in service_config, f"Hardening option {option} should not be present"

    # Test that services can still start and run successfully
    with subtest("Hardened services can start and run"):
      basic.succeed("systemctl start test-basic.service")
      basic.succeed("test $(systemctl show -p ActiveState test-basic.service --value) != failed")

      predefined_presets.succeed("systemctl start test-predefined.service")
      predefined_presets.succeed("test $(systemctl show -p ActiveState test-predefined.service --value) != failed"

      override_test.succeed("systemctl start test-override.service")
      override_test.succeed("test $(systemctl show -p ActiveState test-override.service --value) != failed")

      functional_presets.succeed("systemctl start test-functional.service")
      functional_presets.succeed("test $(systemctl show -p ActiveState test-functional.service --value) != failed")

      no_hardening.succeed("systemctl start test-no-hardening.service")
      no_hardening.succeed("test $(systemctl show -p ActiveState test-no-hardening.service --value) != failed")
  '';
}
