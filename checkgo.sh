#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Uncomment the following line to enable debugging (prints each command before execution)
#set -x

# Function to print informational messages in green
echo_info() {
    echo -e "\e[32m[INFO]\e[0m $1"
}

# Function to print error messages in red
echo_error() {
    echo -e "\e[31m[ERROR]\e[0m $1"
}

# Function to install jq if not present
install_jq() {
    echo_info "Installing 'jq' for JSON processing..."
    sudo apt update -y
    sudo apt install -y jq
}

# Function to fetch the latest Go version from the official website
fetch_latest_go_version() {
    echo_info "Fetching the latest Go version from the official website..."

    # URL to fetch Go versions in JSON format
    GO_JSON_URL="https://go.dev/dl/?mode=json"

    # Fetch JSON data using curl or wget
    if command -v curl >/dev/null 2>&1; then
        GO_JSON=$(curl -s "$GO_JSON_URL")
    elif command -v wget >/dev/null 2>&1; then
        GO_JSON=$(wget -qO- "$GO_JSON_URL")
    else
        echo_error "Neither 'curl' nor 'wget' is installed. Please install one of them and retry."
        exit 1
    fi

    # Check if jq is installed; if not, install it
    if ! command -v jq >/dev/null 2>&1; then
        echo_info "'jq' is not installed. Attempting to install it..."
        install_jq
    fi

    # Extract the latest version number (the first entry in the JSON array)
    LATEST_GO_VERSION=$(echo "$GO_JSON" | jq -r '.[0].version')

    # Remove the leading 'go' from the version string to get just the version number
    LATEST_GO_VERSION_NUMBER=${LATEST_GO_VERSION#go}

    echo_info "Latest Go version is: $LATEST_GO_VERSION_NUMBER"

    # Export the latest Go version as an environment variable for use in other functions
    export LATEST_GO_VERSION_NUMBER
}

# Initialize GO_INSTALLED as false
GO_INSTALLED=false

# Function to check Go installation and version
check_go() {
    echo_info "Checking if Go is installed..."

    if command -v go >/dev/null 2>&1; then
        # Get the installed Go version
        INSTALLED_GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
        echo_info "Installed Go version: $INSTALLED_GO_VERSION"

        echo_info "Desired Go version: $LATEST_GO_VERSION_NUMBER"

        # Compare the installed Go version with the latest version
        if [[ "$INSTALLED_GO_VERSION" == "$LATEST_GO_VERSION_NUMBER" ]]; then
            echo_info "Go version $INSTALLED_GO_VERSION matches the latest version ($LATEST_GO_VERSION_NUMBER)."
            GO_INSTALLED=true
        else
            echo_info "Go version $INSTALLED_GO_VERSION does NOT match the latest version ($LATEST_GO_VERSION_NUMBER)."
            GO_INSTALLED=false
        fi
    else
        echo_info "Go is not installed on this system."
        GO_INSTALLED=false
    fi
}

# Function to install latest version of Go
install_go() {
    # Remove any existing Go installation
    if [ -d /usr/local/go ]; then
        echo_info "Removing existing Go installation..."
        sudo rm -rf /usr/local/go
    fi

    # Define Go version and download URL
    GO_VERSION=$LATEST_GO_VERSION_NUMBER
    GO_TARBALL=go$GO_VERSION.linux-amd64.tar.gz
    GO_DOWNLOAD_URL=https://go.dev/dl/$GO_TARBALL

    # Download Go
    echo_info "Downloading Go $GO_VERSION..."
    wget $GO_DOWNLOAD_URL -O /tmp/$GO_TARBALL

    # Install Go
    echo_info "Installing Go..."
    sudo tar -C /usr/local -xzf /tmp/$GO_TARBALL

    # Clean up the downloaded tarball
    rm /tmp/$GO_TARBALL

    # Set up Go environment variables in ~/.bashrc
    echo_info "Setting up Go environment variables..."

    # Add Go binary to PATH if not already present
    if ! grep -q 'export PATH=/usr/local/go/bin:$PATH' ~/.bashrc; then
        echo 'export PATH=/usr/local/go/bin:$PATH' >> ~/.bashrc
    fi

    # Set GOPATH to $HOME/go if not already set
    if ! grep -q 'export GOPATH=$HOME/go' ~/.bashrc; then
        echo 'export GOPATH=$HOME/go' >> ~/.bashrc
    fi

    # Add GOPATH/bin to PATH if not already present
    if ! grep -q 'export PATH=$PATH:$GOPATH/bin' ~/.bashrc; then
        echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.bashrc
    fi

    # Apply the environment variables to the current session
    echo_info "Applying environment variables..."
    export PATH=/usr/local/go/bin:$PATH
    export GOPATH=$HOME/go
    export PATH=$PATH:$GOPATH/bin

    # Verify Go installation
    echo_info "Verifying Go installation..."
    go version
}

ensure_gopath_bin_in_path() {
    if [[ ":$PATH:" != *":$GOPATH/bin:"* ]]; then
        echo_info "Adding \$GOPATH/bin to PATH in ~/.bashrc..."
        echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.bashrc
        export PATH=$PATH:$GOPATH/bin
        echo_info "Added \$GOPATH/bin to PATH. Please restart your terminal or run 'source ~/.bashrc' to apply the changes."
    else
        echo_info "\$GOPATH/bin is already in your PATH."
    fi
}

# Function to install the tools
install_tools(){

    echo_info "Starting installation of Go-based tools..."

    # List of tools to install: "RepositoryPath ExecutableName ToolName"
    TOOLS=(
        "github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest"
        "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
        "github.com/projectdiscovery/httpx/cmd/httpx@latest"
        "github.com/projectdiscovery/interactsh/cmd/interactsh-client@latest"
        "github.com/hahwul/dalfox/v2@latest"
        "github.com/ffuf/ffuf@latest"
        "github.com/tomnomnom/qsreplace@latest"
        "github.com/tomnomnom/anew@latest"
        "github.com/tomnomnom/waybackurls@latest"
        "github.com/Emoe/kxss@latest"
        "github.com/tomnomnom/gf@latest"
        "github.com/jaeles-project/gospider@latest"
        "github.com/lc/gau@latest"
        "github.com/003random/getJS@latest"
        "github.com/tomnomnom/unfurl@latest"
    )

    echo_info "Installing tools..."

    # Iterate over each tool and install it
    for tool in "${TOOLS[@]}"; do
        # Split the tool entry into repository path, executable name, and tool name
        IFS=' ' read -r repo exec_name name <<< "$tool"
        
        # Check if the tool is already installed
        if command -v "$exec_name" >/dev/null 2>&1; then
            echo_info "$name is already installed. Skipping installation."
            continue
        fi

        echo_info "Installing $name from $repo..."

        # Attempt to install the tool
        if go install "$repo"; then
            echo_info "$name installed successfully."
        else
            echo_error "Failed to install $name. Please check the repository path and your Go setup."
        fi
    done

    echo_info "All Go-based tools have been installed successfully."
}

# Check the tools installation.
verify_tool_installation() {
    local tool_name=$1
    local exec_name=$(echo "$tool_name" | tr '[:upper:]' '[:lower:]')

    if command -v "$exec_name" >/dev/null 2>&1; then
        echo_info "$tool_name is available in PATH."
    else
        echo_error "$tool_name is NOT available in PATH. Please check your installation."
    fi
}

# Function to verify all installed tools
verify_all_tools() {
    echo_info "Verifying installations of all Go-based tools..."

    # List of tools with their executable names: "ToolName ExecutableName"
    VERIFICATION_TOOLS=(
        "Nuclei nuclei"
        "Subfinder subfinder"
        "Httpx httpx"
        "Interactsh-Client interactsh-client"
        "Dalfox dalfox"
        "FFUF ffuf"
        "QsReplace qsreplace"
        "Anew anew"
        "WaybackURLs waybackurls"
        "Kxss kxss"
        "Gf gf"
        "Gospider gospider"
        "Gau gau"
        "GetJS getJS"
        "Unfurl unfurl"
    )

    for tool in "${VERIFICATION_TOOLS[@]}"; do
        IFS=' ' read -r name exec_name <<< "$tool"
        verify_tool_installation "$name" "$exec_name"
    done

    echo_info "Verification of Go-based tools completed."
}

# Main Execution Flow

# Step 1: Fetch the latest Go version
fetch_latest_go_version

# Step 2: Check Go installation and version
check_go

# Step 3: Exit with appropriate status code based on GO_INSTALLED
if [ "$GO_INSTALLED" = true ]; then
    echo_info "Go is up-to-date."
else
    echo_info "Go is not installed or is outdated."
    install_go
fi

# Step 4: Checking the GoPATH
if [ -z "$GOPATH" ]; then
    echo_info "GOPATH is not set. Setting GOPATH to \$HOME/go..."
    export GOPATH=$HOME/go
    echo 'export GOPATH=$HOME/go' >> ~/.bashrc
fi

# Ensure that GOPATH/bin is in the PATH
ensure_gopath_bin_in_path

# Install the Go-based tools
install_tools

# Verify installations
verify_all_tools