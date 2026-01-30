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

## Testing Skill Activation

The test script (`test-skill-activation.sh`) is **not included** in the Nix package. To test skill activation manually, you need to invoke the hook binary directly from the Nix store.

### Finding Your Hook Binary Path

Check your `~/.claude/settings.json` for the hook command:

```bash
jq '.hooks.UserPromptSubmit[0].hooks[0].command' ~/.claude/settings.json
```

This will show something like:
```
"/nix/store/xxx-claude-skill-activation-0.0.1/bin/claude-skill-activation ~/.claude/skill-rules.json"
```

### Manual Testing

**Important:** The hook reads from stdin using file redirection (`<`), not piping (`|`).

```bash
# Create a test input file
echo '{"session_id":"test","prompt":"your test prompt here"}' > /tmp/test-input.json

# Run the hook with file redirection (NOT piping)
/nix/store/xxx-claude-skill-activation-0.0.1/bin/claude-skill-activation ~/.claude/skill-rules.json < /tmp/test-input.json
```

**Why file redirection?** The hook uses Node.js `readFileSync(0, 'utf-8')` to read stdin synchronously, which works with file redirection but may fail with piped input in some shell contexts.

### Example Test Session

```bash
# 1. Find your hook path
HOOK_PATH=$(jq -r '.hooks.UserPromptSubmit[0].hooks[0].command' ~/.claude/settings.json | awk '{print $1}')
RULES_PATH=$(jq -r '.hooks.UserPromptSubmit[0].hooks[0].command' ~/.claude/settings.json | awk '{print $2}')

# 2. Expand tilde in rules path
RULES_PATH="${RULES_PATH/#\~/$HOME}"

# 3. Create test input
echo '{"session_id":"test","prompt":"create beads tasks"}' > /tmp/test.json

# 4. Run test
$HOOK_PATH $RULES_PATH < /tmp/test.json
```

Expected output when a skill matches:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎯 SKILL ACTIVATION CHECK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📚 RECOMMENDED SKILLS:
  → beads

ACTION: Use Skill tool BEFORE responding
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

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
