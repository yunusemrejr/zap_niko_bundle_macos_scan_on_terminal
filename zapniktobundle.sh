#!/bin/bash

# Web Application Security Scanner
# This script runs OWASP ZAP and Nikto against a local web application
# and generates consolidated HTML reports

# Configuration
TARGET_URL="http://localhost:80/itaspdijital/"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_DIR="${SCRIPT_DIR}/security_scan_${TIMESTAMP}"
FINAL_REPORT="${SCRIPT_DIR}/security_scan_report.html"

# Create report directory
mkdir -p "${REPORT_DIR}"

echo "Starting security scan of ${TARGET_URL}"
echo "Reports will be saved to ${REPORT_DIR}"

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Common locations for OWASP ZAP installation on macOS
ZAP_LOCATIONS=(
  "/Applications/ZAP.app/Contents/Java/zap.sh"
  "/Applications/ZAP.app/zap.sh"
  "/Applications/ZAP.app/Contents/Resources/Java/zap.sh"
  "/Applications/OWASP ZAP.app/Contents/Java/zap.sh"
  "$HOME/Downloads/ZAP/zap.sh"
  "$HOME/ZAP/zap.sh"
)

# Find OWASP ZAP installation
ZAP_COMMAND=""

# Use specific ZAP location provided by user
if [ -d "/Applications/ZAP.app" ]; then
  if [ -f "/Applications/ZAP.app/Contents/Java/zap.sh" ]; then
    ZAP_COMMAND="/Applications/ZAP.app/Contents/Java/zap.sh"
  elif [ -f "/Applications/ZAP.app/zap.sh" ]; then
    ZAP_COMMAND="/Applications/ZAP.app/zap.sh"
  else
    # Try to find zap.sh in the application bundle
    ZAP_SH=$(find "/Applications/ZAP.app" -name "zap.sh" -type f | head -n 1)
    if [ ! -z "$ZAP_SH" ]; then
      ZAP_COMMAND="$ZAP_SH"
    fi
  fi
fi

# If not found in specific location, try PATH and other common locations
if [ -z "$ZAP_COMMAND" ]; then
  if command_exists zap.sh; then
    ZAP_COMMAND="zap.sh"
  elif command_exists zap; then
    ZAP_COMMAND="zap"
  else
    for location in "${ZAP_LOCATIONS[@]}"; do
      if [ -f "$location" ]; then
        ZAP_COMMAND="$location"
        break
      fi
    done
  fi
fi

# Check if Nikto is installed
if ! command_exists nikto; then
  echo "Error: Nikto is not installed or not in PATH"
  echo "Install Nikto using: brew install nikto"
  exit 1
fi

# Verify ZAP is available
if [ -z "$ZAP_COMMAND" ]; then
  echo "Error: OWASP ZAP was not found on your system."
  echo "Common installation locations were checked."
  echo "Please install OWASP ZAP or manually specify the path to zap.sh."
  echo "Skipping ZAP scan and continuing with Nikto scan only."
  SKIP_ZAP=true
else
  echo "Found OWASP ZAP at: $ZAP_COMMAND"
  SKIP_ZAP=false
fi

# Run OWASP ZAP scan if available
ZAP_REPORT="${REPORT_DIR}/zap_report.html"
ZAP_SUCCESS=false

if [ "$SKIP_ZAP" = false ]; then
  echo "Running OWASP ZAP scan using: $ZAP_COMMAND"
  
  # Try different ways to run ZAP based on typical macOS installations
  if [[ "$ZAP_COMMAND" == *"/Contents/Java/"* ]] || [[ "$ZAP_COMMAND" == *"/Contents/Resources/Java/"* ]]; then
    # For ZAP.app, we might need to use the jar directly
    ZAP_DIR=$(dirname "$ZAP_COMMAND")
    
    echo "Attempting to run ZAP in daemon mode..."
    java -jar "$ZAP_DIR/zap.jar" -daemon -host 127.0.0.1 -port 8090 -config api.disablekey=true &
    ZAP_PID=$!
    
    # Give ZAP time to start
    echo "Starting ZAP daemon, please wait..."
    sleep 15
    
    # Use curl to access the ZAP API
    echo "Running scan via API..."
    curl "http://localhost:8090/JSON/spider/action/scan/?url=${TARGET_URL}" > /dev/null
    echo "Waiting for scan to complete (30 seconds)..."
    sleep 30 # Wait for spider to complete
    
    # Generate report
    echo "Generating report..."
    curl "http://localhost:8090/OTHER/core/other/htmlreport/" --output "${ZAP_REPORT}"
    
    # Kill ZAP process
    echo "Shutting down ZAP daemon..."
    kill $ZAP_PID
    
    if [ -s "${ZAP_REPORT}" ]; then
      echo "OWASP ZAP scan completed successfully via API."
      ZAP_SUCCESS=true
    else
      echo "API-based scan failed to generate a report."
      ZAP_SUCCESS=false
    fi
  else
    # Try standard command-line approach first
    echo "Attempting standard command-line approach..."
    "$ZAP_COMMAND" -cmd -quickurl "${TARGET_URL}" -quickout "${ZAP_REPORT}" -quickprogress 2>/dev/null
    
    if [ $? -eq 0 ] && [ -s "${ZAP_REPORT}" ]; then
      echo "OWASP ZAP scan completed successfully via command line."
      ZAP_SUCCESS=true
    else
      echo "Standard approach failed. Falling back to daemon mode..."
      ZAP_SUCCESS=false
    fi
  fi
  
  # If both methods failed, try one more approach with ZAP API
  if [ "$ZAP_SUCCESS" = false ]; then
    echo "Trying alternative approach with ZAP daemon..."
    
    # Start ZAP in daemon mode
    "$ZAP_COMMAND" -daemon -host 127.0.0.1 -port 8090 -config api.disablekey=true &
    ZAP_PID=$!
    
    # Give ZAP time to start
    echo "Starting ZAP daemon, please wait..."
    sleep 15
    
    # Use curl to access the ZAP API
    echo "Running scan via API..."
    curl "http://localhost:8090/JSON/spider/action/scan/?url=${TARGET_URL}" > /dev/null
    echo "Waiting for scan to complete (30 seconds)..."
    sleep 30 # Wait for spider to complete
    
    # Generate report
    echo "Generating report..."
    curl "http://localhost:8090/OTHER/core/other/htmlreport/" --output "${ZAP_REPORT}"
    
    # Kill ZAP process
    echo "Shutting down ZAP daemon..."
    kill $ZAP_PID
    
    if [ -s "${ZAP_REPORT}" ]; then
      echo "OWASP ZAP scan completed successfully via daemon API."
      ZAP_SUCCESS=true
    else
      echo "All ZAP approaches failed to generate a report."
      ZAP_SUCCESS=false
    fi
  fi
  
  # If all ZAP methods failed, create a placeholder report
  if [ "$ZAP_SUCCESS" = false ]; then
    echo "Creating placeholder for ZAP report..."
    cat > "${ZAP_REPORT}" << EOL
<!DOCTYPE html>
<html>
<head><title>ZAP Scan Not Available</title></head>
<body>
  <h1>OWASP ZAP Scan Results Not Available</h1>
  <p>The OWASP ZAP scan could not be completed. Please check your ZAP installation and try again manually.</p>
  <p>To run ZAP manually:</p>
  <ol>
    <li>Launch the OWASP ZAP application</li>
    <li>Enter the URL "${TARGET_URL}" in the Quick Start tab</li>
    <li>Click "Attack"</li>
  </ol>
</body>
</html>
EOL
    echo "Continuing with Nikto scan..."
  fi
else
  # Create placeholder for ZAP report if we skipped ZAP
  cat > "${ZAP_REPORT}" << EOL
<!DOCTYPE html>
<html>
<head><title>ZAP Scan Not Available</title></head>
<body>
  <h1>OWASP ZAP Scan Results Not Available</h1>
  <p>The OWASP ZAP scan was skipped because ZAP could not be found on your system.</p>
  <p>To run ZAP manually:</p>
  <ol>
    <li>Download and install OWASP ZAP from <a href="https://www.zaproxy.org/download/">https://www.zaproxy.org/download/</a></li>
    <li>Launch the OWASP ZAP application</li>
    <li>Enter the URL "${TARGET_URL}" in the Quick Start tab</li>
    <li>Click "Attack"</li>
  </ol>
</body>
</html>
EOL
fi

# Run Nikto scan
echo "Running Nikto scan..."
NIKTO_REPORT="${REPORT_DIR}/nikto_report.html"
nikto -h "${TARGET_URL}" -o "${NIKTO_REPORT}" -Format html

# Check if Nikto scan was successful
if [ $? -ne 0 ]; then
  echo "Error: Nikto scan failed."
  # Create placeholder for Nikto report
  cat > "${NIKTO_REPORT}" << EOL
<!DOCTYPE html>
<html>
<head><title>Nikto Scan Failed</title></head>
<body>
  <h1>Nikto Scan Results Not Available</h1>
  <p>The Nikto scan could not be completed. Please check your Nikto installation and try again manually.</p>
  <p>To run Nikto manually:</p>
  <ol>
    <li>Open a Terminal</li>
    <li>Run: nikto -h "${TARGET_URL}" -o nikto_report.html -Format html</li>
  </ol>
</body>
</html>
EOL
  echo "Created placeholder Nikto report."
else
  echo "Nikto scan completed successfully."
fi

# Create combined HTML report
echo "Creating combined HTML report..."

cat > "${FINAL_REPORT}" << EOL
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Security Scan Report - ${TIMESTAMP}</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            color: #333;
        }
        h1, h2, h3 {
            color: #2c3e50;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        .summary {
            background-color: #f8f9fa;
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 20px;
        }
        .report-section {
            margin-bottom: 30px;
            border: 1px solid #ddd;
            border-radius: 5px;
            padding: 15px;
        }
        .report-content {
            height: 600px;
            overflow: auto;
            border: 1px solid #ddd;
            padding: 10px;
            background-color: #f9f9f9;
        }
        .footer {
            margin-top: 20px;
            text-align: center;
            font-size: 0.8em;
            color: #777;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Security Scan Report</h1>
        
        <div class="summary">
            <h2>Scan Summary</h2>
            <p><strong>Target URL:</strong> ${TARGET_URL}</p>
            <p><strong>Scan Date:</strong> $(date)</p>
            <p><strong>Tools Used:</strong> OWASP ZAP, Nikto</p>
        </div>
        
        <div class="report-section">
            <h2>OWASP ZAP Scan Results</h2>
            <div class="report-content" id="zap-report">
                <iframe src="security_scan_${TIMESTAMP}/zap_report.html" width="100%" height="100%" frameborder="0">
                    Your browser does not support iframes. Please check the separate ZAP report file.
                </iframe>
            </div>
        </div>
        
        <div class="report-section">
            <h2>Nikto Scan Results</h2>
            <div class="report-content" id="nikto-report">
                <iframe src="security_scan_${TIMESTAMP}/nikto_report.html" width="100%" height="100%" frameborder="0">
                    Your browser does not support iframes. Please check the separate Nikto report file.
                </iframe>
            </div>
        </div>
        
        <div class="footer">
            <p>Generated by Web Application Security Scanner script on $(date)</p>
        </div>
    </div>
</body>
</html>
EOL

echo "Security scan completed."
echo "Combined report is available at: ${FINAL_REPORT}"
echo "Individual reports are in directory: ${REPORT_DIR}"

# Open the report in the default browser
open "${FINAL_REPORT}"
