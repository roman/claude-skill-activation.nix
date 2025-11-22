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
      default = flakeInputs.self.packages.${pkgs.system}.skill-activation;
      defaultText = lib.literalExpression "pkgs.skill-activation";
      description = "The skill-activation package to use.";
    };

    skillRulesPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path to skill-rules.json file";
    };
  };

  config = lib.mkIf (claudeCfg.enable && cfg.enable) {

    # Install the skill-activation skill.
    home.file.".claude/skills/skill-activation" = {
      source = "${flakeInputs.self}/skill";
      recursive = true;
    };

    # Install the skill-activation hook.
    programs.claude-code.settings.hooks = {
      UserPromptSubmit = [
        {
          type = "command";
          command =
            if cfg.skillRulesPath != null then
              "${cfg.package}/bin/skill-activation ${cfg.skillRulesPath}"
            else
              "${cfg.package}/bin/skill-activation";
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
