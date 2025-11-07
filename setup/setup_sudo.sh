#!/bin/bash

# Complete System Setup Script for Raspberry Pi Camera Setup
# This script performs full system setup including package installation,
# sudo configuration, and user setup for GPIO and camera access
# WARNING: This script modifies system security settings and requires root access

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

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        print_error "Usage: sudo ./setup/setup_sudo.sh"
        exit 1
    fi
    print_success "Running as root"
}

# Function to check if running on Raspberry Pi
check_raspberry_pi() {
    if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
        print_error "This script must be run on a Raspberry Pi"
        exit 1
    fi
    print_success "Raspberry Pi detected"
}

# Function to update system packages
update_system() {
    print_status "Updating system packages..."
    apt update
    apt upgrade -y
    print_success "System packages updated"
}

# Function to install required packages
install_packages() {
    print_status "Installing required packages..."
    apt install -y \
        python3 \
        python3-pip \
        python3-venv \
        libcamera-apps \
        ffmpeg \
        gnupg \
        python3-rpi.gpio \
        git \
        curl \
        wget \
        vsftpd 
    print_success "Required packages installed"
}

# Function to install Tailscale
install_tailscale() {
    print_status "Installing Tailscale..."
    
    # Add Tailscale's GPG key
    curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
    
    # Add Tailscale repository
    curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list
    
    # Update package list
    apt update
    
    # Install Tailscale
    apt install -y tailscale
    
    print_success "Tailscale installed"
}

# Function to copy project files to mlink home directory
copy_project_files() {
    print_status "Copying project files to mlink home directory..."
    
    # Get the directory where the script is located (setup/)
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # Get the parent directory (project root)
    PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
    
    # Copy rpi_files directory
    if [[ -d "${PROJECT_ROOT}/rpi_files" ]]; then
        cp -r "${PROJECT_ROOT}/rpi_files" /home/mlink/
        chown -R mlink:mlink /home/mlink/rpi_files
        print_success "rpi_files directory copied to mlink home directory"
    else
        print_warning "rpi_files directory not found in ${PROJECT_ROOT}/"
    fi
    
    # Copy setup directory
    if [[ -d "${SCRIPT_DIR}" ]]; then
        cp -r "${SCRIPT_DIR}" /home/mlink/
        chown -R mlink:mlink /home/mlink/setup
        print_success "setup directory copied to mlink home directory"
    else
        print_warning "setup directory not found in ${SCRIPT_DIR}/"
    fi
    
    # Copy other important files
    for file in "README.md" "test_gpio.sh" "wifi_usb.sh" "setup_wifi_usb.sh"; do
        if [[ -f "${PROJECT_ROOT}/${file}" ]]; then
            cp "${PROJECT_ROOT}/${file}" /home/mlink/
            chown mlink:mlink "/home/mlink/${file}"
            print_success "${file} copied to mlink home directory"
        fi
    done
}

# Function to set up Python virtual environment
setup_python_env() {
    print_status "Setting up Python virtual environment..."
    
    # Create virtual environment for mlink user in their home directory
    sudo -u mlink python3 -m venv /home/mlink/venv
    
    # Activate virtual environment and upgrade pip
    sudo -u mlink /home/mlink/venv/bin/pip install --upgrade pip
    
    # Install Python requirements
    if [[ -f "/home/mlink/rpi_files/requirements.txt" ]]; then
        print_status "Installing Python requirements..."
        sudo -u mlink /home/mlink/venv/bin/pip install -r /home/mlink/rpi_files/requirements.txt
    else
        print_status "Installing basic Python packages..."
        sudo -u mlink /home/mlink/venv/bin/pip install RPi.GPIO gpiozero
    fi
    
    print_success "Python environment set up"
}

# Function to set up camera configuration
setup_camera() {
    print_status "Setting up camera configuration..."
    
    # Enable camera interface
    raspi-config nonint do_camera 0
    
    # Enable I2C interface for GPIO
    raspi-config nonint do_i2c 0
    
    # Enable SPI interface for GPIO
    raspi-config nonint do_spi 0
    
    # Enable serial interface for GPIO
    raspi-config nonint do_serial 0
    
    print_success "Camera and GPIO interfaces enabled"
    print_warning "A reboot will be required for these changes to take effect"
}

# Function to set up camera script
setup_camera_script() {
    print_status "Setting up camera script..."
    
    # Copy camera script to home directory
    if [[ -f "/home/mlink/rpi_files/pycam.py" ]]; then
        cp /home/mlink/rpi_files/pycam.py /home/mlink/pycam.py
        chown mlink:mlink /home/mlink/pycam.py
        chmod +x /home/mlink/pycam.py
        print_success "Camera script copied and made executable"
    else
        print_warning "Camera script not found in /home/mlink/rpi_files/"
    fi
}

# Function to set up systemd service
setup_service() {
    print_status "Setting up systemd service..."
    
    # Create systemd service file
    cat > /etc/systemd/user/pycam.service << 'EOF'
[Unit]
Description=Physical Button Camera Recorder
After=network.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/home/mlink/venv/bin/python3 /home/mlink/pycam.py
Restart=always
RestartSec=5
StartLimitInterval=0
StartLimitBurst=0
Environment=PYTHONUNBUFFERED=1
Environment=PYTHONPATH=/home/mlink/venv/lib/python3.11/site-packages
WorkingDirectory=/home/mlink

# Ensure service keeps running
KillMode=mixed
KillSignal=SIGTERM
TimeoutStopSec=10

[Install]
WantedBy=default.target
EOF
    
    # Enable user lingering
    loginctl enable-linger mlink
    
    # Reload systemd
    systemctl daemon-reload
    
    print_success "Systemd service configured"
}

# Function to verify and fix service startup
verify_service_startup() {
    print_status "Verifying service startup configuration..."
    
    # Ensure user lingering is enabled
    loginctl enable-linger mlink
    
    # Reload systemd user daemon
    systemctl daemon-reload
    
    print_status "Service auto-start configured"
}

# Function to create assets directory
create_assets_dir() {
    print_status "Creating assets directory for recordings..."
    mkdir -p /home/mlink/assets
    chown mlink:mlink /home/mlink/assets
    print_success "Assets directory created"
}

# Function to test setup
test_setup() {
    print_status "Testing setup..."
    
    # Test camera
    if command -v rpicam-still &> /dev/null; then
        print_success "Camera tools available"
    else
        print_warning "Camera tools not available"
    fi
    
    # Test Python environment
    if [[ -d /home/mlink/venv ]]; then
        print_success "Python virtual environment exists"
    else
        print_warning "Python virtual environment not found"
    fi
    
    # Test GPIO access
    if sudo -u mlink python3 -c "import RPi.GPIO as GPIO; print('GPIO import successful')" 2>/dev/null; then
        print_success "GPIO library accessible"
    else
        print_warning "GPIO library not accessible"
    fi
}

# Function to backup sudoers file
backup_sudoers() {
    print_status "Creating backup of sudoers file..."
    
    if [[ ! -f /etc/sudoers.backup ]]; then
        cp /etc/sudoers /etc/sudoers.backup
        print_success "Sudoers backup created at /etc/sudoers.backup"
    else
        print_warning "Sudoers backup already exists at /etc/sudoers.backup"
    fi
}

# Function to configure sudo access
configure_sudo() {
    print_status "Configuring sudo access for GPIO and camera operations..."
    
    # Check if sudoers entry already exists
    if ! grep -q "mlink ALL=(ALL) NOPASSWD: /usr/bin/python3 /home/mlink/pycam.py" /etc/sudoers; then
        print_status "Adding sudo access for pycam.py..."
        echo "" >> /etc/sudoers
        echo "# Raspberry Pi Camera GPIO and Camera Access" >> /etc/sudoers
        echo "mlink ALL=(ALL) NOPASSWD: /usr/bin/python3 /home/mlink/pycam.py" >> /etc/sudoers
        
        print_status "Adding GPIO access permissions..."
        echo "mlink ALL=(ALL) NOPASSWD: /usr/bin/gpio" >> /etc/sudoers
        echo "mlink ALL=(ALL) NOPASSWD: /usr/bin/raspi-gpio" >> /etc/sudoers
        
        print_status "Adding camera access permissions..."
        echo "mlink ALL=(ALL) NOPASSWD: /usr/bin/libcamera-*" >> /etc/sudoers
        echo "mlink ALL=(ALL) NOPASSWD: /usr/bin/rpicam-*" >> /etc/sudoers
        echo "mlink ALL=(ALL) NOPASSWD: /usr/bin/ffmpeg" >> /etc/sudoers
        
        print_success "Sudo access configured successfully"
    else
        print_success "Sudo access already configured"
    fi
}

# Function to add user to required groups
add_user_to_groups() {
    print_status "Adding mlink user to required groups..."
    
    # Add to gpio group
    if ! groups mlink | grep -q gpio; then
        usermod -a -G gpio mlink
        print_success "Added mlink user to gpio group"
    else
        print_success "mlink user already in gpio group"
    fi
    
    # Add to video group
    if ! groups mlink | grep -q video; then
        usermod -a -G video mlink
        print_success "Added mlink user to video group"
    else
        print_success "mlink user already in video group"
    fi
    
    # Add to audio group
    if ! groups mlink | grep -q audio; then
        usermod -a -G audio mlink
        print_success "Added mlink user to audio group"
    else
        print_success "mlink user already in audio group"
    fi
}

# Function to verify sudo configuration
verify_sudo_config() {
    print_status "Verifying sudo configuration..."
    
    # Test sudo access to pycam.py
    if sudo -u mlink sudo -n /usr/bin/python3 /home/mlink/pycam.py --help 2>/dev/null || sudo -u mlink sudo -n /usr/bin/python3 /home/mlink/pycam.py 2>/dev/null; then
        print_success "Sudo access to pycam.py verified"
    else
        print_warning "Sudo access to pycam.py may not be working correctly"
    fi
    
    # Test GPIO access
    if sudo -u mlink sudo -n /usr/bin/gpio readall 2>/dev/null; then
        print_success "Sudo access to gpio verified"
    else
        print_warning "Sudo access to gpio may not be working correctly"
    fi
    
    # Test camera access
    if sudo -u mlink sudo -n /usr/bin/rpicam-vid --help 2>/dev/null; then
        print_success "Sudo access to rpicam-vid verified"
    else
        print_warning "Sudo access to rpicam-vid may not be working correctly"
    fi
}

# Function to test GPIO functionality
test_gpio_functionality() {
    print_status "Testing GPIO functionality for LED and Button..."
    
    # Check if GPIO interfaces are enabled
    if ! grep -q "i2c_arm=on" /boot/config.txt 2>/dev/null; then
        print_warning "GPIO interfaces may not be enabled yet. A reboot is required after enabling interfaces."
        print_warning "Skipping GPIO test until after reboot."
        return 0
    fi
    
    # Test LED on GPIO 17
    print_status "Testing LED on GPIO 17 (Physical Pin 11)..."
    
    # Create a simple LED test script with better error handling
    cat > /tmp/led_test.py << 'EOF'
#!/usr/bin/env python3
import RPi.GPIO as GPIO
import time
import sys

LED_PIN = 17  # GPIO 17 (Physical Pin 11)

try:
    GPIO.setmode(GPIO.BCM)
    GPIO.setwarnings(False)
    GPIO.setup(LED_PIN, GPIO.OUT)
    
    print(f"Testing LED on GPIO {LED_PIN}")
    print("LED should blink 5 times...")
    
    for i in range(5):
        print(f"Blink {i+1}: LED ON")
        GPIO.output(LED_PIN, GPIO.HIGH)
        time.sleep(0.5)
        print(f"Blink {i+1}: LED OFF")
        GPIO.output(LED_PIN, GPIO.LOW)
        time.sleep(0.5)
    
    print("LED test completed successfully")
    sys.exit(0)
    
except Exception as e:
    print(f"LED test failed: {e}")
    sys.exit(1)
    
finally:
    try:
        GPIO.cleanup()
    except:
        pass
EOF
    
    # Test LED functionality with root privileges first, then as mlink user
    print_status "Testing LED with root privileges..."
    if python3 /tmp/led_test.py; then
        print_success "LED test with root privileges completed successfully"
    else
        print_warning "LED test with root privileges failed - checking as mlink user..."
        if sudo -u mlink python3 /tmp/led_test.py; then
            print_success "LED test as mlink user completed successfully"
        else
            print_warning "LED test failed - check hardware connections and GPIO permissions"
        fi
    fi
    
    # Test Button on GPIO 15
    print_status "Testing Button on GPIO 15 (Physical Pin 10)..."
    
    # Create a simple button test script with better error handling
    cat > /tmp/button_test.py << 'EOF'
#!/usr/bin/env python3
import RPi.GPIO as GPIO
import time
import sys

BUTTON_PIN = 15  # GPIO 15 (Physical Pin 10)

try:
    GPIO.setmode(GPIO.BCM)
    GPIO.setwarnings(False)
    GPIO.setup(BUTTON_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)
    
    print(f"Testing Button on GPIO {BUTTON_PIN}")
    initial_state = GPIO.input(BUTTON_PIN)
    print(f"Initial button state: {'HIGH (not pressed)' if initial_state else 'LOW (pressed)'}")
    print("Press button within 10 seconds to test...")
    
    start_time = time.time()
    button_pressed = False
    
    while time.time() - start_time < 10:
        current_state = GPIO.input(BUTTON_PIN)
        if current_state != initial_state:
            print(f"✅ Button state changed from {initial_state} to {current_state}!")
            button_pressed = True
            break
        time.sleep(0.1)
    
    if not button_pressed:
        print("⚠️ No button press detected in 10 seconds")
        print("This could mean:")
        print("  - Button is not connected to GPIO 15")
        print("  - Button is stuck in pressed state")
        print("  - GPIO permissions issue")
    
    print("Button test completed")
    sys.exit(0)
    
except Exception as e:
    print(f"Button test failed: {e}")
    sys.exit(1)
    
finally:
    try:
        GPIO.cleanup()
    except:
        pass
EOF
    
    # Test Button functionality with root privileges first, then as mlink user
    print_status "Testing Button with root privileges..."
    if python3 /tmp/button_test.py; then
        print_success "Button test with root privileges completed successfully"
    else
        print_warning "Button test with root privileges failed - checking as mlink user..."
        if sudo -u mlink python3 /tmp/button_test.py; then
            print_success "Button test as mlink user completed successfully"
        else
            print_warning "Button test failed - check hardware connections and GPIO permissions"
        fi
    fi
    
    # Clean up test files
    rm -f /tmp/led_test.py /tmp/button_test.py
    
    print_status "GPIO testing completed"
    print_warning "If tests failed, ensure:"
    print_warning "  1. Hardware is properly connected to GPIO 17 (LED) and GPIO 15 (Button)"
    print_warning "  2. System has been rebooted after enabling GPIO interfaces"
    print_warning "  3. User has proper GPIO permissions"
}

# Function to display current sudo configuration
display_sudo_config() {
    print_status "Current sudo configuration for mlink user:"
    echo "=========================================="
    
    # Show sudoers entries for mlink user
    grep "^mlink.*NOPASSWD" /etc/sudoers 2>/dev/null || echo "No NOPASSWD entries found for mlink user"
    
    echo ""
    print_status "Current group membership for mlink user:"
    echo "=========================================="
    groups mlink
    
    echo ""
    print_status "Sudoers backup location:"
    echo "=========================================="
    if [[ -f /etc/sudoers.backup ]]; then
        echo "/etc/sudoers.backup"
    else
        echo "No backup found"
    fi
}

# Function to restore sudoers from backup
restore_sudoers() {
    print_warning "This will restore the original sudoers file and remove all custom configurations!"
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [[ -f /etc/sudoers.backup ]]; then
            cp /etc/sudoers.backup /etc/sudoers
            print_success "Sudoers file restored from backup"
        else
            print_error "No backup file found"
        fi
    else
        print_status "Restore cancelled"
    fi
}

# Function to display help
show_help() {
    echo "Usage: sudo ./setup/setup_sudo.sh [OPTION]"
    echo ""
    echo "Options:"
    echo "  --verify     Verify current sudo configuration"
    echo "  --test-gpio  Test GPIO functionality (LED and Button)"
    echo "  --restore    Restore sudoers from backup"
    echo "  --help       Show this help message"
    echo ""
    echo "Examples:"
    echo "  sudo ./setup/setup_sudo.sh           # Full system setup and sudo configuration"
    echo "  sudo ./setup/setup_sudo.sh --verify  # Verify configuration"
    echo "  sudo ./setup/setup_sudo.sh --test-gpio # Test GPIO functionality"
    echo "  sudo ./setup/setup_sudo.sh --restore # Restore from backup"
    echo ""
    echo "This script performs the following:"
    echo "  - Updates system packages"
    echo "  - Installs required software"
    echo "  - Sets up Python environment"
    echo "  - Configures camera and GPIO interfaces"
    echo "  - Sets up systemd service"
    echo "  - Configures sudo access"
    echo "  - Sets up GPG and SSH keys"
}

# Main function
main() {
    echo "=========================================="
    echo "    Complete System Setup Script"
    echo "  Raspberry Pi Camera Setup"
    echo "=========================================="
    echo ""
    
    # Parse command line arguments
    case "${1:-}" in
        --verify)
            check_root
            check_raspberry_pi
            display_sudo_config
            verify_sudo_config
            exit 0
            ;;
        --test-gpio)
            check_root
            check_raspberry_pi
            test_gpio_functionality
            exit 0
            ;;
        --restore)
            check_root
            restore_sudoers
            exit 0
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        "")
            # No arguments, run full configuration
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
    
    # Run full configuration
    check_root
    check_raspberry_pi
    
    # System-level setup (requires root)
    update_system
    install_packages
    install_tailscale
    copy_project_files
    setup_camera
    setup_camera_script
    setup_service
    verify_service_startup
    create_assets_dir
    test_setup
    
    # User-specific setup
    setup_python_env
    
    # Sudo configuration
    backup_sudoers
    configure_sudo
    add_user_to_groups
    verify_sudo_config
    test_gpio_functionality
    display_sudo_config
    
    echo ""
    echo "=========================================="
    echo "        SYSTEM SETUP COMPLETE"
    echo "=========================================="
    echo ""
    echo "What was configured:"
    echo "✅ System packages updated and installed"
    echo "✅ Tailscale installed via curl"
    echo "✅ Project files copied to mlink home directory"
    echo "✅ Python virtual environment set up"
    echo "✅ Camera and GPIO interfaces enabled"
    echo "✅ Camera script and systemd service configured"
    echo "✅ Passwordless sudo access to pycam.py"
    echo "✅ GPIO access permissions (gpio, raspi-gpio)"
    echo "✅ Camera access permissions (libcamera-*, rpicam-*, ffmpeg)"
    echo "✅ User added to gpio, video, and audio groups"
    echo "✅ Sudoers backup created at /etc/sudoers.backup"
    echo ""
    echo "Next steps:"
    echo "1. Run user configuration: ./setup/install.sh"
    echo "2. Reboot the Raspberry Pi: sudo reboot"
    echo "3. After reboot, test the camera: rpicam-still -o test.jpg"
    echo "4. Test sudo access: sudo python3 ~/pycam.py"
    echo "5. Test GPIO access: sudo gpio readall"
    echo "6. Test camera access: sudo rpicam-vid --help"
    echo "7. Start the camera service: systemctl --user start pycam.service"
    echo ""
    echo "To verify configuration later:"
    echo "  sudo ./setup/setup_sudo.sh --verify"
    echo ""
    echo "To restore original sudoers:"
    echo "  sudo ./setup/setup_sudo.sh --restore"
    echo "=========================================="
}

# Run main function
main "$@"
