# Check Commit - Run clang-format and cppcheck on changed files only
# Usage: .\check_commit.ps1 [commit-ref]

param(
    [string]$CommitRef = "--cached"
)

$ErrorActionPreference = "Continue"
$Global:Errors = 0

function Write-Info { Write-Host "[INFO] $args" -ForegroundColor Blue }
function Write-Success { Write-Host "[PASS] $args" -ForegroundColor Green }
function Write-Fail { Write-Host "[FAIL] $args" -ForegroundColor Red; $Global:Errors++ }

# Get changed files in software directory
if ($CommitRef -eq "--cached") {
    Write-Info "Checking staged files in software directory..."
    $Files = git diff --cached --name-only --diff-filter=ACM | Where-Object { $_ -match '^software/.*\.(c|h)$' }
} else {
    Write-Info "Checking files changed in commit: $CommitRef"
    $Files = git diff-tree --no-commit-id --name-only -r $CommitRef | Where-Object { $_ -match '^software/.*\.(c|h)$' }
}

if (-not $Files) {
    Write-Info "No C/H files changed in software directory"
    exit 0
}

Write-Host "`nFiles to check:"
$Files | ForEach-Object { Write-Host "  - $_" }
Write-Host ""

# Check clang-format
Write-Info "Running clang-format..."
$FormatErrors = 0
foreach ($file in $Files) {
    if (Test-Path $file) {
        $result = clang-format --dry-run -Werror $file 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "Format issues: $file"
            $FormatErrors = 1
        }
    }
}

if ($FormatErrors -eq 0) {
    Write-Success "All files properly formatted"
} else {
    Write-Fail "Formatting issues found. Run: clang-format -i <file>"
}

Write-Host ""

# Check cppcheck
Write-Info "Running cppcheck..."
$CppcheckErrors = 0
foreach ($file in $Files) {
    if (Test-Path $file) {
        $output = cppcheck --enable=all --inconclusive --error-exitcode=1 --suppress=missingIncludeSystem $file 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host $output
            $CppcheckErrors = 1
        }
    }
}

if ($CppcheckErrors -eq 0) {
    Write-Success "Static analysis passed"
}

Write-Host ""

# Summary
if ($Global:Errors -eq 0) {
    Write-Success "All checks passed!"
    exit 0
} else {
    Write-Fail "$($Global:Errors) check(s) failed"
    exit 1
}
