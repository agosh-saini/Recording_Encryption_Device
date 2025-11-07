#!/bin/bash

# Raspberry Pi Physical Button Camera Setup Install Script
# This script automates the setup process described in the README

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if running on Raspberry Pi
check_raspberry_pi() {
    if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
        print_error "This script must be run on a Raspberry Pi"
        exit 1
    fi
    print_success "Raspberry Pi detected"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root. Please run as mlink user."
        exit 1
    fi
    print_success "Running as mlink user"
}

# Function to check if setup_sudo.sh has been run
check_setup_sudo() {
    if [[ ! -f "/etc/systemd/user/pycam.service" ]]; then
        print_error "System setup has not been completed yet!"
        print_status "Please run the system setup script first:"
        echo "  sudo ./setup/setup_sudo.sh"
        echo ""
        print_status "This script will:"
        echo "  - Install required packages"
        echo "  - Set up Python environment"
        echo "  - Configure camera and GPIO interfaces"
        echo "  - Set up systemd service"
        echo "  - Configure sudo access"
        echo "  - Set up GPG and SSH keys"
        echo ""
        exit 1
    fi
    print_success "System setup completed - proceeding with user configuration"
}

# Function to set up camera interface
setup_camera() {
    print_status "Checking camera interface configuration..."
    
    # Check if camera interface is already enabled
    if grep -q "start_x=1" /boot/firmware/config.txt; then
        print_success "Camera interface already enabled"
    else
        print_warning "Camera interface not enabled"
        print_status "Camera interface should be enabled by the system setup script"
        print_status "If not enabled, please run: sudo ./setup/setup_sudo.sh"
    fi
}

# Function to copy camera script
setup_camera_script() {
    print_status "Checking camera script..."
    
    if [[ -f "~/pycam.py" ]]; then
        print_success "Camera script already exists in home directory"
    elif [[ -f "../rpi_files/pycam.py" ]]; then
        cp ../rpi_files/pycam.py ~/pycam.py
        chmod +x ~/pycam.py
        print_success "Camera script copied and made executable"
    else
        print_warning "Camera script not found in ../rpi_files/"
        print_status "Script should be copied by the system setup script"
        print_status "If not found, please run: sudo ./setup/setup_sudo.sh"
    fi
}

# Function to set up systemd service
setup_service() {
    print_status "Checking systemd service configuration..."
    
    # Check if service file already exists
    if [[ -f "/etc/systemd/user/pycam.service" ]]; then
        print_success "Systemd service already configured"
    else
        print_warning "Systemd service not configured"
        print_status "Service should be configured by the system setup script"
        print_status "If not configured, please run: sudo ./setup/setup_sudo.sh"
        return
    fi
    
    # Create service directory for user
    mkdir -p ~/.config/systemd/user/
    
    # Reload systemd
    systemctl --user daemon-reload
    
    # Enable service
    systemctl --user enable pycam.service
    
    print_success "Systemd service enabled for user"
    
    # Show service status
    print_status "Service status:"
    systemctl --user status pycam.service --no-pager || true
    
    print_status "Service will start automatically on boot and restart if it crashes"
}

# Function to verify and fix service startup
verify_service_startup() {
    print_status "Verifying service startup configuration..."
    
    # Reload systemd user daemon
    systemctl --user daemon-reload
    
    # Enable the service
    systemctl --user enable pycam.service
    
    # Try to start the service to test it
    print_status "Testing service startup..."
    if systemctl --user start pycam.service; then
        print_success "Service started successfully"
        sleep 2
        systemctl --user stop pycam.service
        print_success "Service stopped successfully - startup test passed"
    else
        print_warning "Service failed to start - checking logs..."
        journalctl --user -u pycam.service --no-pager -n 10 || true
        
        # Try to fix common issues
        print_status "Attempting to fix service issues..."
        systemctl --user daemon-reload
        systemctl --user reset-failed pycam.service
    fi
    
    print_status "Service auto-start configured"
}

# Function to show service management commands
show_service_commands() {
    echo ""
    print_status "Service Management Commands:"
    echo "=================================="
    echo "Start service:        systemctl --user start pycam.service"
    echo "Stop service:         systemctl --user stop pycam.service"
    echo "Restart service:      systemctl --user restart pycam.service"
    echo "Check status:         systemctl --user status pycam.service"
    echo "View logs:            journalctl --user -u pycam.service -f"
    echo "Enable auto-start:    systemctl --user enable pycam.service"
    echo "Disable auto-start:   systemctl --user disable pycam.service"
    echo "=================================="
}

# Function to set up user permissions
setup_user_permissions() {
    print_status "Checking user permissions for GPIO and camera access..."
    
    # Check if user is in required groups
    if groups | grep -q gpio; then
        print_success "User already in gpio group"
    else
        print_warning "User not in gpio group"
        print_status "User should be added to gpio group by the system setup script"
        print_status "If not added, please run: sudo ./setup/setup_sudo.sh"
    fi
    
    if groups | grep -q video; then
        print_success "User already in video group"
    else
        print_warning "User not in video group"
        print_status "User should be added to video group by the system setup script"
        print_status "If not added, please run: sudo ./setup/setup_sudo.sh"
    fi
    
    # Create assets directory with proper ownership
    mkdir -p ~/assets
    print_success "Assets directory ready"
    
    print_warning "You may need to log out and back in for group changes to take effect"
}

# Function to set up GPG keys
setup_gpg_keys() {
    print_status "Setting up GPG encryption keys..."
    
    # Check if public key exists
    if [[ -f "Key_Folder/public.asc" ]]; then
        cp Key_Folder/public.asc ~/mlink_public.asc
        print_success "Public key copied to home directory"
        
        # Import the key into GnuPG
        gpg --import ~/mlink_public.asc
        
        # Get the key ID
        KEY_ID=$(gpg --list-keys --with-colons | grep "mlink@trymlink.com" | cut -d: -f5)
        
        if [[ -n "$KEY_ID" ]]; then
            # Trust the key
            echo -e "trust\n5\ny\nquit" | gpg --command-fd 0 --edit-key "$KEY_ID"
            print_success "GPG key imported and trusted"
        else
            print_warning "Could not find mlink@trymlink.com key for trust setup"
        fi
    else
        print_warning "Public key file not found in Key_Folder/"
        print_status "GPG key should be set up by the system setup script"
        print_status "If not found, please run: sudo ./setup/setup_sudo.sh"
    fi
}

# Function to set up SSH keys
setup_ssh_keys() {
    print_status "Setting up SSH keys..."
    
    # Create .ssh directory if it doesn't exist
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    
    # Add public key to authorized_keys for passwordless login FROM laptop
    if [[ -f "Key_Folder/mlink_key.pub" ]]; then
        # Add public key to authorized_keys for passwordless login FROM laptop
        if [[ ! -f ~/.ssh/authorized_keys ]] || ! grep -q "$(cat Key_Folder/mlink_key.pub)" ~/.ssh/authorized_keys; then
            cat Key_Folder/mlink_key.pub >> ~/.ssh/authorized_keys
            chmod 600 ~/.ssh/authorized_keys
            print_success "Public key added to authorized_keys for passwordless login from laptop"
        else
            print_success "Public key already in authorized_keys"
        fi
    else
        print_warning "Public key file not found in Key_Folder/"
        print_status "SSH key should be set up by the system setup script"
        print_status "If not found, please run: sudo ./setup/setup_sudo.sh"
    fi
}

# Function to create assets directory
create_assets_dir() {
    print_status "Checking assets directory..."
    if [[ -d ~/assets ]]; then
        print_success "Assets directory already exists"
    else
        mkdir -p ~/assets
        print_success "Assets directory created"
    fi
}

# Function to test setup
test_setup() {
    print_status "Testing setup..."
    
    # Test camera
    if command -v rpicam-still &> /dev/null; then
        print_success "Camera tools available"
    else
        print_warning "Camera tools not available"
        print_status "Camera tools should be installed by the system setup script"
        print_status "If not available, please run: sudo ./setup/setup_sudo.sh"
    fi
    
    # Test Python environment
    if [[ -d ~/venv ]]; then
        print_success "Python virtual environment exists"
    else
        print_warning "Python virtual environment not found"
        print_status "Python environment should be set up by the system setup script"
        print_status "If not found, please run: sudo ./setup/setup_sudo.sh"
    fi
    
    # Test GPIO access
    if python3 -c "import RPi.GPIO as GPIO; print('GPIO import successful')" 2>/dev/null; then
        print_success "GPIO library accessible"
    else
        print_warning "GPIO library not accessible"
        print_status "GPIO library should be installed by the system setup script"
        print_status "If not accessible, please run: sudo ./setup/setup_sudo.sh"
    fi
}

# Function to display next steps
display_next_steps() {
    echo ""
    echo "=========================================="
    echo "           INSTALLATION COMPLETE"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "1. Log out and log back in for group permissions to take effect:"
    echo "   exit"
    echo "   ssh mlink@<PI_IP>"
    echo ""
    echo "2. Reboot the Raspberry Pi:"
    echo "   sudo reboot"
    echo ""
    echo "3. After reboot, test the camera:"
    echo "   rpicam-still -o test.jpg"
    echo ""
    echo "4. Test the GPIO script:"
    echo "   sudo ./test_gpio.sh"
    echo ""
    echo "5. Start the camera service:"
    echo "   systemctl --user start pycam.service"
    echo ""
    echo "6. Check service status:"
    echo "   systemctl --user status pycam.service"
    echo ""
    echo "7. View service logs:"
    echo "   journalctl --user -u pycam.service -f"
    echo ""
    echo "For troubleshooting, see the README.md file"
    echo "=========================================="
}

# Main installation function
main() {
    echo "=========================================="
    echo "  Raspberry Pi Camera Setup Installer"
    echo "=========================================="
    echo ""
    
    # Check prerequisites
    check_raspberry_pi
    check_root
    check_setup_sudo
    
    # Run user-level installation steps
    setup_camera
    setup_camera_script
    setup_service
    setup_user_permissions
    verify_service_startup
    setup_gpg_keys
    setup_ssh_keys
    create_assets_dir
    test_setup
    
    # Display completion message
    display_next_steps
    
    # Show service management commands
    show_service_commands
}

# Run main function
main "$@"
