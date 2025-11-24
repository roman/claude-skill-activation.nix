# Troubleshooting - Skill Activation Issues

Complete debugging guide for skill activation problems.

## Table of Contents

- [Skill Not Triggering](#skill-not-triggering)
  - [UserPromptSubmit Not Suggesting](#userpromptsubmit-not-suggesting)
  - [PreToolUse Not Blocking](#pretooluse-not-blocking)
- [False Positives](#false-positives)
- [Hook Not Executing](#hook-not-executing)
- [Performance Issues](#performance-issues)

---

## Skill Not Triggering

### UserPromptSubmit Not Suggesting

**Symptoms:** Ask a question, but no skill suggestion appears in output.

**Common Causes:**

####  1. Keywords Don't Match

**Check:**
- Look at `promptTriggers.keywords` in skill-rules.json
- Are the keywords actually in your prompt?
- Remember: case-insensitive substring matching

**Example:**
```json
"keywords": ["layout", "grid"]
```
- "how does the layout work?" → ✅ Matches "layout"
- "how does the grid system work?" → ✅ Matches "grid"
- "how do layouts work?" → ✅ Matches "layout"
- "how does it work?" → ❌ No match

**Fix:** Add more keyword variations to skill-rules.json

#### 2. Intent Patterns Too Specific

**Check:**
- Look at `promptTriggers.intentPatterns`
- Test regex at https://regex101.com/
- May need broader patterns

**Example:**
```json
"intentPatterns": [
  "(create|add).*?(database.*?table)"  // Too specific
]
```
- "create a database table" → ✅ Matches
- "add new table" → ❌ Doesn't match (missing "database")

**Fix:** Broaden the pattern:
```json
"intentPatterns": [
  "(create|add).*?(table|database)"  // Better
]
```

#### 3. Typo in Skill Name

**Check:**
- Skill name in SKILL.md frontmatter
- Skill name in skill-rules.json
- Must match exactly

**Example:**
```yaml
# SKILL.md
name: project-catalog-developer
```
```json
// skill-rules.json
"project-catalogue-developer": {  // ❌ Typo: catalogue vs catalog
  ...
}
```

**Fix:** Make names match exactly

#### 4. JSON Syntax Error

**Check:**
```bash
cat .claude/skills/skill-rules.json | jq .
```

If invalid JSON, jq will show the error.

**Common errors:**
- Trailing commas
- Missing quotes
- Single quotes instead of double
- Unescaped characters in strings

**Fix:** Correct JSON syntax, validate with jq

#### Debug Command

Test the hook manually:

```bash
echo '{"session_id":"debug","prompt":"your test prompt here"}' | \
  npx tsx .claude/hooks/skill-activation-prompt.ts
```

Expected: Your skill should appear in the output.

---

## False Positives

**Symptoms:** Skill triggers when it shouldn't.

**Common Causes & Solutions:**

### 1. Keywords Too Generic

**Problem:**
```json
"keywords": ["user", "system", "create"]  // Too broad
```
- Triggers on: "user manual", "file system", "create directory"

**Solution:** Make keywords more specific
```json
"keywords": [
  "user authentication",
  "user tracking",
  "create feature"
]
```

### 2. Intent Patterns Too Broad

**Problem:**
```json
"intentPatterns": [
  "(create)"  // Matches everything with "create"
]
```
- Triggers on: "create file", "create folder", "create account"

**Solution:** Add context to patterns
```json
"intentPatterns": [
  "(create|add).*?(database|table|feature)"  // More specific
]
```

**Advanced:** Use negative lookaheads to exclude
```regex
(create)(?!.*test).*?(feature)  // Don't match if "test" appears
```

### 3. File Paths Too Generic

**Problem:**
```json
"pathPatterns": [
  "form/**"  // Matches everything in form/
]
```
- Triggers on: test files, config files, everything

**Solution:** Use narrower patterns
```json
"pathPatterns": [
  "form/src/services/**/*.ts",  // Only service files
  "form/src/controllers/**/*.ts"
]
```

### 4. Content Patterns Catching Unrelated Code

**Problem:**
```json
"contentPatterns": [
  "Prisma"  // Matches in comments, strings, etc.
]
```
- Triggers on: `// Don't use Prisma here`
- Triggers on: `const note = "Prisma is cool"`

**Solution:** Make patterns more specific
```json
"contentPatterns": [
  "import.*[Pp]risma",        // Only imports
  "PrismaService\\.",         // Only actual usage
  "prisma\\.(findMany|create)" // Specific methods
]
```

### 5. Adjust Enforcement Level

**Last resort:** If false positives are frequent:

```json
{
  "enforcement": "block"  // Change to "suggest"
}
```

This makes it advisory instead of blocking.

---

## Hook Not Executing

**Symptoms:** Hook doesn't run at all - no suggestion, no block.

**Common Causes:**

### 1. Hook Not Registered

**Check `.claude/settings.json`:**
```bash
cat .claude/settings.json | jq '.hooks.UserPromptSubmit'
cat .claude/settings.json | jq '.hooks.PreToolUse'
```

Expected: Hook entries present

**Fix:** Add missing hook registration:
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

---

## Performance Issues

**Symptoms:** Hooks are slow, noticeable delay before prompt/edit.

**Common Causes:**

### 1. Too Many Patterns

**Check:**
- Count patterns in skill-rules.json
- Each pattern = regex compilation + matching

**Solution:** Reduce patterns
- Combine similar patterns
- Remove redundant patterns
- Use more specific patterns (faster matching)

### 2. Complex Regex

**Problem:**
```regex
(create|add|modify|update|implement|build).*?(feature|endpoint|route|service|controller|component|UI|page)
```
- Long alternations = slow

**Solution:** Simplify
```regex
(create|add).*?(feature|endpoint)  // Fewer alternatives
```

### 3. Too Many Files Checked

**Problem:**
```json
"pathPatterns": [
  "**/*.ts"  // Checks ALL TypeScript files
]
```

**Solution:** Be more specific
```json
"pathPatterns": [
  "form/src/services/**/*.ts",  // Only specific directory
  "form/src/controllers/**/*.ts"
]
```

### 4. Large Files

Content pattern matching reads entire file - slow for large files.

**Solution:**
- Only use content patterns when necessary
- Consider file size limits (future enhancement)

### Measure Performance

```bash
# UserPromptSubmit
time echo '{"prompt":"test"}' | claude-skill-activation
```

**Target metrics:**
- UserPromptSubmit: < 100ms

---

**Related Files:**
- [SKILL.md](SKILL.md) - Main skill guide
- [HOOK_MECHANISMS.md](HOOK_MECHANISMS.md) - How hooks work
- [SKILL_RULES_REFERENCE.md](SKILL_RULES_REFERENCE.md) - Configuration reference
