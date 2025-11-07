# Recording Encryption Device

A secure, open-source hardware and software solution for encrypted video recording on Raspberry Pi devices. This project enables physical button-controlled video recording with real-time encryption, LED status indicators, and automated systemd service management.

## Description

The Recording Encryption Device is a complete system for creating a secure, button-operated video recording device using a Raspberry Pi Zero 2W. It features:

- **Physical Button Control**: Start/stop recording with a simple button press
- **Real-time Encryption**: Videos are encrypted using GPG public-key cryptography
- **LED Status Indicators**: Visual feedback for recording state, encryption, and errors
- **Automated Setup**: Two-script installation process for easy deployment
- **Systemd Integration**: Automatic startup and service management
- **Hardware Design**: Includes 3D CAD files for custom body camera enclosure

Perfect for security-conscious applications requiring encrypted video capture with physical control.

## Features

- 🎥 **Video Recording**: High-quality 1080p video capture at 10fps
- 🔐 **GPG Encryption**: Public-key encryption for secure video storage
- 🔘 **Physical Button Interface**: Simple GPIO-based button control
- 💡 **LED Status Indicators**: Visual feedback for all system states
- ⚙️ **Automated Setup**: Streamlined installation scripts
- 🔄 **Real-time Processing**: Simultaneous recording, encoding, and encryption
- 📦 **3D Printed Enclosure**: Custom body camera design files included

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

# Raspberry Pi Physical Button Camera Setup

This guide provides complete instructions for setting up automatic video recording with physical button control, LED indicators, and encryption on a Raspberry Pi Zero 2W.

## ⚠️ Important: Updated Setup Process

The setup process has been simplified and automated. **You now only need to run two scripts in sequence:**

1. **`sudo ./setup/setup_sudo.sh`** - Complete system setup (run as root)
2. **`./setup/install.sh`** - User configuration (run as mlink user)

This replaces the previous manual step-by-step process with automated scripts that handle all configuration automatically.

## Table of Contents

1. [Quick Setup](#quick-setup)
2. [Prerequisites](#prerequisites)
3. [Hardware Setup](#hardware-setup)
4. [Installation Process](#installation-process)
5. [SSH Key Setup](#ssh-key-setup)
6. [Camera Setup](#camera-setup)
7. [Recording Script Setup](#recording-script-setup)
8. [Sudo Configuration](#sudo-configuration)
9. [Service Management](#service-management)
10. [Windows Setup](#windows-setup)
11. [Troubleshooting](#troubleshooting)
12. [Maintenance](#maintenance)

## Quick Setup

### 🚀 One-Command Installation

```bash
# 1. Transfer files to Pi
scp -r mLink_hardware/ pi@<RPI_IP>:~/

# 2. SSH to Pi
ssh pi@<RPI_IP>

# 3. Navigate to project directory
cd mLink_hardware

# 4. Run system setup (as root)
sudo ./setup/setup_sudo.sh

# 5. Run user configuration (as mlink user)
./setup/install.sh

# 6. Reboot
sudo reboot

# 7. Test & start service
rpicam-still -o test.jpg
python3 ~/pycam.py
systemctl --user start pycam.service
```

### 🔑 Key Files Location

| File | Source | Destination |
|------|---------|-------------|
| `public.asc` | `setup/Key_Folder/` | `~/mlink_public.asc` |
| `mlink-hardware-deploy` | `setup/Key_Folder/` | `~/.ssh/` |
| `mlink_key.pub` | `setup/Key_Folder/` | `~/.ssh/` |
| `pycam.py` | `rpi_files/` | `~/pycam.py` |

### 📋 What Gets Installed

- ✅ System packages (python3, libcamera-apps, ffmpeg, gnupg)
- ✅ Python virtual environment with dependencies
- ✅ GPG encryption key import and trust
- ✅ SSH deploy keys and new key pair generation
- ✅ Camera interface enablement
- ✅ Systemd service for auto-startup
- ✅ Sudo permissions for GPIO access
- ✅ Assets directory for recordings

## Prerequisites

- Raspberry Pi OS (Bullseye or newer)
- Raspberry Pi Zero 2 W
- Camera module (connected via CSI interface)
- Physical push button (momentary switch)
- LED (for status indication)
- Resistors (220Ω for LED, 10kΩ for button pull-up)
- Breadboard and jumper wires
- Windows computer for decryption
- Required packages:
  - `python3` - Python runtime
  - `python3-pip` - Python package manager
  - `libcamera-apps` - Camera applications
  - `ffmpeg` - Video processing
  - `gnupg` - Encryption tools
  - `RPi.GPIO` - GPIO control

## Hardware Setup

### 1. Button Connection

Connect the physical button between GND and GPIO pin 15 (BCM numbering):

```ini
Button between GND and GPIO 15 (BCM 15, Physical Pin 10)
```

### 2. LED Connection

Connect the LED between GND and GPIO pin 17 (BCM numbering):

```Bash
LED between GND and GPIO 17 (BCM 17, Physical Pin 11)
```

### 3. Circuit Diagram

```bash
GND ── Button ── GPIO 15 (Physical Pin 10)
GND ── LED ── GPIO 17 (Physical Pin 11)
```

### GPIO Pin Connections

| Component | GPIO Pin (BCM) | Physical Pin | Connection |
|-----------|----------------|--------------|------------|
| Button    | 15            | 10           | Button between GND and GPIO 15 |
| LED       | 17            | 11           | LED between GND and GPIO 17 |

## Installation Process

### Step 1: Transfer Files to Raspberry Pi

1. **Copy the entire project folder** to your Raspberry Pi:

   ```bash
   # From your development machine
   scp -r mLink_hardware/ pi@<RPI_IP>:~/
   
   # Or use USB drive, SCP, or any file transfer method
   ```

2. **SSH into your Raspberry Pi**:

   ```bash
   ssh pi@<RPI_IP>
   ```

3. **Navigate to the project directory**:

   ```bash
   cd mLink_hardware
   ```

### Step 2: Complete System Setup (Run First)

The system setup is now handled by `setup/setup_sudo.sh` which performs all root-level operations:

```bash
# Run as root (sudo)
sudo ./setup/setup_sudo.sh
```

This script automatically:

- Updates system packages (`apt update`)
- Installs all required software
- Sets up Python virtual environment
- Configures camera and GPIO interfaces
- Creates systemd service
- Configures sudo access
- Sets up GPG and SSH keys
- Installs Tailscale

**Note**: Ensure your public key is placed in `setup/Key_Folder/public.asc` before running the setup script.

### Step 3: User Configuration (Run Second)

After system setup, run the user configuration script:

```bash
# Run as mlink user (non-root)
./setup/install.sh
```

This script handles user-specific configurations and final testing.

**Note**: The main install script checks that system setup has been completed first.

### Step 4: Reboot and Test

1. **Reboot the Raspberry Pi**:

   ```bash
   sudo reboot
   ```

2. **After reboot, test the camera**:

   ```bash
   libcamera-still -o test.jpg
   ```

3. **Test the GPIO script**:

   ```bash
   python3 ~/pycam.py
   ```

4. **Start the camera service**:

   ```bash
   systemctl --user start pycam.service
   ```

## SSH Key Setup

SSH key setup is now automatically handled by `setup/setup_sudo.sh`. The script will:

1. Create the `.ssh` directory with proper permissions (700)
2. Copy the public key from `setup/Key_Folder/mlink_key.pub`
3. Add it to `authorized_keys` for passwordless login (with 644 permissions)

**Note**:

- Ensure your public key is placed in `setup/Key_Folder/mlink_key.pub` before running the setup script
- This enables unidirectional SSH access (only your laptop can connect to the Pi without password)
- The Pi cannot connect to other machines

## VSFTPD Configuration

For FTP access to transfer recorded videos, you need to configure VSFTPD. This requires manual configuration as it needs sudo access:

### 1. Install VSFTPD (if not already installed)

```bash
sudo apt update
sudo apt install vsftpd
```

### 2. Configure VSFTPD

Edit the VSFTPD configuration file:

```bash
sudo nano /etc/vsftpd.conf
```

Add or modify the following settings in the configuration file:

```ini
# Enable local users
local_enable=YES

# Disable write access for security
write_enable=NO

# Enable chroot for local users
chroot_local_user=YES

# Allow writeable chroot
allow_writeable_chroot=YES

# Enable passive mode
pasv_enable=YES

# Set passive mode port range
pasv_min_port=40000
pasv_max_port=40100

# Set local umask for file permissions (022 = readable by all, writable by owner only)
local_umask=022
```

### 3. Restart VSFTPD Service

```bash
sudo systemctl restart vsftpd
sudo systemctl enable vsftpd
```

### 4. Verify FTP Service

```bash
# Check service status
sudo systemctl status vsftpd

# Test FTP connection (from another machine)
ftp <PI_IP_ADDRESS>
```

**Note**:

- VSFTPD is configured in read-only mode (`write_enable=NO`) for security
- Passive mode is enabled with specific port range for firewall compatibility
- Users are chrooted to their home directory for security
- This configuration allows downloading recorded videos via FTP

## Camera Setup

Camera setup is now automatically handled by `setup/setup_sudo.sh`. The script will:

1. Enable camera interface using `raspi-config`
2. Enable I2C, SPI, and serial interfaces for GPIO
3. Configure proper permissions

**Note**: A reboot will be required after setup for these changes to take effect.

## Recording Script Setup

Script setup is now automatically handled by `setup/setup_sudo.sh`. The script will:

1. Copy `pycam.py` from `rpi_files/` to `/home/mlink/pycam.py`
2. Set proper ownership and permissions
3. Make the script executable

**Note**: Ensure `pycam.py` is present in the `rpi_files/` directory before running the setup script.

### LED Indicator Meanings

- **LED Off**: System ready, not recording
- **LED Slow Blink (1s)**: Recording in progress
- **LED Solid**: Error state

## Sudo Configuration

Sudo configuration is now automatically handled by `setup/setup_sudo.sh`. The script will:

1. Create a backup of the sudoers file
2. Add passwordless sudo access for specific commands:
   - `/usr/bin/python3 /home/mlink/pycam.py`
   - GPIO access (`/usr/bin/gpio`, `/usr/bin/raspi-gpio`)
   - Camera access (`/usr/bin/libcamera-*`, `/usr/bin/ffmpeg`)
3. Add the mlink user to required groups (gpio, video, audio)

**Note**: The sudoers backup is stored at `/etc/sudoers.backup` for safety.

## Service Management

Service setup is now automatically handled by `setup/setup_sudo.sh`. The script will:

1. Create the systemd service file at `/etc/systemd/user/pycam.service`
2. Enable user lingering for the mlink user
3. Reload systemd daemon
4. Configure the service to start automatically on boot

The service runs the camera script from the Python virtual environment and automatically restarts on failure.

### Service Management Commands

```bash
# Check service status
systemctl --user status pycam.service

# View service logs
journalctl --user -u pycam.service -f

# Restart service
systemctl --user restart pycam.service

# Stop service
systemctl --user stop pycam.service

# Disable service (won't start on boot)
systemctl --user disable pycam.service

# Start service
systemctl --user start pycam.service
```

### Automatic Restart on Failure

The service is configured to automatically restart if it crashes. To monitor for issues:

```bash
# Check recent logs
journalctl --user -u pycam.service --since "1 hour ago"

# Check for errors
journalctl --user -u pycam.service -p err
```

## Windows Setup

### 1. Install Gpg4win

Download and install from: ```https://gpg4win.org/```

### 2. Import Private Key

Use Kleopatra to import your private key matching `westw@mlink`.

### 3. Decryption Script

Run the improved decryption script:

```powershell
powershell -ExecutionPolicy Bypass -File "automations/decrypt.ps1"
```

### 4. Diagnostic Tool

If decryption fails, run the diagnostic tool:

```powershell
powershell -ExecutionPolicy Bypass -File "automations/diagnose_decrypt.ps1"
```

## Troubleshooting

### 1. Setup Issues

#### Script Not Found

- **Problem**: `setup/setup_sudo.sh` or `setup/install.sh` not found
- **Solution**: Ensure you're in the correct directory with all project files

#### Permission Denied

- **Problem**: Cannot run setup scripts
- **Solution**:

  - Run `setup/setup_sudo.sh` with sudo: `sudo ./setup/setup_sudo.sh`
  - Run `setup/install.sh` as mlink user (not root)

#### Setup Incomplete

- **Problem**: Some features not working after setup
- **Solution**: Ensure both scripts completed successfully and reboot if prompted

### 2. Button Not Working

```bash
# Check GPIO permissions
sudo usermod -a -G gpio mlink

# Test GPIO manually
python3 -c "import RPi.GPIO as GPIO; GPIO.setmode(GPIO.BCM); GPIO.setup(15, GPIO.IN); print('Button pin:', GPIO.input(15))"
```

### 3. LED Not Working

```bash
# Test LED manually
python3 -c "import RPi.GPIO as GPIO; GPIO.setmode(GPIO.BCM); GPIO.setup(17, GPIO.OUT); GPIO.output(17, GPIO.HIGH); print('LED should be on')"
```

### 4. Camera Issues

```bash
# Check camera connection
ls -l /dev/video*

# Test camera
libcamera-still -o test.jpg

# Check camera permissions
sudo usermod -a -G video mlink
```

### 5. Service Issues

```bash
# Check service status
systemctl --user status pycam.service

# View detailed logs
journalctl --user -u pycam.service -n 50

# Restart service
systemctl --user restart pycam.service
```

### 6. Recording Issues

```bash
# Check disk space
df -h

# Check recording directory
ls -la /home/mlink/assets/

# Check for lock files
find /home/mlink/assets/ -name "*.lock" -delete
```

### 7. SSH Connection Issues

```bash
# Test SSH connection from laptop to Pi
ssh mlink@<PI_IP>

# Check SSH keys on Pi
ls -la ~/.ssh/

# Check authorized_keys
cat ~/.ssh/authorized_keys
```

### 8. GPIO Permission Issues

```bash
# Add user to required groups
sudo usermod -a -G gpio,video mlink

# Reboot to apply changes
sudo reboot
```

### 🆘 Quick Troubleshooting

```bash
# Service won't start
journalctl --user -u pycam.service

# Camera issues
dmesg | grep -i camera

# GPIO problems
sudo gpio readall

# Check permissions
ls -la ~/.ssh/
ls -la ~/pycam.py
```

## Maintenance

### 1. Regular Checks

```bash
# Check disk space
df -h

# Check service status
systemctl --user status pycam.service

# Check recent recordings
ls -la /home/mlink/assets/

# Check system logs
journalctl --user -u pycam.service --since "1 day ago"
```

### 2. Backup Strategy

```bash
# Backup recordings directory
rsync -av /home/mlink/assets/ /backup/recordings/

# Backup service configuration
cp /etc/systemd/user/pycam.service /backup/
```

### 3. Updates

```bash
# Update system packages
sudo apt update && sudo apt upgrade

# Update Python packages
pip install --upgrade RPi.GPIO
```

### Regular Updates

```bash
# Update system packages
sudo apt update && sudo apt upgrade

# Update Python packages
source ~/venv/bin/activate
pip install --upgrade -r rpi_files/requirements.txt
```

### Backup Strategy

- Backup recordings directory: `~/assets/`
- Backup service configuration: `~/.config/systemd/user/pycam.service`
- Backup SSH keys: `~/.ssh/`
- Backup GPG keys: `~/mlink_public.asc`

### Monitoring

- Check disk space regularly: `df -h`
- Monitor service logs: `journalctl --user -u pycam.service`
- Verify camera functionality: `libcamera-still -o test.jpg`

## Configuration Files

### 1. pycam.py Configuration

Key settings in `pycam.py`:

```python
BUTTON_PIN = 15       # BCM pin 15
LED_PIN = 17         # BCM pin 17
ASSETS_DIR = Path("/home/mlink/assets")
RECORD_DURATION_MS = 1800000  # 30 minutes max
TRIGGER_COOLDOWN = 2.0  # Button debounce
MIN_RECORDING_TIME = 5  # Minimum recording time
```

### 2. Service Configuration

The service file is located at:

```bash
/etc/systemd/user/pycam.service
```

## File Locations After Installation

| File/Directory | Location | Purpose |
|----------------|----------|---------|
| Python script | `~/pycam.py` | Main camera recording script |
| Virtual env | `~/venv/` | Python environment with dependencies |
| Service file | `~/.config/systemd/user/pycam.service` | Systemd service configuration |
| Assets dir | `~/assets/` | Directory for video recordings |
| GPG key | `~/mlink_public.asc` | Encryption public key |
| SSH keys | `~/.ssh/` | SSH and deploy keys |
| Camera config | `/boot/firmware/config.txt` | Camera interface settings |

## Security Considerations

### SSH Key Security

- Private keys have 600 permissions (owner read/write only)
- Public keys have 644 permissions (owner read/write, others read)
- Deploy keys should be kept secure and not shared

### GPG Key Security

- Public keys are imported and trusted for encryption
- Private keys remain on the originating machine
- Encrypted videos can only be decrypted with the corresponding private key

### Sudo Permissions

- Limited sudo access only to required commands
- No general sudo access granted
- Specific paths and commands are whitelisted

## Notes

- The LED provides visual feedback for all system states
- Button presses are debounced to prevent accidental triggers
- Recordings are automatically encrypted after completion
- The service automatically restarts on failure
- SSH keys enable secure remote access
- Regular backups of recordings are recommended
- Monitor disk space to prevent recording failures
- Check service logs regularly for issues
- **Reboot required** after camera interface setup
- **SSH public key** will be displayed - copy it to other machines
- **Service runs as root** for GPIO access
- **LED indicators**: Off=ready, Slow blink=recording
- **Button debounce**: 2-second cooldown between recordings

## Support

For additional support or troubleshooting:

1. Check the main README.md file
2. Review service logs for error messages
3. Verify hardware connections
4. Test individual components separately
