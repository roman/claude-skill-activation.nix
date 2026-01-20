#!/usr/bin/env bash
#
# Test hierarchical loading of skill-rules.json files
#
# This test verifies that skill rules are loaded from multiple locations
# and merged with proper priority ordering:
#   1. Explicit CLI path (highest)
#   2. $CLAUDE_PROJECT_DIR/.claude/skills/skill-rules.json
#   3. ./.claude/skills/skill-rules.json (cwd)
#   4. ~/.claude/skills/skill-rules.json (lowest)
#
# Usage:
#   ./test-hierarchical-loading.sh [--activation-cmd PATH] [--fixtures-dir PATH]
#
# When run without arguments, it will auto-detect paths based on script location
# and build the package if needed.
#

set -euo pipefail

# Colors for output (disabled if not a tty)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Paths (can be overridden via CLI)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES_DIR="${FIXTURES_DIR:-$SCRIPT_DIR/fixtures}"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
ACTIVATION_CMD="${ACTIVATION_CMD:-}"

# Temporary test environment
TEST_TMPDIR=""

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --activation-cmd)
                ACTIVATION_CMD="$2"
                shift 2
                ;;
            --fixtures-dir)
                FIXTURES_DIR="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: $0 [--activation-cmd PATH] [--fixtures-dir PATH]"
                echo ""
                echo "Options:"
                echo "  --activation-cmd PATH  Path to claude-skill-activation binary"
                echo "  --fixtures-dir PATH    Path to test fixtures directory"
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                exit 1
                ;;
        esac
    done
}

# Cleanup function
cleanup() {
    if [[ -n "$TEST_TMPDIR" && -d "$TEST_TMPDIR" ]]; then
        rm -rf "$TEST_TMPDIR"
    fi
}
trap cleanup EXIT

# Setup test environment
setup() {
    echo -e "${BLUE}Setting up test environment...${NC}"

    # Create temp directory structure
    TEST_TMPDIR=$(mktemp -d)
    mkdir -p "$TEST_TMPDIR/home/.claude/skills"
    mkdir -p "$TEST_TMPDIR/project/.claude/skills"

    # Verify fixtures directory exists
    if [[ ! -d "$FIXTURES_DIR" ]]; then
        echo -e "${RED}Error: Fixtures directory not found: $FIXTURES_DIR${NC}" >&2
        exit 1
    fi

    # Copy fixtures
    cp "$FIXTURES_DIR/home-skill-rules.json" "$TEST_TMPDIR/home/.claude/skills/skill-rules.json"
    cp "$FIXTURES_DIR/project-skill-rules.json" "$TEST_TMPDIR/project/.claude/skills/skill-rules.json"

    # Find activation command if not specified
    if [[ -z "$ACTIVATION_CMD" ]]; then
        if [[ -x "$PROJECT_ROOT/result/bin/claude-skill-activation" ]]; then
            ACTIVATION_CMD="$PROJECT_ROOT/result/bin/claude-skill-activation"
        else
            echo -e "${YELLOW}Building package...${NC}"
            (cd "$PROJECT_ROOT" && nix build .#claude-skill-activation)
            ACTIVATION_CMD="$PROJECT_ROOT/result/bin/claude-skill-activation"
        fi
    fi

    # Verify activation command exists
    if [[ ! -x "$ACTIVATION_CMD" ]]; then
        echo -e "${RED}Error: Activation command not found or not executable: $ACTIVATION_CMD${NC}" >&2
        exit 1
    fi

    echo -e "${GREEN}Setup complete${NC}"
    echo -e "  Activation command: $ACTIVATION_CMD"
    echo -e "  Fixtures directory: $FIXTURES_DIR"
    echo ""
}

# Run activation and capture output
run_activation() {
    local prompt="$1"
    local explicit_path="${2:-}"
    local home_dir="$TEST_TMPDIR/home"
    local project_dir="$TEST_TMPDIR/project"

    local json_input
    json_input=$(printf '{"session_id": "test", "prompt": "%s"}' "$prompt")

    if [[ -n "$explicit_path" ]]; then
        (cd "$project_dir" && export HOME="$home_dir" && echo "$json_input" | "$ACTIVATION_CMD" "$explicit_path" 2>&1) || true
    else
        (cd "$project_dir" && export HOME="$home_dir" && echo "$json_input" | "$ACTIVATION_CMD" 2>&1) || true
    fi
}

# Assert output contains string
assert_contains() {
    local output="$1"
    local expected="$2"
    local test_name="$3"

    TESTS_RUN=$((TESTS_RUN + 1))

    if echo "$output" | grep -q "$expected"; then
        echo -e "${GREEN}✓ PASS:${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL:${NC} $test_name"
        echo -e "  ${YELLOW}Expected to contain:${NC} $expected"
        echo -e "  ${YELLOW}Got:${NC}"
        echo "$output" | sed 's/^/    /'
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Assert output does NOT contain string
assert_not_contains() {
    local output="$1"
    local unexpected="$2"
    local test_name="$3"

    TESTS_RUN=$((TESTS_RUN + 1))

    if ! echo "$output" | grep -q "$unexpected"; then
        echo -e "${GREEN}✓ PASS:${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL:${NC} $test_name"
        echo -e "  ${YELLOW}Expected NOT to contain:${NC} $unexpected"
        echo -e "  ${YELLOW}Got:${NC}"
        echo "$output" | sed 's/^/    /'
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Assert output is empty
assert_empty() {
    local output="$1"
    local test_name="$2"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ -z "$output" ]]; then
        echo -e "${GREEN}✓ PASS:${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL:${NC} $test_name"
        echo -e "  ${YELLOW}Expected empty output, got:${NC}"
        echo "$output" | sed 's/^/    /'
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# ============================================================================
# TEST CASES
# ============================================================================

test_home_only_skill() {
    echo -e "${BLUE}━━━ Test: Home-only skill is found ━━━${NC}"

    local output
    output=$(run_activation "help with home-keyword")

    assert_contains "$output" "home-only-skill" "Home-only skill detected"
    assert_contains "$output" "SUGGESTED" "Home skill has medium priority (SUGGESTED)"
}

test_project_only_skill() {
    echo -e "${BLUE}━━━ Test: Project-only skill is found ━━━${NC}"

    local output
    output=$(run_activation "help with project-keyword")

    assert_contains "$output" "project-only-skill" "Project-only skill detected"
    assert_contains "$output" "RECOMMENDED" "Project skill has high priority (RECOMMENDED)"
}

test_project_overrides_home() {
    echo -e "${BLUE}━━━ Test: Project skill overrides home skill with same name ━━━${NC}"

    local output
    output=$(run_activation "help with shared-keyword")

    assert_contains "$output" "shared-skill" "Shared skill detected"
    assert_contains "$output" "CRITICAL" "Project version (critical) overrides home version (low)"
    assert_not_contains "$output" "OPTIONAL" "Home version (low/OPTIONAL) is NOT shown"
}

test_explicit_path_highest_priority() {
    echo -e "${BLUE}━━━ Test: Explicit path takes highest priority ━━━${NC}"

    local output
    output=$(run_activation "help with shared-keyword" "$FIXTURES_DIR/explicit-skill-rules.json")

    assert_contains "$output" "shared-skill" "Shared skill detected"
    assert_contains "$output" "RECOMMENDED" "Explicit version (high) overrides project (critical)"
    assert_not_contains "$output" "CRITICAL" "Project version (critical) is NOT shown"
}

test_explicit_only_skill() {
    echo -e "${BLUE}━━━ Test: Explicit-only skill is found ━━━${NC}"

    local output
    output=$(run_activation "help with explicit-keyword" "$FIXTURES_DIR/explicit-skill-rules.json")

    assert_contains "$output" "explicit-only-skill" "Explicit-only skill detected"
}

test_merging_unique_skills() {
    echo -e "${BLUE}━━━ Test: Unique skills from all sources are merged ━━━${NC}"

    # Test that we can trigger skills from both home and project in same run
    local output
    output=$(run_activation "home-keyword and project-keyword")

    assert_contains "$output" "home-only-skill" "Home-only skill found in merged results"
    assert_contains "$output" "project-only-skill" "Project-only skill found in merged results"
}

test_no_match_silent_exit() {
    echo -e "${BLUE}━━━ Test: No match exits silently ━━━${NC}"

    local output
    output=$(run_activation "completely unrelated prompt with no keywords")

    assert_empty "$output" "No output when no skills match"
}

test_no_rules_files_silent_exit() {
    echo -e "${BLUE}━━━ Test: No rules files exits silently ━━━${NC}"

    # Create empty directories (no skill-rules.json)
    local empty_home="$TEST_TMPDIR/empty-home"
    local empty_project="$TEST_TMPDIR/empty-project"
    mkdir -p "$empty_home/.claude/skills"
    mkdir -p "$empty_project/.claude/skills"

    local json_input='{"session_id": "test", "prompt": "any prompt"}'
    local output
    output=$(cd "$empty_project" && export HOME="$empty_home" && echo "$json_input" | "$ACTIVATION_CMD" 2>&1) || true

    assert_empty "$output" "No output when no rules files exist"
}

test_intent_pattern_matching() {
    echo -e "${BLUE}━━━ Test: Intent patterns are matched ━━━${NC}"

    local output
    output=$(run_activation "something home test pattern here")

    assert_contains "$output" "home-only-skill" "Intent pattern matched home skill"
}

# ============================================================================
# MAIN
# ============================================================================

print_summary() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}TEST SUMMARY${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "Tests run:    $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        return 1
    fi
}

main() {
    parse_args "$@"

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Hierarchical Loading Tests${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    setup

    # Run all tests
    test_home_only_skill
    echo ""
    test_project_only_skill
    echo ""
    test_project_overrides_home
    echo ""
    test_explicit_path_highest_priority
    echo ""
    test_explicit_only_skill
    echo ""
    test_merging_unique_skills
    echo ""
    test_no_match_silent_exit
    echo ""
    test_no_rules_files_silent_exit
    echo ""
    test_intent_pattern_matching

    print_summary
}

main "$@"
