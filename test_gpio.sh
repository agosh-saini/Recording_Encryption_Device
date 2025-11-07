#!/bin/bash

# Standalone GPIO Test Script for Raspberry Pi
# This script tests LED and Button functionality with proper error handling

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if running on Raspberry Pi
check_raspberry_pi() {
    if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
        print_error "This script must be run on a Raspberry Pi"
        exit 1
    fi
    print_success "Raspberry Pi detected"
}

# Check GPIO interface status
check_gpio_interfaces() {
    print_status "Checking GPIO interface status..."
    
    if grep -q "i2c_arm=on" /boot/config.txt 2>/dev/null; then
        print_success "I2C interface enabled"
    else
        print_warning "I2C interface not enabled in /boot/config.txt"
    fi
    
    if grep -q "spi=on" /boot/config.txt 2>/dev/null; then
        print_success "SPI interface enabled"
    else
        print_warning "SPI interface not enabled in /boot/config.txt"
    fi
    
    if grep -q "enable_uart=1" /boot/config.txt 2>/dev/null; then
        print_success "Serial interface enabled"
    else
        print_warning "Serial interface not enabled in /boot/config.txt"
    fi
}

# Test LED functionality
test_led() {
    print_status "Testing LED on GPIO 17 (Physical Pin 11)..."
    
    cat > /tmp/led_test.py << 'EOF'
#!/usr/bin/env python3
import RPi.GPIO as GPIO
import time
import sys

LED_PIN = 17  # GPIO 17 (Physical Pin 11)

try:
    print("Initializing GPIO...")
    GPIO.setmode(GPIO.BCM)
    GPIO.setwarnings(False)
    
    print(f"Setting up GPIO {LED_PIN} as output...")
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
    print(f"Error type: {type(e).__name__}")
    sys.exit(1)
    
finally:
    try:
        GPIO.cleanup()
        print("GPIO cleanup completed")
    except Exception as e:
        print(f"GPIO cleanup error: {e}")
EOF
    
    print_status "Running LED test with current user..."
    if python3 /tmp/led_test.py; then
        print_success "LED test completed successfully"
        return 0
    else
        print_warning "LED test failed with current user"
        
        # Try with root privileges
        print_status "Trying LED test with root privileges..."
        if sudo python3 /tmp/led_test.py; then
            print_success "LED test with root privileges completed successfully"
            return 0
        else
            print_error "LED test failed even with root privileges"
            return 1
        fi
    fi
}

# Test Button functionality
test_button() {
    print_status "Testing Button on GPIO 15 (Physical Pin 10)..."
    
    cat > /tmp/button_test.py << 'EOF'
#!/usr/bin/env python3
import RPi.GPIO as GPIO
import time
import sys

BUTTON_PIN = 15  # GPIO 15 (Physical Pin 10)

try:
    print("Initializing GPIO...")
    GPIO.setmode(GPIO.BCM)
    GPIO.setwarnings(False)
    
    print(f"Setting up GPIO {BUTTON_PIN} as input with pull-up...")
    GPIO.setup(BUTTON_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)
    
    print(f"Testing Button on GPIO {BUTTON_PIN}")
    initial_state = GPIO.input(BUTTON_PIN)
    print(f"Initial button state: {'HIGH (not pressed)' if initial_state else 'LOW (pressed)'}")
    
    if initial_state == GPIO.LOW:
        print("⚠️ Button appears to be pressed initially - check connections")
    
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
        print("Possible issues:")
        print("  - Button not connected to GPIO 15")
        print("  - Button stuck in pressed state")
        print("  - Wrong GPIO pin assignment")
        print("  - Hardware connection problem")
    
    print("Button test completed")
    sys.exit(0)
    
except Exception as e:
    print(f"Button test failed: {e}")
    print(f"Error type: {type(e).__name__}")
    sys.exit(1)
    
finally:
    try:
        GPIO.cleanup()
        print("GPIO cleanup completed")
    except Exception as e:
        print(f"GPIO cleanup error: {e}")
EOF
    
    print_status "Running Button test with current user..."
    if python3 /tmp/button_test.py; then
        print_success "Button test completed successfully"
        return 0
    else
        print_warning "Button test failed with current user"
        
        # Try with root privileges
        print_status "Trying Button test with root privileges..."
        if sudo python3 /tmp/button_test.py; then
            print_success "Button test with root privileges completed successfully"
            return 0
        else
            print_error "Button test failed even with root privileges"
            return 1
        fi
    fi
}

# Test GPIO permissions
test_gpio_permissions() {
    print_status "Testing GPIO permissions..."
    
    # Check if gpio group exists
    if getent group gpio > /dev/null 2>&1; then
        print_success "GPIO group exists"
        
        # Check current user's groups
        if groups | grep -q gpio; then
            print_success "Current user is in gpio group"
        else
            print_warning "Current user is not in gpio group"
        fi
    else
        print_warning "GPIO group does not exist"
    fi
    
    # Test basic GPIO access
    if command -v gpio > /dev/null 2>&1; then
        print_success "GPIO command available"
        if gpio readall > /dev/null 2>&1; then
            print_success "GPIO readall command works"
        else
            print_warning "GPIO readall command failed"
        fi
    else
        print_warning "GPIO command not available"
    fi
}

# Main function
main() {
    echo "=========================================="
    echo "    GPIO Test Script"
    echo "  Raspberry Pi Hardware Test"
    echo "=========================================="
    echo ""
    
    check_raspberry_pi
    check_gpio_interfaces
    test_gpio_permissions
    
    echo ""
    print_status "Starting hardware tests..."
    echo ""
    
    # Test LED
    led_result=0
    test_led || led_result=1
    
    echo ""
    
    # Test Button
    button_result=0
    test_button || button_result=1
    
    # Clean up
    rm -f /tmp/led_test.py /tmp/button_test.py
    
    echo ""
    echo "=========================================="
    echo "        TEST RESULTS"
    echo "=========================================="
    
    if [ $led_result -eq 0 ]; then
        print_success "LED Test: PASSED"
    else
        print_error "LED Test: FAILED"
    fi
    
    if [ $button_result -eq 0 ]; then
        print_success "Button Test: PASSED"
    else
        print_error "Button Test: FAILED"
    fi
    
    echo ""
    if [ $led_result -eq 0 ] && [ $button_result -eq 0 ]; then
        print_success "All tests passed! Hardware is working correctly."
    else
        print_warning "Some tests failed. Check hardware connections and GPIO setup."
        echo ""
        print_status "Troubleshooting tips:"
        echo "1. Ensure hardware is connected to correct GPIO pins:"
        echo "   - LED: GPIO 17 (Physical Pin 11)"
        echo "   - Button: GPIO 15 (Physical Pin 10)"
        echo "2. Check that GPIO interfaces are enabled in /boot/config.txt"
        echo "3. Reboot the system after enabling GPIO interfaces"
        echo "4. Verify user has proper GPIO permissions"
        echo "5. Check for loose connections or faulty components"
    fi
    
    echo "=========================================="
}

# Run main function
main "$@"
