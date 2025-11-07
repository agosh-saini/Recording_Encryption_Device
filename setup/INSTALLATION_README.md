# Installation Guide

This directory contains the installation scripts for setting up the Raspberry Pi Physical Button Camera system. Follow this guide to properly install and configure the system.

## Overview

The installation process consists of two main scripts that must be run in sequence:

1. **`setup_sudo.sh`** - Complete system setup (requires root/sudo)
2. **`install.sh`** - User configuration (run as mlink user)

## Prerequisites

Before running the installation scripts, ensure you have:

1. **Raspberry Pi OS** (Bullseye or newer) installed
2. **Internet connection** for package downloads
3. **User account** with sudo privileges (default `mlink` user)
4. **Camera module** connected via CSI interface
5. **Physical button and LED** connected to GPIO pins
6. **Required key files** in `Key_Folder/`:
   - `public.asc` - GPG public key for encryption
   - `mlink_key.pub` - SSH public key for passwordless login

## Installation Steps

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

### Step 2: Prepare Key Files

Before running the installation scripts, ensure your key files are in place:

```bash
# Check that key files exist
ls -la setup/Key_Folder/
# Should show:
# - public.asc
# - mlink_key.pub
```

If these files are missing, add them before proceeding.

### Step 3: Run System Setup Script (as root)

The first script performs all system-level configuration and requires root privileges:

```bash
# Make script executable (if not already)
chmod +x setup/setup_sudo.sh

# Run as root
sudo ./setup/setup_sudo.sh
```

**What this script does:**

- Updates system packages (`apt update && apt upgrade`)
- Installs required software (python3, libcamera-apps, ffmpeg, gnupg, etc.)
- Installs Tailscale
- Copies project files to `/home/mlink/`
- Sets up Python virtual environment
- Configures camera and GPIO interfaces
- Creates systemd service
- Configures sudo access for GPIO and camera operations
- Sets up GPG and SSH keys
- Adds user to required groups (gpio, video, audio)

**Expected output:**

- Progress messages for each step
- Success/warning/error indicators
- Summary of what was configured
- Next steps instructions

**Note:** This script will prompt for a reboot after completion. You can reboot now or after running the user configuration script.

### Step 4: Run User Configuration Script (as mlink user)

After the system setup completes, run the user configuration script:

```bash
# Switch to mlink user (if not already)
su - mlink
# Or if already logged in as mlink, skip the above

# Navigate to project directory
cd ~/mLink_hardware

# Make script executable (if not already)
chmod +x setup/install.sh

# Run as mlink user (NOT as root)
./setup/install.sh
```

**What this script does:**

- Verifies system setup was completed
- Checks camera interface configuration
- Verifies camera script location
- Configures systemd service for user
- Sets up user permissions
- Configures GPG keys
- Configures SSH keys
- Creates assets directory
- Tests setup components

**Expected output:**

- Verification messages
- Configuration status
- Service management commands
- Next steps instructions

### Step 5: Reboot and Test

After both scripts complete successfully:

1. **Reboot the Raspberry Pi**:

   ```bash
   sudo reboot
   ```

2. **After reboot, test the camera**:

   ```bash
   rpicam-still -o test.jpg
   ```

3. **Test the GPIO script**:

   ```bash
   python3 ~/pycam.py
   ```

4. **Start the camera service**:

   ```bash
   systemctl --user start pycam.service
   ```

5. **Check service status**:

   ```bash
   systemctl --user status pycam.service
   ```

## Script Options

### setup_sudo.sh Options

The `setup_sudo.sh` script supports several command-line options:

```bash
# Full system setup (default)
sudo ./setup/setup_sudo.sh

# Verify current configuration
sudo ./setup/setup_sudo.sh --verify

# Test GPIO functionality (LED and Button)
sudo ./setup/setup_sudo.sh --test-gpio

# Restore sudoers from backup
sudo ./setup/setup_sudo.sh --restore

# Show help message
sudo ./setup/setup_sudo.sh --help
```

### install.sh Options

The `install.sh` script runs user configuration. It doesn't have command-line options but will check prerequisites and provide helpful error messages if something is missing.

## Troubleshooting

### Script Not Found

**Problem:** `setup/setup_sudo.sh` or `setup/install.sh` not found

**Solution:**

- Ensure you're in the correct directory (`mLink_hardware`)
- Check that scripts exist: `ls -la setup/`
- Verify you're in the project root directory

### Permission Denied

**Problem:** Cannot run setup scripts

**Solution:**

- Run `setup_sudo.sh` with sudo: `sudo ./setup/setup_sudo.sh`
- Run `install.sh` as mlink user (NOT as root)
- Check script permissions: `chmod +x setup/*.sh`

### Setup Incomplete

**Problem:** Some features not working after setup

**Solution:**

- Ensure both scripts completed successfully
- Check for error messages in the output
- Reboot if prompted: `sudo reboot`
- Verify system setup: `sudo ./setup/setup_sudo.sh --verify`

### Key Files Missing

**Problem:** GPG or SSH key setup fails

**Solution:**

- Ensure `public.asc` is in `setup/Key_Folder/`
- Ensure `mlink_key.pub` is in `setup/Key_Folder/`
- Check file permissions: `ls -la setup/Key_Folder/`

### Service Won't Start

**Problem:** Systemd service fails to start

**Solution:**

- Check service logs: `journalctl --user -u pycam.service`
- Verify Python virtual environment exists: `ls -la ~/venv/`
- Check file paths in service configuration: `cat /etc/systemd/user/pycam.service`
- Ensure user lingering is enabled: `loginctl show-user mlink | grep Linger`

## File Locations After Installation

| File/Directory | Location | Purpose |
|----------------|----------|---------|
| Python script | `~/pycam.py` | Main camera recording script |
| Virtual env | `~/venv/` | Python environment with dependencies |
| Service file | `/etc/systemd/user/pycam.service` | Systemd service configuration |
| Assets dir | `~/assets/` | Directory for video recordings |
| GPG key | `~/mlink_public.asc` | Encryption public key |
| SSH keys | `~/.ssh/` | SSH and deploy keys |
| Camera config | `/boot/firmware/config.txt` | Camera interface settings |
| Project files | `~/mLink_hardware/` | Copied project directory |

## Service Management

After installation, manage the camera service with these commands:

```bash
# Start service
systemctl --user start pycam.service

# Stop service
systemctl --user stop pycam.service

# Restart service
systemctl --user restart pycam.service

# Check service status
systemctl --user status pycam.service

# View service logs
journalctl --user -u pycam.service -f

# Enable auto-start on boot
systemctl --user enable pycam.service

# Disable auto-start on boot
systemctl --user disable pycam.service
```

## Security Considerations

### Sudo Permissions

The `setup_sudo.sh` script configures limited sudo access:

- Passwordless sudo for `/usr/bin/python3 /home/mlink/pycam.py`
- GPIO access commands (`gpio`, `raspi-gpio`)
- Camera access commands (`libcamera-*`, `rpicam-*`, `ffmpeg`)

A backup of the sudoers file is created at `/etc/sudoers.backup` for safety.

### SSH Keys

- Private keys have 600 permissions (owner read/write only)
- Public keys have 644 permissions (owner read/write, others read)
- SSH keys enable unidirectional access (laptop to Pi, not Pi to laptop)

### GPG Keys

- Public keys are imported and trusted for encryption
- Private keys remain on the originating machine
- Encrypted videos can only be decrypted with the corresponding private key

## Next Steps

After successful installation:

1. **Test hardware connections** - Verify button and LED work correctly
2. **Test camera** - Take a test photo/video
3. **Test recording** - Press button and verify recording works
4. **Check encryption** - Verify videos are encrypted after recording
5. **Monitor service** - Check logs to ensure service runs correctly
6. **Set up backups** - Configure backup strategy for recordings

## Additional Resources

- Main README: `../README.md` - Complete project documentation
- Quick Setup: See Quick Setup section in main README
- Troubleshooting: See Troubleshooting section in main README

## Support

For additional support or troubleshooting:

1. Check the main README.md file
2. Review service logs for error messages
3. Verify hardware connections
4. Test individual components separately
5. Run verification commands: `sudo ./setup/setup_sudo.sh --verify`
