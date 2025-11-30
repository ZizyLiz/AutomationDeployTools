#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Add gohttpx alias
add_custom_alias(){
    echo "# Custom Aliases" >> ~/.bashrc
}

add_gohttpx() {
    if ! grep -q "alias gohttpx='~/go/bin/httpx'" ~/.bashrc; then
        echo_info "Adding gohttpx alias to .bashrc"
        echo "alias gohttpx='~/go/bin/httpx'" >> ~/.bashrc
        source ~/.bashrc
        echo_success "Added gohttpx alias"
    else
        echo_success "gohttpx alias already added"
        source ~/.bashrc
    fi
}

# Function to print informational messages
echo_info() {
    echo -e "\e[34m[INFO]\e[0m $1"
}

echo_success() {
    echo -e "\e[32m[SUCCESS]\e[0m $1"
}

# Function to print error messages
echo_error() {
    echo -e "\e[31m[ERROR]\e[0m $1"
}

# Function to install jq if not present
install_jq() {
    echo_info "Installing 'jq'"
    sudo apt update -y
    sudo apt install -y jq
}

# Function to install curl if not present
install_curl() {
    echo_info "Installing 'curl'"
    sudo apt update -y
    sudo apt install -y curl
}

install_python3() {
    echo_info "Installing 'python3'"
    sudo apt update -y
    sudo apt install -y python3-full
}

install_pipx() {
    echo_info "Installing 'pipx'"
    sudo apt update -y
    sudo apt install -y pipx
}

# Function to install wget if not present
install_wget() {
    echo_info "Installing 'wget'"
    sudo apt update -y
    sudo apt install -y wget
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

# Function to check Go installation and the version
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

    # Define Go version and the Download URL
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
        source ~/.bashrc
        echo_info "Added \$GOPATH/bin to PATH"
    else
        echo_success "\$GOPATH/bin is already in your PATH."
    fi
}

ensure_pip_in_path(){
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo "Adding \$HOME/.local/bin to PATH in ~/.bashrc..."
        echo 'export PATH=$PATH:$HOME/.local/bin' >> ~/.bashrc
        export PATH=$PATH:$HOME/.local/bin
        source ~/.bashrc
        echo_info "Added \$HOME/.local/bin to PATH"
    else
        echo_success "\$HOME/.local/bin is already in your PATH."
    fi
}

# Function to install the tools
install_tools_go() {
    echo_info "Starting installation of Go-based tools..."

    # Repository of the `Tools`
    REPO=(
        "github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest"
        "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
        "github.com/projectdiscovery/httpx/cmd/httpx@latest"
        "github.com/projectdiscovery/interactsh/cmd/interactsh-client@latest"
        "github.com/hahwul/dalfox/v2@latest"
        "github.com/ffuf/ffuf@latest"
        "github.com/tomnomnom/anew@latest"
        "github.com/tomnomnom/waybackurls@latest"
        "github.com/Emoe/kxss@latest"
        "github.com/jaeles-project/gospider@latest"
        "github.com/lc/gau@latest"
        "github.com/003random/getJS@latest"
        "github.com/tomnomnom/unfurl@latest"
        "github.com/projectdiscovery/httpx/cmd/httpx@latest"
        "github.com/d3mondev/cidrex@latest"
        "github.com/projectdiscovery/katana/cmd/katana@latest"
    )

    VERIFICATION_TOOLS=(
    "Nuclei nuclei"
    "Subfinder subfinder"
    "Httpx httpx"
    "Interactsh-Client interactsh-client"
    "Dalfox dalfox"
    "FFUF ffuf"
    "Anew anew"
    "WaybackURLs waybackurls"
    "Kxss kxss"
    "Gospider gospider"
    "Gau gau"
    "GetJS getJS"
    "Unfurl unfurl"
    "HttpX httpx"
    "Cidrex cidrex"
    "Katana katana"
    )
    echo_info "Installing tools..."

    # Check the installation of the `Tools`
    for verification_tool in "${VERIFICATION_TOOLS[@]}"; do
        IFS=' ' read -r name exec_name <<< "$verification_tool"

        # Find the matching repository path from the `REPO` array
        repo=""
        for tool in "${REPO[@]}"; do
            if [[ $tool == *"$exec_name"* ]]; then
                repo=$tool
                break
            fi
        done

        # If repo is not found, skip this tool installation
        if [ -z "$repo" ]; then
            echo_error "Repository path for $exec_name not found. Skipping..."
            continue
        fi

        # Check if the tool is already installed
        if command -v "$exec_name" >/dev/null 2>&1; then
            echo_info "$exec_name is already installed. Skipping installation."
            continue
        fi

        # Install the tool if not found
        echo_info "Installing $exec_name from $repo..."
        if go install "$repo"; then
            echo_success "$exec_name installed successfully."
        else
            echo_error "Failed to install $exec_name. Please check the repository path and your Go setup."
        fi
    done

    echo_info "All Go-based tools have been installed or verified."
}

install_tools_pipx() {
    echo_info "Starting installation of tools using Pipx..."

    install_python3
    install_pipx
    ensure_pip_in_path
    
    # List of tools with format: "Name|ExecutableName|InstallCommand|InjectCommand(optional)"
    # If no inject command is needed, leave it empty (e.g., "ToolName|executable|pipx install toolname|")
    VERIFICATION_TOOLS=(
        "Dirsearch|dirsearch|pipx install dirsearch|pipx inject dirsearch setuptools"
    )

    for verification_tool in "${VERIFICATION_TOOLS[@]}"; do
        IFS='|' read -r name exec_name install_command inject_command <<< "$verification_tool"
        
        if ! command -v "$exec_name" &>/dev/null; then
            echo_info "$name is not installed. Installing..."
            if eval "$install_command"; then
                echo_success "$name installed successfully."
                
                if [ -n "$inject_command" ]; then
                    echo_info "Injecting dependencies for $name..."
                    if eval "$inject_command"; then
                        echo_success "Dependencies injected successfully."
                    else
                        echo_error "Failed to inject dependencies for $name."
                    fi
                fi
            else
                echo_error "Failed to install $name."
            fi
        else
            echo_info "$name is already installed. If the tools throw any errors, consider to run $inject_command"
        fi
    done
    
    echo_info "Pipx tools installation completed."
}

# Fetch the latest Go version
fetch_latest_go_version

# Check Go installation and version
check_go

# Exit with appropriate status code based on GO_INSTALLED
if [ "$GO_INSTALLED" = true ]; then
    echo_info "Go is up-to-date."
else
    echo_info "Go is not installed or is outdated."
    install_go
fi

# Checking the GoPATH
if [ -z "$GOPATH" ]; then
    echo_info "GOPATH is not set. Setting GOPATH to \$HOME/go..."
    export GOPATH=$HOME/go
    echo 'export GOPATH=$HOME/go' >> ~/.bashrc
    source ~/.bashrc
fi

# Ensure that GOPATH/bin is in the PATH
ensure_gopath_bin_in_path

# Ensure that .local/bin is in the PATH
ensure_pip_in_path

# Install the Go-based tools
install_tools_go

install_tools_pipx
# Add alias to .bashrc to prevent collision between httpx (python and go)
add_gohttpx

echo -e "\e[32m[IMPORTANT!]\e[0m \e[1;32mrun 'source ~/.bashrc' to ensure the PATH is updated\e[0m"
