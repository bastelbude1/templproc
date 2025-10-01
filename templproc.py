#!/usr/bin/env python3
"""

Simple Template Pattern Replacement Script
This script processes template files by replacing defined patterns with values.
Supports both single values and multi-column data from files.
Enhanced with comprehensive pattern validation and force mode support.
Version: 1.0.3
"""

import argparse
import os
import sys
import re
import logging
import glob
from logging.handlers import RotatingFileHandler
from pathlib import Path
from typing import List, Dict, Tuple, Optional
from contextlib import contextmanager

# Script version
__version__ = "1.0.3"

# Exit codes for automation/scripting

class ExitCodes:

    SUCCESS = 0
    INVALID_ARGUMENTS = 1
    FILE_NOT_FOUND = 2
    PERMISSION_ERROR = 3
    PROCESSING_ERROR = 4
    INTERRUPTED = 130  # Standard code for Ctrl+C

# Grouped Constants

class Limits:

    FILE_SIZE = 100 * 1024  # 100KB
    VALUE_LINES = 3000
    VALUE_SIZE = 4 * 1024  # 4KB per individual value
    FILENAME_LENGTH = 255  # OS filesystem limit

class Log:

    MAX_SIZE = 1024 * 1024  # 1MB
    BACKUP_COUNT = 9
ALLOWED_EXTENSIONS = {'.txt', '.conf', '.yaml', '.yml', '.json', '.xml', '.cfg', '.ini', '.template', '.tpl'}

@contextmanager

def output_file_manager(run_mode: bool, logger: logging.Logger):

    """Context manager for tracking and cleaning up created files on failure."""

    created_files = []

    def create_file(path: Path, content: str) -> bool:

        """Create file and track it for cleanup."""

        try:
            if run_mode:
                path.write_text(content, encoding='utf-8')
                created_files.append(path)
                logger.info(f"Created: {path}")
            else:
                logger.info(f"Would create: {path}")
            return True
        except Exception as e:
            logger.error(f"Error creating {path}: {e}")
            return False
    try:
        yield create_file
    except KeyboardInterrupt:
        logger.warning("Process interrupted by user")
        if run_mode and created_files:
            response = input("\nClean up partially created files? (y/N): ").strip().lower()
            if response in ['y', 'yes']:
                cleanup_files(created_files, logger)
        sys.exit(ExitCodes.INTERRUPTED)
    except Exception as e:
        logger.error(f"Unexpected error during processing: {e}")
        if run_mode and created_files:
            logger.warning("Processing failed, cleaning up partial files...")
            cleanup_files(created_files, logger)
        sys.exit(ExitCodes.PROCESSING_ERROR)

def cleanup_files(files: List[Path], logger: logging.Logger) -> None:

    """Clean up list of files."""

    if not files:
        return
    logger.info(f"Cleaning up {len(files)} files...")
    cleaned = 0
    for file_path in files:
        try:
            if file_path.exists():
                file_path.unlink()
                cleaned += 1
        except Exception as e:
            logger.warning(f"Could not remove {file_path}: {e}")
    logger.info(f"Cleaned up {cleaned}/{len(files)} files")

def setup_logging(log_level: str = 'INFO') -> logging.Logger:

    """Set up logging with console and rotating file output."""

    logger = logging.getLogger('template_processor')
    logger.setLevel(getattr(logging, log_level.upper()))
    logger.handlers.clear()
    time_format = '%d%b%y_%H%M%S'

    # Console handler
    console = logging.StreamHandler(sys.stdout)
    console.setFormatter(logging.Formatter(f'%(asctime)s - %(levelname)s - %(message)s',
                                         datefmt=time_format))
    logger.addHandler(console)

    # File handler with rotation
    try:
        log_dir = Path.home() / Path(__file__).stem
        log_dir.mkdir(exist_ok=True)
        log_file = log_dir / 'template_processor.log'
        file_handler = RotatingFileHandler(log_file, maxBytes=Log.MAX_SIZE,
                                         backupCount=Log.BACKUP_COUNT, encoding='utf-8')
        file_handler.setFormatter(logging.Formatter(
            f'%(asctime)s - %(levelname)s - %(funcName)s:%(lineno)d - %(message)s',
            datefmt=time_format))
        logger.addHandler(file_handler)
        logger.info(f"Logging to: {log_file}")
    except Exception as e:
        logger.warning(f"Could not set up file logging: {e}")
    return logger

def parse_arguments():

    """Parse command line arguments."""

    parser = argparse.ArgumentParser(
        description="Simple Template Pattern Replacement Script",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""

Arguments Details:
  -V, --Values:
    • Comma-separated values: "value1,value2,value3"
    • File path containing values (one per line or delimited)
    • Supported delimiters in files: TAB, semicolon (;), or newline
    • Comments starting with # are ignored
    • Maximum 3000 lines in value files
  -P, --Pattern:
    • One or more comma-separated patterns: "@HOST@,@IP@,@PORT@"
    • Must be in format @PATTERN_NAME@ (uppercase, underscores, numbers)
    • Number of patterns should match values per line
  -T, --Template:
    • Single template file: "config.yaml"
    • Directory containing templates: "/path/to/templates/"
    • Shell wildcards: "template_*.txt" (expanded by shell)
    • Supported extensions: .txt, .conf, .yaml, .yml, .json, .xml, .cfg, .ini, .template, .tpl
    • Maximum 100KB per template file
  -f, --force:
    • Force processing mode - warns about missing patterns instead of erroring
    • Useful for multi-stage template processing
    • Allows unreplaced patterns in output files
Examples:
  python template-processor.py -V "server1,server2,server3" -P "@HOSTNAME@" -T template.txt -r
  python template-processor.py -V servers.txt -P "@HOST@,@IP@,@PORT@" -T config.yaml -r
  python template-processor.py -V values.txt -P "@VALUE@" -T "template_*.conf" -r
  python template-processor.py -V partial.txt -P "@HOST@" -T template.yaml -r --force
        """

    )
    parser.add_argument('-V', '--Values', required=True,
                       help='Comma-separated values or file path (supports TAB, semicolon, newline delimiters)')
    parser.add_argument('-P', '--Pattern', required=True,
                       help='Comma-separated patterns in @PATTERN@ format (e.g., "@HOST@,@IP@)')
    parser.add_argument('-T', '--Template', required=True,
                       help='Template file, directory, or wildcard pattern (e.g., "template_*.txt")')
    parser.add_argument('-r', '--run', action='store_true',
                       help='Execute replacement (default is dry-run)')
    parser.add_argument('-f', '--force', action='store_true',
                       help='Force processing - warn about missing patterns instead of erroring')
    parser.add_argument('-p', '--project', help='Project name (default: current PID)')
    parser.add_argument('-o', '--output_dir', help='Output directory (default: current_dir/<project>)')
    parser.add_argument('--log-level', choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'],
                       default='INFO', help='Set logging level')
    parser.add_argument('--version', action='version', version=f'%(prog)s {__version__}',
                       help='Show version and exit')
    return parser.parse_args()

def find_all_patterns_in_template(content: str) -> List[str]:

    """Find all @PATTERN@ tokens in template content."""

    pattern_regex = r'@[A-Z_][A-Z0-9_]*@'
    return list(set(re.findall(pattern_regex, content)))

def validate_template_patterns(template_content: str, provided_patterns: List[str],

                             template_name: str, force_mode: bool, logger: logging.Logger) -> None:
    """Validate that all template patterns have corresponding provided patterns."""

    found_patterns = find_all_patterns_in_template(template_content)
    missing_patterns = [p for p in found_patterns if p not in provided_patterns]
    if missing_patterns:
        message = f"Template '{template_name}' contains patterns without values: {missing_patterns}"
        if force_mode:
            logger.warning(f"FORCE MODE: {message}")
        else:
            raise ValueError(message)
    if found_patterns:
        logger.debug(f"Template '{template_name}' contains patterns: {found_patterns}")

def validate_no_unreplaced_patterns(processed_content: str, template_name: str,

                                   line_num: int, force_mode: bool, logger: logging.Logger) -> None:
    """Ensure no @PATTERN@ tokens remain in processed content."""

    remaining_patterns = find_all_patterns_in_template(processed_content)
    if remaining_patterns:
        message = f"Unreplaced patterns in {template_name} line {line_num}: {remaining_patterns}"
        if force_mode:
            logger.warning(f"FORCE MODE: {message}")
        else:
            raise ValueError(f"CRITICAL: {message} - Output file would be broken!")

def validate_value_sizes(values_list: List[List[str]]) -> None:

    """Check individual value sizes to prevent memory issues."""

    for row_idx, row in enumerate(values_list, 1):
        for col_idx, value in enumerate(row):
            if len(value) > Limits.VALUE_SIZE:
                raise ValueError(f"Value too large at row {row_idx}, column {col_idx}: "
                               f"{len(value)} chars (max {Limits.VALUE_SIZE//1024}KB)")

def validate_template_constraints(template_file: Path) -> None:

    """Validate template file constraints (filename length, file size, etc.)."""

    # Check filename length first
    base_name = re.sub(r'[^\w\-_.]', '_', template_file.stem)
    extension = template_file.suffix
    longest_filename = base_name + f"_line{Limits.VALUE_LINES:04d}" + extension
    if len(longest_filename) > Limits.FILENAME_LENGTH:
        excess = len(longest_filename) - Limits.FILENAME_LENGTH
        raise ValueError(
            f"Template filename too long: '{template_file.name}' would generate filenames "
            f"exceeding {Limits.FILENAME_LENGTH} characters (by {excess} chars). "
            f"Please rename template to be {excess} characters shorter."
        )

    # Check file size
    if template_file.stat().st_size > Limits.FILE_SIZE:
        raise ValueError(f"Template file too large (max {Limits.FILE_SIZE//1024}KB): {template_file}")

def validate_inputs(patterns: List[str], values_list: List[List[str]], logger: logging.Logger) -> None:

    """Combined validation for all inputs."""

    # Check pattern uniqueness
    seen_patterns = set()
    duplicates = []
    for pattern in patterns:
        if pattern in seen_patterns:
            duplicates.append(pattern)
        seen_patterns.add(pattern)
    if duplicates:
        raise ValueError(f"Duplicate patterns found: {duplicates}. Each pattern must be unique.")

    # Check individual value sizes and special characters
    special_chars = ['$', '^', '[', ']', '(', ')', '{', '}', '\\', '|', '*', '+', '?']
    for row_idx, row in enumerate(values_list, 1):
        for col_idx, value in enumerate(row):

            # Check value size
            if len(value) > Limits.VALUE_SIZE:
                raise ValueError(f"Value too large at row {row_idx}, column {col_idx}: "
                               f"{len(value)} chars (max {Limits.VALUE_SIZE//1024}KB)")

            # Check for newlines (usually unintended)
            if '\n' in value or '\r' in value:
                logger.warning(f"Value at row {row_idx}, column {col_idx} contains newline characters")

            # Log special characters (informational)
            found_special = [char for char in special_chars if char in value]
            if found_special:
                logger.debug(f"Value at row {row_idx}, column {col_idx} contains special characters: {found_special}")

    # Check pattern/value alignment
    pattern_count = len(patterns)
    for row_idx, row in enumerate(values_list, 1):
        value_count = len(row)
        if value_count < pattern_count:
            missing_patterns = patterns[value_count:]
            logger.error(f"Row {row_idx}: {value_count} values but {pattern_count} patterns. "
                        f"Missing values for patterns: {missing_patterns}")
            raise ValueError(f"Insufficient values in row {row_idx} - need {pattern_count} values, got {value_count}")
        elif value_count > pattern_count:
            extra_values = row[pattern_count:]
            logger.warning(f"Row {row_idx}: {value_count} values but only {pattern_count} patterns. "
                          f"Extra values will be ignored: {extra_values}")

def parse_values(values_input: str, logger: logging.Logger) -> List[List[str]]:

    """Parse values from string or file with validation."""

    values = []

    # Check if it looks like a file path and handle accordingly
    if os.path.isfile(values_input):

        # File exists - read from file
        logger.info(f"Reading values from file: {values_input}")
        try:
            line_count = 0
            with open(values_input, 'r', encoding='utf-8') as f:
                for line_num, line in enumerate(f, 1):
                    line = line.strip()
                    if not line or line.startswith('#'):
                        continue
                    line_count += 1
                    if line_count > Limits.VALUE_LINES:
                        raise ValueError(f"Too many value lines (max {Limits.VALUE_LINES})")

                    # Split on tab, semicolon, or treat as single value
                    if '\t' in line:
                        row = [v.strip() for v in line.split('\t') if v.strip()]
                    elif ';' in line:
                        row = [v.strip() for v in line.split(';') if v.strip()]
                    else:
                        row = [line]
                    if row:
                        values.append(row)
        except Exception as e:
            raise ValueError(f"Error reading values file: {e}")
    elif ('/' in values_input or '\\' in values_input or values_input.endswith('.txt') or
          values_input.endswith('.csv') or values_input.endswith('.dat')):

        # Looks like a file path but file doesn't exist
        raise ValueError(f"Values file not found: {values_input}")
    else:

        # Parse as comma-separated string
        logger.info("Parsing values from command line")
        items = [item.strip() for item in values_input.split(',') if item.strip()]
        for item in items:
            if ';' in item:
                row = [v.strip() for v in item.split(';') if v.strip()]
            else:
                row = [item]
            if row:
                values.append(row)
    if not values:
        raise ValueError("No values found")
    logger.info(f"Parsed {len(values)} value rows")
    return values

def parse_patterns(pattern_str: str) -> List[str]:

    """Parse and validate comma-separated patterns."""

    try:
        patterns = [pattern.strip() for pattern in pattern_str.split(',') if pattern.strip()]

        # Check for empty patterns
        if not patterns:
            raise ValueError("No patterns provided")

        # Validate pattern format - assign $ to variable to avoid issues
        end_anchor = '$'
        pattern_regex = r'^@[A-Z_][A-Z0-9_]*@' + end_anchor
        for pattern in patterns:
            if not re.match(pattern_regex, pattern):
                raise ValueError(f"Invalid pattern format: '{pattern}'. Use @PATTERN_NAME@")
        return patterns
    except Exception as e:
        raise ValueError(f"Error parsing patterns: {e}")

def load_template_content(template_file: Path, logger: logging.Logger) -> str:

    """Load template content with encoding detection."""

    # Read with encoding detection
    encodings = ['utf-8', 'utf-8-sig', 'latin-1', 'windows-1252', 'ascii']
    for encoding in encodings:
        try:
            content = template_file.read_text(encoding=encoding)
            if encoding != 'utf-8':
                logger.debug(f"File {template_file.name} read with {encoding} encoding")
            return content
        except UnicodeDecodeError:
            continue
        except Exception as e:
            logger.debug(f"Error reading {template_file} with {encoding}: {e}")
            continue
    raise ValueError(f"Could not decode file {template_file} with any supported encoding")

def load_and_validate_template(template_file: Path, content_cache: Dict[Path, str], logger: logging.Logger) -> str:

    """Load template with caching and validation."""

    # Return cached content if available
    if template_file in content_cache:
        logger.debug(f"Using cached content for {template_file.name}")
        return content_cache[template_file]

    # Validate constraints first
    validate_template_constraints(template_file)

    # Load content
    content = load_template_content(template_file, logger)

    # Validate not empty
    if not content or not content.strip():
        raise ValueError(f"Template {template_file.name} is empty or contains only whitespace")

    # Cache the content
    content_cache[template_file] = content
    logger.debug(f"Cached content for {template_file.name}")
    return content

def get_templates(template_path: str, logger: logging.Logger) -> List[Path]:

    """Get list of template files with wildcard support."""

    path = Path(template_path)
    templates = []

    # Try direct path first
    if path.exists():
        if path.is_file():
            templates = [path]
        elif path.is_dir():
            for f in path.iterdir():
                if f.is_file() and f.suffix.lower() in ALLOWED_EXTENSIONS:
                    templates.append(f)
            if not templates:
                raise ValueError(f"No valid template files found in {template_path}")
    else:

        # Try as glob pattern
        logger.info(f"Trying wildcard pattern: {template_path}")
        matches = glob.glob(template_path)
        if matches:
            for match in matches:
                f = Path(match)
                if f.is_file() and f.suffix.lower() in ALLOWED_EXTENSIONS:
                    templates.append(f)
            if not templates:
                raise ValueError(f"No valid template files found matching pattern: {template_path}")
        else:
            raise ValueError(f"No templates found: {template_path}")
    logger.info(f"Found {len(templates)} template file(s)")
    return templates

def validate_output_permissions(output_dir: Path, logger: logging.Logger) -> None:

    """Check output directory permissions before processing."""

    if output_dir.exists():
        if not os.access(output_dir, os.W_OK):
            raise ValueError(f"Output directory not writable: {output_dir}")
    else:
        parent = output_dir.parent
        if not parent.exists():
            raise ValueError(f"Parent directory does not exist: {parent}")
        if not os.access(parent, os.W_OK):
            raise ValueError(f"Cannot create output directory, parent not writable: {parent}")

def validate_output_directory_safety(output_dir: Path, template_paths: List[Path], logger: logging.Logger) -> None:

    """Check that output directory doesn't overlap with template directories to prevent overwriting."""

    output_resolved = output_dir.resolve()
    for template_path in template_paths:
        template_dir = template_path.parent.resolve()

        # Check if output directory is same as or inside template directory
        try:
            output_resolved.relative_to(template_dir)
            raise ValueError(
                f"Output directory '{output_dir}' would be inside template directory '{template_dir}'. "
                f"This could overwrite source templates. Please use a different output directory."
            )
        except ValueError as e:
            if "would be inside template directory" in str(e):
                raise

            # relative_to() raises ValueError if paths don't overlap - this is what we want
            continue

        # Check if template directory is inside output directory 
        try:
            template_dir.relative_to(output_resolved)
            logger.warning(
                f"Template directory '{template_dir}' is inside output directory '{output_dir}'. "
                f"This is allowed but be careful not to use output files as templates."
            )
        except ValueError:

            # relative_to() raises ValueError if paths don't overlap - this is fine
            continue

def process_template_with_patterns(content: str, patterns: List[str], values: List[str],
                                 template_name: str, logger: logging.Logger) -> Tuple[str, int]:
    """Process template with pattern validation and safe replacement."""

    # Check which patterns exist and validate case
    found_patterns = []
    missing_patterns = []
    for pattern in patterns:
        if pattern in content:
            found_patterns.append(pattern)
        else:
            missing_patterns.append(pattern)

            # Check for case issues
            pattern_core = pattern[1:-1]  # Remove @ symbols
            lower_pattern = f"@{pattern_core.lower()}@"
            upper_pattern = f"@{pattern_core.upper()}@"
            if pattern != upper_pattern and upper_pattern in content:
                logger.warning(f"Found uppercase version '{upper_pattern}' in template {template_name}, but pattern is '{pattern}'")
            elif pattern != lower_pattern and lower_pattern in content:
                logger.warning(f"Found lowercase version '{lower_pattern}' in template {template_name}, but pattern is '{pattern}'")
    if missing_patterns:
        logger.warning(f"Patterns not found in template {template_name}: {missing_patterns}")

    # Create pattern-value pairs and sort by length (longest first) to prevent interference
    pattern_value_pairs = []
    for i, pattern in enumerate(patterns):
        if i < len(values):
            pattern_value_pairs.append((pattern, str(values[i])))
    pattern_value_pairs.sort(key=lambda x: len(x[0]), reverse=True)

    # Replace patterns
    result = content
    total_replacements = 0
    for pattern, value in pattern_value_pairs:
        count = result.count(pattern)
        if count > 0:
            result = result.replace(pattern, value)
            total_replacements += count
    return result, total_replacements

def generate_filename(template_file: Path, line_number: int) -> str:

    """Generate output filename."""

    # Fix regex: put hyphen at end of character class to avoid range interpretation
    name = re.sub(r'[^\w_.-]', '_', template_file.stem)
    return f"{name}_line{line_number:04d}{template_file.suffix}"

def main():

    """Main function with proper exit codes for automation."""

    try:
        args = parse_arguments()
        logger = setup_logging(args.log_level)
        logger.info("Starting template processor")

        # Set project name and output directory
        project = args.project or f"project_{os.getpid()}"
        project = re.sub(r'[^\w\-_.]', '_', project)
        output_dir = Path(args.output_dir or '.') / project

        # Parse and validate all inputs
        try:
            values_list = parse_values(args.Values, logger)
            patterns = parse_patterns(args.Pattern)
            templates = get_templates(args.Template, logger)
        except ValueError as e:
            logger.error(f"Invalid input: {e}")
            sys.exit(ExitCodes.INVALID_ARGUMENTS)
        except FileNotFoundError as e:
            logger.error(f"File not found: {e}")
            sys.exit(ExitCodes.FILE_NOT_FOUND)

        # Combined input validation
        try:
            validate_inputs(patterns, values_list, logger)
        except ValueError as e:
            logger.error(f"Input validation failed: {e}")
            sys.exit(ExitCodes.INVALID_ARGUMENTS)

        # Early permission check
        try:
            validate_output_permissions(output_dir, logger)
        except ValueError as e:
            logger.error(f"Permission error: {e}")
            sys.exit(ExitCodes.PERMISSION_ERROR)

        # Check output directory safety (prevent overwriting templates)
        try:
            validate_output_directory_safety(output_dir, templates, logger)
        except ValueError as e:
            logger.error(f"Output directory safety check failed: {e}")
            sys.exit(ExitCodes.INVALID_ARGUMENTS)

        # Calculate and validate total tasks
        total_tasks = len(templates) * len(values_list)
        if total_tasks > Limits.VALUE_LINES:
            logger.error(f"Total tasks ({total_tasks}) exceeds limit ({Limits.VALUE_LINES})")
            sys.exit(ExitCodes.INVALID_ARGUMENTS)

        # Log summary
        logger.info(f"Project: {project}")
        logger.info(f"Output: {output_dir}")
        logger.info(f"Mode: {'RUN' if args.run else 'DRY-RUN'}")
        logger.info(f"Force mode: {'ENABLED' if args.force else 'DISABLED'}")
        logger.info(f"Templates: {len(templates)}, Values: {len(values_list)}, Tasks: {total_tasks}")

        # Create output directory if running
        if args.run:
            try:
                output_dir.mkdir(parents=True, exist_ok=True)
                validate_output_permissions(output_dir, logger)
                logger.info(f"Output directory ready: {output_dir}")
            except PermissionError as e:
                logger.error(f"Permission denied creating output directory: {e}")
                sys.exit(ExitCodes.PERMISSION_ERROR)
            except Exception as e:
                logger.error(f"Cannot create output directory {output_dir}: {e}")
                sys.exit(ExitCodes.PROCESSING_ERROR)

        # Process templates with automatic cleanup and caching
        successful = 0
        failed = 0
        template_cache = {}  # Cache template content for performance
        with output_file_manager(args.run, logger) as create_file:
            for template_idx, template_file in enumerate(templates, 1):
                logger.info(f"Processing template {template_idx}/{len(templates)}: {template_file.name}")
                try:
                    content = load_and_validate_template(template_file, template_cache, logger)
                except ValueError as e:
                    logger.error(f"Skipping template {template_file.name}: {e}")
                    continue
                except PermissionError as e:
                    logger.error(f"Permission denied reading {template_file.name}: {e}")
                    sys.exit(ExitCodes.PERMISSION_ERROR)

                # Validate template patterns against provided patterns
                try:
                    validate_template_patterns(content, patterns, template_file.name, args.force, logger)
                except ValueError as e:
                    logger.error(f"Pattern validation failed for {template_file.name}: {e}")
                    if not args.force:
                        sys.exit(ExitCodes.INVALID_ARGUMENTS)

                    # If force mode, continue processing with warnings already logged
                for line_num, value_row in enumerate(values_list, 1):

                    # Better progress reporting - show progress even for smaller jobs
                    current_task = (template_idx - 1) * len(values_list) + line_num
                    if total_tasks >= 20:  # Show progress for jobs with 20+ tasks
                        progress_interval = max(1, total_tasks // 20)  # Show max 20 progress updates
                        if current_task % progress_interval == 0:
                            percentage = (current_task / total_tasks) * 100
                            logger.info(f"Progress: {percentage:.0f}% ({current_task}/{total_tasks})")
                    try:
                        processed, replacements = process_template_with_patterns(
                            content, patterns, value_row, template_file.name, logger)
                        if replacements == 0:
                            logger.warning(f"No replacements in {template_file.name} line {line_num}")

                        # Critical: Check for unreplaced patterns in output
                        try:
                            validate_no_unreplaced_patterns(processed, template_file.name, line_num, args.force, logger)
                        except ValueError as e:
                            logger.error(f"Post-processing validation failed: {e}")
                            if not args.force:
                                failed += 1
                                continue

                            # If force mode, continue with warnings already logged
                        output_file = output_dir / generate_filename(template_file, line_num)
                        if create_file(output_file, processed):
                            successful += 1
                        else:
                            failed += 1
                    except Exception as e:
                        logger.error(f"Error processing {template_file.name} line {line_num}: {e}")
                        failed += 1

        # Final summary
        logger.info(f"Completed: {successful} successful, {failed} failed")
        if failed > 0:
            logger.error(f"Processing completed with {failed} failures")
            sys.exit(ExitCodes.PROCESSING_ERROR)
        else:
            logger.info("All tasks completed successfully")
            sys.exit(ExitCodes.SUCCESS)
    except KeyboardInterrupt:
        if 'logger' in locals():
            logger.warning("Process interrupted by user")
        else:
            print("Process interrupted by user", file=sys.stderr)
        sys.exit(ExitCodes.INTERRUPTED)
    except Exception as e:
        if 'logger' in locals():
            logger.error(f"Unexpected error: {e}")
        else:
            print(f"Unexpected error: {e}", file=sys.stderr)
        sys.exit(ExitCodes.PROCESSING_ERROR)
if __name__ == "__main__":
    main()
