{
  description = "Figma Agent";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: lib.genAttrs systems (system: f system);
    in {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in {
          default = pkgs.rustPlatform.buildRustPackage {
            pname = "figma-agent";
            version = "0.4.3";
            src = self;
            cargoLock = {
              lockFile = ./Cargo.lock;
            };
          };
        });

      nixosModules.default = { config, lib, pkgs, ... }:
        let
          cfg = config.services.figma-agent;
          configFile = pkgs.writeText "figma-agent-config.json" (builtins.toJSON {
            bind = cfg.bind;
            use_system_fonts = cfg.useSystemFonts;
            font_directories = cfg.fontDirectories;
            enable_font_rescan = cfg.enableFontRescan;
            enable_font_preview = cfg.enableFontPreview;
          });
        in {
          options.services.figma-agent = with lib; {
            enable = mkEnableOption "Figma Agent";
            package = mkOption {
              type = types.package;
              default = self.packages.${pkgs.system}.default;
              description = "Figma Agent package.";
            };
            bind = mkOption {
              type = types.str;
              default = "127.0.0.1:44950";
              description = "Bind address used when not socket-activated.";
            };
            useSystemFonts = mkOption {
              type = types.bool;
              default = true;
              description = "Whether to include system font directories.";
            };
            fontDirectories = mkOption {
              type = types.listOf types.str;
              default = [];
              description = "Additional font directories to scan.";
            };
            enableFontRescan = mkOption {
              type = types.bool;
              default = true;
              description = "Enable automatic font rescan per request.";
            };
            enableFontPreview = mkOption {
              type = types.bool;
              default = true;
              description = "Enable SVG font preview endpoint.";
            };
          };

          config = lib.mkIf cfg.enable {
            systemd.user.sockets.figma-agent = {
              wantedBy = [ "sockets.target" ];
              socketConfig = {
                ListenStream = cfg.bind;
              };
            };

            systemd.user.services.figma-agent = {
              description = "Figma Agent";
              requires = [ "figma-agent.socket" ];
              after = [ "figma-agent.socket" ];
              serviceConfig = {
                ExecStart = "${cfg.package}/bin/figma-agent";
                Restart = "on-failure";
                Environment = [ "FIGMA_AGENT_CONFIG=${configFile}" ];
              };
              wantedBy = [ "default.target" ];
            };
          };
        };

      darwinModules.default = { config, lib, pkgs, ... }:
        let
          cfg = config.services.figma-agent;
          configFile = pkgs.writeText "figma-agent-config.json" (builtins.toJSON {
            bind = cfg.bind;
            use_system_fonts = cfg.useSystemFonts;
            font_directories = cfg.fontDirectories;
            enable_font_rescan = cfg.enableFontRescan;
            enable_font_preview = cfg.enableFontPreview;
          });
        in {
          options.services.figma-agent = with lib; {
            enable = mkEnableOption "Figma Agent";
            package = mkOption {
              type = types.package;
              default = self.packages.${pkgs.system}.default;
              description = "Figma Agent package.";
            };
            bind = mkOption {
              type = types.str;
              default = "127.0.0.1:44950";
              description = "Bind address used by the agent.";
            };
            useSystemFonts = mkOption {
              type = types.bool;
              default = true;
              description = "Whether to include system font directories.";
            };
            fontDirectories = mkOption {
              type = types.listOf types.str;
              default = [];
              description = "Additional font directories to scan.";
            };
            enableFontRescan = mkOption {
              type = types.bool;
              default = true;
              description = "Enable automatic font rescan per request.";
            };
            enableFontPreview = mkOption {
              type = types.bool;
              default = true;
              description = "Enable SVG font preview endpoint.";
            };
          };

          config = lib.mkIf cfg.enable {
            launchd.user.agents.figma-agent = {
              serviceConfig = {
                ProgramArguments = [ "${cfg.package}/bin/figma-agent" ];
                EnvironmentVariables = {
                  FIGMA_AGENT_CONFIG = toString configFile;
                };
                KeepAlive = true;
                RunAtLoad = true;
              };
            };
          };
        };
    };
}
