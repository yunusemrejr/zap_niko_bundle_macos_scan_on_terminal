# Web Application Security Scanner

This script is a comprehensive security scanner that automates vulnerability assessment for local web applications using industry-standard security tools: OWASP ZAP and Nikto.

## Overview

The Web Application Security Scanner is a bash script that helps security professionals and developers perform automated security testing on local web applications. It orchestrates multiple scanning tools and generates consolidated HTML reports for easy review of potential vulnerabilities.

## Features

- **Automated Multi-Tool Scanning**: Combines the strengths of OWASP ZAP (for dynamic application security testing) and Nikto (for web server scanning)
- **Intelligent Tool Detection**: Automatically locates OWASP ZAP installation across multiple common paths on macOS
- **Fallback Mechanisms**: Implements multiple approaches to run ZAP if the standard method fails
- **Consolidated Reporting**: Generates a single HTML report that embeds and combines results from all tools
- **Error Handling**: Creates placeholder reports with helpful instructions if a tool fails or isn't found
- **User-Friendly Output**: Opens the final report automatically in the default browser

## How It Works

1. The script first establishes configuration variables including the target URL (defaulting to a local web application)
2. It then attempts to locate OWASP ZAP installation in common paths on macOS systems
3. For ZAP scanning, the script implements three different approaches:
   - Standard command-line execution
   - JAR-based execution for macOS app bundles
   - API-based execution via ZAP daemon mode
4. It runs a Nikto scan against the target URL
5. Finally, it generates a consolidated HTML report that embeds both scan results in a clean, organized format

## Requirements

- macOS (script is optimized for macOS paths and commands)
- OWASP ZAP (installed in a standard location)
- Nikto (available in PATH)

## Usage

Simply run the script and it will:
1. Detect and use available security tools
2. Scan the configured target URL (defaults to http://localhost:80/itaspdijital/)
3. Generate individual and combined reports
4. Open the combined report in your default browser

```bash
$ ./web_app_security_scanner.sh
```

You can customize the target URL by modifying the `TARGET_URL` variable at the top of the script.

## Report Structure

The generated HTML report includes:
- A summary section with target information and scan timestamp
- Embedded OWASP ZAP scan results
- Embedded Nikto scan results
- Clean, responsive layout for easy review

## Troubleshooting

If a security tool isn't found or fails to run, the script:
1. Creates a placeholder report explaining the issue
2. Provides instructions for manual execution
3. Continues with any available tools
4. Notes the failure in console output

This script is ideal for developers and security teams looking to incorporate automated security scanning into their local development and testing workflows.
