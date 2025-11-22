# Hooks

Claude Code hooks that enable skill auto-activation, file tracking, and validation.

---

## What Are Hooks?

Hooks are scripts that run at specific points in Claude's workflow:
- **UserPromptSubmit**: When user submits a prompt
- **PreToolUse**: Before a tool executes  
- **PostToolUse**: After a tool completes
- **Stop**: When user requests to stop

**Key insight:** Hooks can modify prompts, block actions, and track state - enabling features Claude can't do alone.

---

## Essential Hooks (Start Here)

### skill-activation-prompt (UserPromptSubmit)

**Purpose:** Automatically suggests relevant skills based on user prompts and file context

**How it works:**
1. Reads `skill-rules.json`
2. Matches user prompt against trigger patterns
3. Checks which files user is working with
4. Injects skill suggestions into Claude's context

**Why it's essential:** This is THE hook that makes skills auto-activate.

**Integration:**
```bash
# Copy both files
cp skill-activation-prompt.sh your-project/.claude/hooks/
cp skill-activation-prompt.ts your-project/.claude/hooks/

# Make executable
chmod +x your-project/.claude/hooks/skill-activation-prompt.sh

# Install dependencies
cd your-project/.claude/hooks
npm install
```

**Add to settings.json:**
```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/skill-activation-prompt.sh"
          }
        ]
      }
    ]
  }
}
```

**Customization:** ✅ None needed - reads skill-rules.json automatically
