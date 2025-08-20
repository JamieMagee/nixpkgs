{ ... }:

{
  name = "systemd-hardening";

  meta.maintainers = [ ];

  nodes = {
    # Test strict hardening profile
    strict = {
      systemd.services.test-strict = {
        harden = {
          enable = true;
          profile = "strict";
        };
        serviceConfig = {
          ExecStart = "/bin/sh -c 'echo hello'";
          Type = "oneshot";
        };
      };
    };

    # Test moderate hardening profile (default)
    moderate = {
      systemd.services.test-moderate = {
        harden.enable = true;
        serviceConfig = {
          ExecStart = "/bin/sh -c 'echo hello'";
          Type = "oneshot";
        };
      };
    };

    # Test minimal hardening profile
    minimal = {
      systemd.services.test-minimal = {
        harden = {
          enable = true;
          profile = "minimal";
        };
        serviceConfig = {
          ExecStart = "/bin/sh -c 'echo hello'";
          Type = "oneshot";
        };
      };
    };

    # Test network service with allowNetwork
    network-service = {
      systemd.services.test-network = {
        harden = {
          enable = true;
          profile = "strict";
          allowNetwork = true;
          capabilities = [ "CAP_NET_BIND_SERVICE" ];
        };
        serviceConfig = {
          ExecStart = "/bin/sh -c 'echo hello'";
          Type = "oneshot";
        };
      };
    };

    # Test service with custom paths and capabilities
    custom-config = {
      # Pre-create the directory that the service will use
      systemd.tmpfiles.rules = [
        "d /var/lib/test 0755 root root -"
      ];

      systemd.services.test-custom = {
        harden = {
          enable = true;
          profile = "moderate";
          allowHome = true;
          allowDevices = [ "/dev/null" ];
          readWritePaths = [ "/var/lib/test" ];
          additionalSyscalls = [ "@network-io" ];
          addressFamilies = [ "AF_NETLINK" ];
        };
        serviceConfig = {
          ExecStart = "/bin/sh -c 'echo hello > /var/lib/test/output'";
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
    # Test strict hardening profile
    with subtest("Strict hardening applies maximum security options"):
      strict.start()

      service_config = strict.succeed("systemctl cat test-strict.service")
      print("Strict service configuration:")
      print(service_config)

      # Verify strict profile options
      assert "PrivateUsers=true" in service_config
      assert "PrivateDevices=true" in service_config
      assert "PrivateTmp=true" in service_config
      assert "PrivateNetwork=true" in service_config
      assert "ProtectHome=true" in service_config
      assert "ProtectProc=invisible" in service_config
      assert "ProcSubset=pid" in service_config
      assert "ProtectSystem=strict" in service_config
      assert "ProtectKernelTunables=true" in service_config
      assert "ProtectKernelModules=true" in service_config
      assert "ProtectKernelLogs=true" in service_config
      assert "ProtectControlGroups=true" in service_config
      assert "ProtectClock=true" in service_config
      assert "ProtectHostname=true" in service_config
      assert "NoNewPrivileges=true" in service_config
      assert "CapabilityBoundingSet=" in service_config
      assert "LockPersonality=true" in service_config
      assert "RemoveIPC=true" in service_config
      assert "RestrictSUIDSGID=true" in service_config
      assert "SystemCallFilter=@system-service" in service_config
      assert "SystemCallFilter=~@privileged" in service_config
      assert "SystemCallArchitectures=native" in service_config
      assert "SystemCallErrorNumber=EPERM" in service_config
      assert "RestrictAddressFamilies=AF_UNIX" in service_config
      assert "IPAddressDeny=any" in service_config
      assert "NoExecPaths=/" in service_config
      assert "ExecPaths=/nix/store" in service_config
      assert "MemoryDenyWriteExecute=true" in service_config
      assert "RestrictNamespaces=true" in service_config
      assert "RestrictRealtime=true" in service_config
      assert "UMask=0077" in service_config

    # Test moderate hardening profile (default)
    with subtest("Moderate hardening applies balanced security options"):
      moderate.start()

      service_config = moderate.succeed("systemctl cat test-moderate.service")
      print("Moderate service configuration:")
      print(service_config)

      # Verify moderate profile options
      assert "PrivateDevices=true" in service_config
      assert "PrivateTmp=true" in service_config
      assert "ProtectHome=true" in service_config
      assert "ProtectProc=invisible" in service_config
      assert "ProtectSystem=full" in service_config
      assert "ProtectKernelTunables=true" in service_config
      assert "ProtectKernelModules=true" in service_config
      assert "ProtectKernelLogs=true" in service_config
      assert "ProtectControlGroups=true" in service_config
      assert "ProtectClock=true" in service_config
      assert "NoNewPrivileges=true" in service_config
      assert "LockPersonality=true" in service_config
      assert "RestrictSUIDSGID=true" in service_config
      assert "SystemCallFilter=@system-service" in service_config
      assert "SystemCallArchitectures=native" in service_config
      assert "RestrictAddressFamilies=AF_UNIX" in service_config
      assert "RestrictAddressFamilies=AF_INET" in service_config
      assert "RestrictAddressFamilies=AF_INET6" in service_config
      assert "RestrictNamespaces=true" in service_config
      assert "RestrictRealtime=true" in service_config
      assert "UMask=0027" in service_config

      # Should not have strict-only options
      assert "PrivateNetwork=true" not in service_config
      assert "PrivateUsers=true" not in service_config
      assert "ProtectSystem=strict" not in service_config

    # Test minimal hardening profile
    with subtest("Minimal hardening applies basic security options"):
      minimal.start()

      service_config = minimal.succeed("systemctl cat test-minimal.service")
      print("Minimal service configuration:")
      print(service_config)

      # Verify minimal profile options
      assert "PrivateTmp=true" in service_config
      assert "ProtectKernelTunables=true" in service_config
      assert "ProtectKernelModules=true" in service_config
      assert "ProtectControlGroups=true" in service_config
      assert "NoNewPrivileges=true" in service_config
      assert "RestrictSUIDSGID=true" in service_config
      assert "RestrictRealtime=true" in service_config
      assert "SystemCallArchitectures=native" in service_config

      # Should not have more restrictive options
      assert "PrivateDevices=true" not in service_config
      assert "PrivateNetwork=true" not in service_config
      assert "ProtectHome=true" not in service_config

    # Test network service configuration
    with subtest("Network service with allowNetwork works correctly"):
      network_service.start()

      service_config = network_service.succeed("systemctl cat test-network.service")
      print("Network service configuration:")
      print(service_config)

      # Should have strict base but network overrides
      assert "PrivateNetwork=false" in service_config
      assert "RestrictAddressFamilies=AF_UNIX" in service_config
      assert "RestrictAddressFamilies=AF_INET" in service_config
      assert "RestrictAddressFamilies=AF_INET6" in service_config
      assert "CapabilityBoundingSet=CAP_NET_BIND_SERVICE" in service_config
      # Should not have network restrictions
      assert "IPAddressDeny=any" not in service_config

    # Test custom configuration
    with subtest("Custom hardening options work correctly"):
      custom_config.start()

      service_config = custom_config.succeed("systemctl cat test-custom.service")
      print("Custom service configuration:")
      print(service_config)

      # Verify custom overrides
      assert "ProtectHome=false" in service_config
      assert "PrivateDevices=false" in service_config
      assert "DeviceAllow=/dev/null" in service_config
      assert "ReadWritePaths=/var/lib/test" in service_config
      assert "SystemCallFilter=@system-service" in service_config
      assert "SystemCallFilter=@network-io" in service_config

    # Test service without hardening
    with subtest("Services without hardening are not affected"):
      no_hardening.start()

      service_config = no_hardening.succeed("systemctl cat test-no-hardening.service")
      print("No hardening service configuration:")
      print(service_config)

      # Hardening options should not be present
      hardening_options = [
        "NoNewPrivileges=true",
        "PrivateDevices=true",
        "PrivateTmp=true",
        "ProtectHome=true",
        "RestrictNamespaces=true"
      ]

      for option in hardening_options:
        assert option not in service_config, f"Hardening option {option} should not be present"

    # Test that services can still start and run successfully
    with subtest("Hardened services can start and run"):
      strict.succeed("systemctl start test-strict.service")
      strict.succeed("test $(systemctl show -p ActiveState test-strict.service --value) != failed")

      moderate.succeed("systemctl start test-moderate.service")
      moderate.succeed("test $(systemctl show -p ActiveState test-moderate.service --value) != failed")

      minimal.succeed("systemctl start test-minimal.service")
      minimal.succeed("test $(systemctl show -p ActiveState test-minimal.service --value) != failed")

      network_service.succeed("systemctl start test-network.service")
      network_service.succeed("test $(systemctl show -p ActiveState test-network.service --value) != failed")

      custom_config.succeed("systemctl start test-custom.service")
      custom_config.succeed("test $(systemctl show -p ActiveState test-custom.service --value) != failed")

      no_hardening.succeed("systemctl start test-no-hardening.service")
      no_hardening.succeed("test $(systemctl show -p ActiveState test-no-hardening.service --value) != failed")
  '';
}
