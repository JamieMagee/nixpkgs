{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.vert;
in
{
  options.services.vert = {
    enable = lib.mkEnableOption "VERT, a privacy-focused file converter using WebAssembly";

    package = lib.mkPackageOption pkgs "vert" { };

    virtualHost = {
      enableNginx = lib.mkEnableOption "a virtualhost to serve VERT through nginx";

      domain = lib.mkOption {
        description = ''
          Domain to use for the virtual host.

          This can be used to change nginx options like
          ```nix
          services.nginx.virtualHosts."$\{config.services.vert.virtualHost.domain}".listen = [ ... ]
          ```
        '';
        type = lib.types.str;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.nginx = lib.mkIf cfg.virtualHost.enableNginx {
      enable = true;
      virtualHosts."${cfg.virtualHost.domain}" = {
        locations."/" = {
          root = "${cfg.package}/share/vert";
          tryFiles = "$uri /index.html";
        };
      };
    };
  };

  meta.maintainers = [
    lib.maintainers.jamieMagee
  ];
}
