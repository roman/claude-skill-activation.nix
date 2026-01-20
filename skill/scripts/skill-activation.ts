#!/usr/bin/env node
import { readFileSync, existsSync } from 'fs';
import { join } from 'path';

interface HookInput {
    session_id: string;
    transcript_path: string;
    cwd: string;
    permission_mode: string;
    prompt: string;
}

interface PromptTriggers {
    keywords?: string[];
    intentPatterns?: string[];
}

interface SkillRule {
    type: 'guardrail' | 'domain';
    enforcement: 'block' | 'suggest' | 'warn';
    priority: 'critical' | 'high' | 'medium' | 'low';
    promptTriggers?: PromptTriggers;
}

interface SkillRules {
    version: string;
    skills: Record<string, SkillRule>;
}

interface MatchedSkill {
    name: string;
    matchType: 'keyword' | 'intent';
    config: SkillRule;
}

function showHelp(toStderr: boolean = false) {
    const output = toStderr ? console.error : console.log;

    output('skill-activation-prompt v1.0.0');
    output('');
    output('Usage: skill-activation-prompt [OPTIONS] [skill-rules.json]');
    output('');
    output('Reads hook input from stdin and checks for skill activation.');
    output('Loads and merges skill rules from multiple locations hierarchically.');
    output('');
    output('Options:');
    output('  -h, --help          Show this help message and exit');
    output('  skill-rules.json    Optional explicit path to skill rules file (highest priority)');
    output('');
    output('Search Order (highest to lowest priority):');
    output('  1. Explicit CLI argument path');
    output('  2. $CLAUDE_PROJECT_DIR/.claude/skills/skill-rules.json');
    output('  3. ./.claude/skills/skill-rules.json (current directory)');
    output('  4. ~/.claude/skills/skill-rules.json (home directory)');
    output('');
    output('Skills from higher priority sources override those with the same name.');
    output('Skills unique to each source are merged together.');
    output('');
    output('Examples:');
    output('  # Auto-discover from hierarchy');
    output('  skill-activation-prompt < input.json');
    output('');
    output('  # With explicit path (takes highest priority)');
    output('  skill-activation-prompt /path/to/skill-rules.json < input.json');
}

function discoverSkillRulesFiles(explicitPath?: string): string[] {
    const paths: string[] = [];

    // 1. Explicit path (highest priority)
    if (explicitPath && existsSync(explicitPath)) {
        paths.push(explicitPath);
    }

    // 2. CLAUDE_PROJECT_DIR
    if (process.env.CLAUDE_PROJECT_DIR) {
        const projectPath = join(process.env.CLAUDE_PROJECT_DIR, '.claude', 'skills', 'skill-rules.json');
        if (existsSync(projectPath) && !paths.includes(projectPath)) {
            paths.push(projectPath);
        }
    }

    // 3. Current working directory
    const cwdPath = join(process.cwd(), '.claude', 'skills', 'skill-rules.json');
    if (existsSync(cwdPath) && !paths.includes(cwdPath)) {
        paths.push(cwdPath);
    }

    // 4. Home directory (lowest priority)
    const homePath = join(process.env.HOME || '', '.claude', 'skills', 'skill-rules.json');
    if (existsSync(homePath) && !paths.includes(homePath)) {
        paths.push(homePath);
    }

    return paths;
}

function mergeSkillRules(rulesArray: SkillRules[]): SkillRules {
    const merged: SkillRules = { version: '1.0', skills: {} };

    // Process in reverse (lowest priority first, higher priority overwrites)
    for (const rules of [...rulesArray].reverse()) {
        merged.version = rules.version || merged.version;
        merged.skills = { ...merged.skills, ...rules.skills };
    }

    return merged;
}

async function main() {
    try {
        // Parse command line arguments
        const args = process.argv.slice(2);

        // Check for help flag
        if (args.includes('--help') || args.includes('-h') || args.includes('help')) {
            showHelp(false);
            process.exit(0);
        }

        // Read input from stdin
        const input = readFileSync(0, 'utf-8');
        const data: HookInput = JSON.parse(input);
        const prompt = data.prompt.toLowerCase();

        // Discover skill rules files hierarchically
        const explicitPath = args.length > 0 ? args[0] : undefined;
        const discoveredPaths = discoverSkillRulesFiles(explicitPath);

        if (discoveredPaths.length === 0) {
            // No rules found - exit silently
            process.exit(0);
        }

        // Load and merge all found files
        const rulesArray: SkillRules[] = discoveredPaths.map(path =>
            JSON.parse(readFileSync(path, 'utf-8'))
        );
        const rules = mergeSkillRules(rulesArray);

        const matchedSkills: MatchedSkill[] = [];

        // Check each skill for matches
        for (const [skillName, config] of Object.entries(rules.skills)) {
            const triggers = config.promptTriggers;
            if (!triggers) {
                continue;
            }

            // Keyword matching
            if (triggers.keywords) {
                const keywordMatch = triggers.keywords.some(kw =>
                    prompt.includes(kw.toLowerCase())
                );
                if (keywordMatch) {
                    matchedSkills.push({ name: skillName, matchType: 'keyword', config });
                    continue;
                }
            }

            // Intent pattern matching
            if (triggers.intentPatterns) {
                const intentMatch = triggers.intentPatterns.some(pattern => {
                    const regex = new RegExp(pattern, 'i');
                    return regex.test(prompt);
                });
                if (intentMatch) {
                    matchedSkills.push({ name: skillName, matchType: 'intent', config });
                }
            }
        }

        // Generate output if matches found
        if (matchedSkills.length > 0) {
            let output = '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n';
            output += '🎯 SKILL ACTIVATION CHECK\n';
            output += '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n';

            // Group by priority
            const critical = matchedSkills.filter(s => s.config.priority === 'critical');
            const high = matchedSkills.filter(s => s.config.priority === 'high');
            const medium = matchedSkills.filter(s => s.config.priority === 'medium');
            const low = matchedSkills.filter(s => s.config.priority === 'low');

            if (critical.length > 0) {
                output += '⚠️ CRITICAL SKILLS (REQUIRED):\n';
                critical.forEach(s => output += `  → ${s.name}\n`);
                output += '\n';
            }

            if (high.length > 0) {
                output += '📚 RECOMMENDED SKILLS:\n';
                high.forEach(s => output += `  → ${s.name}\n`);
                output += '\n';
            }

            if (medium.length > 0) {
                output += '💡 SUGGESTED SKILLS:\n';
                medium.forEach(s => output += `  → ${s.name}\n`);
                output += '\n';
            }

            if (low.length > 0) {
                output += '📌 OPTIONAL SKILLS:\n';
                low.forEach(s => output += `  → ${s.name}\n`);
                output += '\n';
            }

            output += 'ACTION: Use Skill tool BEFORE responding\n';
            output += '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n';

            console.log(output);
        }

        process.exit(0);
    } catch (err) {
        console.error('Error in skill-activation-prompt hook:', err);
        process.exit(1);
    }
}

main().catch(err => {
    console.error('Uncaught error:', err);
    process.exit(1);
});
