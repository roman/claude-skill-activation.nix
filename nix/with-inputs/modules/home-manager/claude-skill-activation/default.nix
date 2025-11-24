flakeInputs:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  claudeCfg = config.programs.claude-code;
  cfg = config.programs.claude-code.plugins.skill-activation;
in
{
  options.programs.claude-code.plugins.skill-activation = {
    enable = lib.mkEnableOption "skill-activation plugin for Claude Code";

    package = lib.mkOption {
      type = lib.types.package;
      default = flakeInputs.self.packages.${pkgs.system}.claude-skill-activation;
      defaultText = lib.literalExpression "pkgs.claude-skill-activation";
      description = "The claude-skill-activation package to use.";
    };

    skillRulesPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path to skill-rules.json file";
    };
  };

  config = lib.mkIf (claudeCfg.enable && cfg.enable) {

    # Install the skill-activation skill from the package output
    home.file.".claude/skills/skill-activation" = {
      source = "${cfg.package}/share/claude/skills/skill-activation";
      recursive = true;
    };

    # Install the skill-activation hook
    programs.claude-code.settings.hooks = {
      UserPromptSubmit = [
        {
          type = "command";
          command =
            if cfg.skillRulesPath != null then
              "${cfg.package}/bin/claude-skill-activation ${cfg.skillRulesPath}"
            else
              "${cfg.package}/bin/claude-skill-activation";
        }
      ];
    };

    assertions = [
      {
        assertion = cfg.enable -> (cfg.package != null);
        message = "skill-activation package must be provided when enabled";
      }
    ];

  };

}
