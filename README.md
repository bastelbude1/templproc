# Template Processor - templproc

Simple Template Pattern Replacement Script, which can be used for tasker

replace **@PATTERN@** in template file with values from an file write output into task files

Note: template files must have an appendix like .txt, .json, .yaml, ...

## Diagram

![Template Processor](templproc.png)

## Usage

```
usage: templproc [-h] -V VALUES -P PATTERN -T TEMPLATE [-r] [-f]
                             [-p PROJECT] [-o OUTPUT_DIR]
                             [--log-level {DEBUG,INFO,WARNING,ERROR}]
                             [--version]

Simple Template Pattern Replacement Script

optional arguments:
  -h, --help            show this help message and exit
  -V VALUES, --Values VALUES
                        Comma-separated values or file path (supports TAB,
                        semicolon, newline delimiters)
  -P PATTERN, --Pattern PATTERN
                        Comma-separated patterns in @PATTERN@ format (e.g.,
                        "@HOST@,@IP@)
  -T TEMPLATE, --Template TEMPLATE
                        Template file, directory, or wildcard pattern (e.g.,
                        "template_*.txt")
  -r, --run             Execute replacement (default is dry-run)
  -f, --force           Force processing - warn about missing patterns instead
                        of erroring
  -p PROJECT, --project PROJECT
                        Project name (default: current PID)
  -o OUTPUT_DIR, --output_dir OUTPUT_DIR
                        Output directory (default: current_dir/<project>)
  --log-level {DEBUG,INFO,WARNING,ERROR}
                        Set logging level
  --version             Show version and exit

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
```


## Examples:

### Single value replacement
  `templproc -V "server1,server2,server3" -P "@HOSTNAME@" -T template.txt -r`

### Multi-column file with multiple patterns
  `templproc -V servers.txt -P "@HOST@,@IP@,@PORT@" -T config.yaml -r`

### process multiple templates at once
  `templproc -V values.txt -P "@VALUE@" -T "template_*.conf" -r`

### Ignore ERRORS (force mode)
  `templproc -V partial.txt -P "@HOST@" -T template.yaml -r --force`

  