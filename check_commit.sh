#!/usr/bin/env bash
################################################################################
# Check Commit - Run clang-format and cppcheck on changed files only
# Usage: ./check_commit.sh [commit-ref]
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ERRORS=0

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_error() { echo -e "${RED}[FAIL]${NC} $1"; ((ERRORS++)); }

# Get commit reference (default: staged files)
COMMIT_REF="${1:---cached}"

# Get changed files in software directory
if [ "$COMMIT_REF" = "--cached" ]; then
    log_info "Checking staged files in software directory..."
    FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '^software/' | grep -E '\.(c|h)$' || true)
else
    log_info "Checking files changed in commit: $COMMIT_REF"
    FILES=$(git diff-tree --no-commit-id --name-only -r "$COMMIT_REF" | grep '^software/' | grep -E '\.(c|h)$' || true)
fi

if [ -z "$FILES" ]; then
    log_info "No C/H files changed in software directory"
    exit 0
fi

echo "Files to check:"
echo "$FILES" | sed 's/^/  - /'
echo ""

# Check clang-format
log_info "Running clang-format..."
FORMAT_ERRORS=0
for file in $FILES; do
    if [ -f "$file" ]; then
        if ! clang-format --dry-run -Werror "$file" 2>&1; then
            log_error "Format issues: $file"
            FORMAT_ERRORS=1
        fi
    fi
done

if [ $FORMAT_ERRORS -eq 0 ]; then
    log_success "All files properly formatted"
else
    log_error "Formatting issues found. Run: clang-format -i <file>"
fi

echo ""

# Check cppcheck
log_info "Running cppcheck..."
CPPCHECK_ERRORS=0
for file in $FILES; do
    if [ -f "$file" ]; then
        if ! cppcheck --enable=all --inconclusive --error-exitcode=1 --suppress=missingIncludeSystem "$file" 2>&1 | grep -v "Checking"; then
            CPPCHECK_ERRORS=1
        fi
    fi
done

if [ $CPPCHECK_ERRORS -eq 0 ]; then
    log_success "Static analysis passed"
fi

echo ""

# Summary
if [ $ERRORS -eq 0 ]; then
    log_success "All checks passed!"
    exit 0
else
    log_error "$ERRORS check(s) failed"
    exit 1
fi
