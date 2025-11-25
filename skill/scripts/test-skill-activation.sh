#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
SESSION_ID="test"
RULES_PATH=""
PROMPT=""
HOOK_CMD=""
ACTIVATION_CMD=""

# Print usage
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] <prompt>

Test skill activation with a given prompt.

OPTIONS:
    -h, --help              Show this help message
    -r, --rules-path PATH   Path to skill-rules.json (default: auto-detect)
    -s, --session ID        Session ID for testing (default: test)

DETECTION:
    Auto-detects configuration from:
    1. ./.claude/settings.json (current project)
    2. ~/.claude/settings.json (home directory)

EXAMPLES:
    # Test with a prompt (auto-detects from project or home)
    $(basename "$0") "I need to review reconcilers"

    # Test with custom session ID
    $(basename "$0") -s my-session "update controller logic"

    # Test with explicit rules path
    $(basename "$0") -r ~/.claude/skill-rules.json "test reconciler"

    # Pipe prompt from stdin
    echo "create new controller" | $(basename "$0")
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -r|--rules-path)
                RULES_PATH="$2"
                shift 2
                ;;
            -s|--session)
                SESSION_ID="$2"
                shift 2
                ;;
            *)
                PROMPT="$1"
                shift
                ;;
        esac
    done
}

# Get prompt from arguments or stdin
get_prompt() {
    if [[ -z "$PROMPT" ]]; then
        if [[ -t 0 ]]; then
            echo -e "${RED}Error: No prompt provided${NC}" >&2
            echo "Provide a prompt as an argument or pipe it via stdin" >&2
            echo "" >&2
            usage >&2
            exit 1
        else
            PROMPT=$(cat)
        fi
    fi
}

# Try to extract hook from a settings file
try_extract_hook() {
    local settings_file=$1
    local location=$2

    if [[ ! -f "$settings_file" ]]; then
        return 1
    fi

    echo -e "${BLUE}  Checking $settings_file ($location)${NC}"

    local hook_cmd
    hook_cmd=$(jq -r '.hooks.UserPromptSubmit[0].command' "$settings_file" 2>/dev/null || echo "")

    if [[ -n "$hook_cmd" && "$hook_cmd" != "null" ]]; then
        HOOK_CMD="$hook_cmd"
        echo -e "${GREEN}✓ Found hook in $location settings${NC}"
        return 0
    fi

    return 1
}

# Find hook command from settings files (cascade through project then home)
find_hook_command() {
    echo -e "${BLUE}→ Finding configuration${NC}"

    # Try project settings first
    if try_extract_hook ".claude/settings.json" "project"; then
        return 0
    fi

    echo -e "${YELLOW}  No UserPromptSubmit hook in project settings, trying home...${NC}"

    # Try home settings
    if try_extract_hook "$HOME/.claude/settings.json" "home"; then
        return 0
    fi

    # Neither worked, error out
    echo -e "${RED}Error: Could not find UserPromptSubmit hook${NC}" >&2
    echo "Checked:" >&2
    if [[ -f .claude/settings.json ]]; then
        echo "  - ./.claude/settings.json (no hook found)" >&2
    else
        echo "  - ./.claude/settings.json (file not found)" >&2
    fi
    if [[ -f ~/.claude/settings.json ]]; then
        echo "  - ~/.claude/settings.json (no hook found)" >&2
    else
        echo "  - ~/.claude/settings.json (file not found)" >&2
    fi
    echo "" >&2
    echo "Use -r to specify rules path directly" >&2
    exit 1
}

# Extract rules path from hook command or use provided path
extract_rules_path() {
    if [[ -z "$RULES_PATH" ]]; then
        # Extract the last argument (rules path) from the command
        RULES_PATH=$(echo "$HOOK_CMD" | awk '{print $NF}')

        # Expand tilde if present
        RULES_PATH="${RULES_PATH/#\~/$HOME}"

        echo -e "${GREEN}✓ Found rules path: $RULES_PATH${NC}"
    else
        echo -e "${BLUE}→ Using provided rules path: $RULES_PATH${NC}"
    fi
}

# Extract activation command from hook command
extract_activation_command() {
    # Extract the activation command (first part of the command)
    ACTIVATION_CMD=$(echo "$HOOK_CMD" | awk '{print $1}')

    # Expand tilde in activation command if present
    ACTIVATION_CMD="${ACTIVATION_CMD/#\~/$HOME}"

    echo -e "${GREEN}✓ Found activation command: $ACTIVATION_CMD${NC}"
}

# Verify all required files and commands exist
verify_configuration() {
    # Verify rules file exists
    if [[ ! -f "$RULES_PATH" ]]; then
        echo -e "${RED}Error: skill-rules.json not found at: $RULES_PATH${NC}" >&2
        exit 1
    fi

    # Verify activation command is set
    if [[ -z "$ACTIVATION_CMD" ]]; then
        echo -e "${RED}Error: Could not determine activation command${NC}" >&2
        exit 1
    fi

    # Warn if activation command is not executable
    if [[ ! -x "$ACTIVATION_CMD" ]]; then
        echo -e "${YELLOW}Warning: Activation command not executable: $ACTIVATION_CMD${NC}" >&2
    fi
}

# Print test header
print_test_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Testing Skill Activation${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Session ID:${NC} $SESSION_ID"
    echo -e "${YELLOW}Rules Path:${NC} $RULES_PATH"
    echo -e "${YELLOW}Prompt:${NC} $PROMPT"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Run the skill activation test
run_test() {
    print_test_header

    # Create JSON input
    local json_input
    json_input=$(jq -n \
        --arg session "$SESSION_ID" \
        --arg prompt "$PROMPT" \
        '{session_id: $session, prompt: $prompt}')

    # Run the test
    echo "$json_input" | "$ACTIVATION_CMD" "$RULES_PATH"

    echo ""
    echo -e "${GREEN}✓ Test completed${NC}"
}

# Main function
main() {
    parse_arguments "$@"
    get_prompt
    find_hook_command
    extract_rules_path
    extract_activation_command
    verify_configuration
    run_test
}

# Run main function
main "$@"
