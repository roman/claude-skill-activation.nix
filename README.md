# claude-skill-activation.nix

Auto-activate Claude Code skills based on context using hook-driven pattern matching.

## Installation

Add to your flake inputs:

```nix
{
  inputs.claude-skill-activation.url = "github:roman/claude-skill-activation.nix";
}
```

Enable in your home-manager configuration:

```nix
{
  programs.claude-code.plugins.skill-activation.enable = true;
}
```

## Configuration

### Basic Usage

The default configuration works out of the box. By default, it looks for skill rules in your project's `.claude/skills/skill-ruleset.json`.

### Custom Rules

To use a custom skill-rules.json file at a different location:

```nix
{
  programs.claude-code.plugins.skill-activation = {
    enable = true;
    skillRulesPath = "/path/to/your/skill-rules.json";
  };
}
```

See [skill/references/SKILL_RULES_REFERENCE.md](skill/references/SKILL_RULES_REFERENCE.md) for the complete schema.

## How It Works

- **UserPromptSubmit hook** analyzes prompts before Claude sees them
- Matches against keywords, intent patterns, file paths, and content
- Suggests relevant skills automatically
- Tracks session state to avoid repeated suggestions

## Options Reference

### `programs.claude-code.plugins.skill-activation.enable`

Enable the skill-activation plugin.

**Type**: `boolean`

**Default**: `false`

### `programs.claude-code.plugins.skill-activation.package`

The skill-activation package to use.

**Type**: `package`

**Default**: `pkgs.claude-skill-activation`

### `programs.claude-code.plugins.skill-activation.skillRulesPath`

Path to custom skill-rules.json file.

**Type**: `null or string`

**Default**: `null` (uses `.claude/skills/skill-ruleset.json` in the current project)

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

Heavily inspired by [claude-code-infrastructure-showcase](https://github.com/diet103/claude-code-infrastructure-showcase).
