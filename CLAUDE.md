# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**templproc** is a Python-based template pattern replacement script designed for task automation. It replaces `@PATTERN@` tokens in template files with values from input sources and generates multiple output files.

## Core Functionality

The script processes template files by:
- Reading template files containing patterns in `@PATTERN@` format (uppercase, underscores, numbers only)
- Replacing patterns with values from comma-separated strings or delimited files (TAB, semicolon, newline)
- Generating output files with sanitized filenames: `{template_name}_line{number:04d}.{extension}`
- Supporting multi-column data for multiple pattern replacements per template

## Commands

### Running the Script

```bash
# Dry-run mode (default - shows what would happen without creating files)
python3 templproc.py -V "value1,value2" -P "@PATTERN@" -T template.txt

# Execute mode (actually creates files)
python3 templproc.py -V values.txt -P "@HOST@,@IP@" -T config.yaml -r

# Force mode (warn about missing patterns instead of erroring)
python3 templproc.py -V partial.txt -P "@HOST@" -T template.yaml -r -f

# Multiple templates with wildcards
python3 templproc.py -V servers.txt -P "@NAME@,@IP@" -T "template_*.conf" -r

# With custom project name and output directory
python3 templproc.py -V data.txt -P "@VAL@" -T template.yaml -r -p myproject -o /path/to/output
```

### Common Options

- `-V, --Values`: Value source (comma-separated or file path)
- `-P, --Pattern`: Pattern definitions (e.g., `"@HOST@,@IP@,@PORT@"`)
- `-T, --Template`: Template file, directory, or wildcard pattern
- `-r, --run`: Execute (without this flag, it's dry-run)
- `-f, --force`: Continue with warnings instead of errors for missing patterns
- `-p, --project`: Project name (defaults to PID)
- `-o, --output_dir`: Output directory (defaults to `./<project>`)
- `--log-level`: DEBUG, INFO, WARNING, ERROR

## Architecture

### Script Structure

**Single-file Python script** (`templproc.py`) organized into functional sections:

1. **Constants and Configuration** (lines 55-96)
   - `ExitCodes`: Automation-friendly exit codes (SUCCESS=0, INVALID_ARGUMENTS=1, FILE_NOT_FOUND=2, PERMISSION_ERROR=3, PROCESSING_ERROR=4, INTERRUPTED=130)
   - `Limits`: File size (100KB), value lines (3000), value size (4KB), filename length (255)
   - `ALLOWED_EXTENSIONS`: Supported template file types

2. **File Management** (lines 101-204)
   - `output_file_manager`: Context manager for transactional file creation with automatic cleanup on failure
   - `cleanup_files`: Cleanup helper for interrupted or failed operations

3. **Logging** (lines 207-270)
   - `setup_logging`: Dual output to console and rotating file (`~/templproc/template_processor.log`)
   - Log format includes timestamps (ddMMMYY_HHMMSS)

4. **Input Parsing and Validation** (lines 275-768)
   - `parse_arguments`: CLI argument parsing with comprehensive help
   - `parse_values`: Multi-format value parsing (file or command-line)
   - `parse_patterns`: Pattern format validation (`@[A-Z_][A-Z0-9_]*@`)
   - `validate_inputs`: Cross-validation of patterns/values alignment

5. **Template Handling** (lines 773-920)
   - `load_template_content`: Multi-encoding support (utf-8, latin-1, windows-1252, ascii)
   - `load_and_validate_template`: Template caching and constraint validation
   - `get_templates`: Wildcard/directory/file path resolution
   - `validate_template_constraints`: Filename length and file size checks

6. **Pattern Processing** (lines 393-461, 1015-1114)
   - `find_all_patterns_in_template`: Extract all `@PATTERN@` tokens using regex
   - `validate_template_patterns`: Pre-processing validation
   - `validate_no_unreplaced_patterns`: Post-processing validation
   - `process_template_with_patterns`: Core replacement logic with case-sensitivity warnings

7. **Safety Checks** (lines 925-1010)
   - `validate_output_permissions`: Write permission verification
   - `validate_output_directory_safety`: Prevent template overwriting

8. **Main Processing** (lines 1117-1437)
   - Template content caching for performance
   - Progress reporting (every 5% for 20+ tasks)
   - Error handling with detailed logging
   - Cleanup on interruption or failure

### Key Design Patterns

- **Context Manager Pattern**: `output_file_manager` provides transactional guarantees
- **Caching**: Template content cached in `template_cache` dict to avoid re-reading
- **Validation Layers**: Early validation (inputs) → Template validation → Post-processing validation
- **Force Mode**: Optional warnings-only mode for multi-stage processing pipelines
- **Exit Codes**: Structured exit codes for automation integration

### Processing Flow

1. Parse CLI arguments
2. Load and parse values (file or command-line)
3. Parse and validate patterns
4. Discover templates (file/directory/wildcard)
5. Validate inputs (pattern/value alignment, sizes, uniqueness)
6. Check output directory permissions and safety
7. For each template:
   - Load and cache content
   - Validate template patterns
   - For each value row:
     - Replace patterns
     - Validate no unreplaced patterns remain
     - Generate output filename
     - Write output file (with transactional cleanup)
8. Report summary (successful/failed counts)

## Important Constraints

- **File Sizes**: Templates max 100KB, individual values max 4KB
- **Limits**: Max 3000 value lines, max 3000 total tasks
- **Filename Safety**: Generated filenames must not exceed 255 characters
- **Pattern Format**: Must be `@UPPERCASE_OR_UNDERSCORE@` format
- **Template Extensions**: Only `.txt`, `.conf`, `.yaml`, `.yml`, `.json`, `.xml`, `.cfg`, `.ini`, `.template`, `.tpl`
- **Output Safety**: Cannot write to template directory (prevents overwriting sources)

## Error Handling

- **Dry-run by default**: Requires explicit `-r` flag to write files
- **Transactional**: Automatic cleanup of partial files on failure/interruption
- **Force mode** (`-f`): Allows unreplaced patterns with warnings (for multi-stage workflows)
- **Case sensitivity**: Warns if pattern case mismatches between template and provided patterns
- **Progress reporting**: Shows percentage for jobs with 20+ tasks

## Development Workflow

### Code Review Requirements

**MANDATORY**: Before pushing **code changes** to GitHub, ALWAYS run CodeRabbit code review:

```bash
/home/baste/.local/bin/coderabbit review --prompt-only --type committed --base-commit HEAD~5
```

**When CodeRabbit review is REQUIRED:**
- ✅ Changes to `templproc.py` (main script)
- ✅ Changes to test files in `tests/`
- ✅ Changes to test scripts (`run_tests.sh`)

**When CodeRabbit review is NOT required:**
- ❌ Documentation-only changes (README.md, CLAUDE.md)
- ❌ Tarball rebuilds (no code changes)
- ❌ Version history updates

**Process:**
1. Make code changes and commit locally
2. Run CodeRabbit review with `--prompt-only` flag
3. Fix any issues found by CodeRabbit
4. Re-run CodeRabbit if fixes were made
5. Only push to GitHub after CodeRabbit review passes with no issues

**Important Notes:**
- CodeRabbit has rate limits (~1 hour between large reviews)
- Use `--base-commit HEAD~N` to review last N commits
- The `--prompt-only` flag shows what CodeRabbit would tell an AI to fix
- Fix all reported issues before pushing
- Rebuild and push tarball after any code/documentation changes

### Release Checklist

When releasing a new version:
1. ✅ Update version number in `templproc.py` (`__version__`)
2. ✅ Update version in `README.md` (Version History section)
3. ✅ Run full test suite: `cd tests && bash run_tests.sh`
4. ✅ Verify 100% test pass rate (52/52 tests)
5. ✅ Run CodeRabbit review: `/home/baste/.local/bin/coderabbit review --prompt-only`
6. ✅ Fix any CodeRabbit issues
7. ✅ Rebuild tarball: `tar -czf templproc-X.Y.Z.tar.gz --exclude='.git' --exclude='.claude' --exclude='.gitignore' --exclude='CLAUDE.md' --exclude='*.log' templproc/templproc.py templproc/README.md templproc/templproc.png templproc/tests/`
8. ✅ Commit and push all changes including tarball
9. ✅ Create git tag: `git tag -a vX.Y.Z -m "Release vX.Y.Z"`
10. ✅ Push tags: `git push --tags`
