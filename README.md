# Acer WMI Battery Ansible Role

This Ansible role installs and configures the [Acer WMI Battery kernel module](https://github.com/frederik-h/acer-wmi-battery) for Acer laptops. The module enables battery threshold control on supported Acer laptops.

## About the Module

This role installs and configures the [acer-wmi-battery](https://github.com/frederik-h/acer-wmi-battery) kernel module, created by [Frederik Himpe](https://github.com/frederik-h). The module provides battery health control features for Acer laptops:

- **Health Mode**: Limits battery charging to 80% to preserve long-term battery capacity
- **Calibration Mode**: Enables battery capacity calibration for accurate capacity estimates

This Ansible role focuses solely on automating the installation and configuration of the upstream module. For module-specific issues or feature requests, please refer to the [upstream repository](https://github.com/frederik-h/acer-wmi-battery).

## Features

- Distribution-agnostic package management
- Automatic upstream repository updates
- DKMS integration for kernel updates
- Module autoloading configuration
- Comprehensive test suite
- Full idempotency support

## Battery Health Features

After installation, you can control the battery features through sysfs:

```bash
# Enable health mode (limit charging to 80%)
echo 1 > /sys/devices/platform/acer-wmi-battery/health_mode

# Disable health mode (allow full charging)
echo 0 > /sys/devices/platform/acer-wmi-battery/health_mode

# Start battery calibration
echo 1 > /sys/devices/platform/acer-wmi-battery/calibration_mode
```

The health mode is particularly useful for laptops that are frequently plugged in, as limiting the maximum charge to 80% can significantly extend the battery's lifespan.

## Requirements

- Ansible 2.9 or higher
- One of the following Linux distributions:
  - Debian/Ubuntu
  - RedHat/Fedora
  - SUSE
  - Arch Linux
- Python 3.x
- Git
- DKMS

## Secure Boot Considerations

The role now includes automatic module signing support. When installing the module:

1. If you have Secure Boot enabled (common on modern systems):
   - The role will automatically sign the module using DKMS's MOK (Machine Owner Key)
   - You'll need to enroll the MOK key on first installation:
     ```bash
     # Check if you already have a MOK key
     ls -l /var/lib/dkms/mok.*
     
     # If no key exists, generate one (the role will do this automatically)
     sudo dkms mok -g
     
     # Import the public key into your system
     sudo mokutil --import /var/lib/dkms/mok.pub
     
     # You'll be prompted to create a one-time password
     # Remember this password for the next step!
     ```
   - Reboot your system
   - During boot, you'll see a blue MOK management screen
   - Select "Enroll MOK"
   - Select "Continue"
   - Enter the password you created with mokutil
   - Select "Yes" to enroll the key
   - Select "Reboot"
   - After reboot, the module will load automatically with Secure Boot enabled

2. If you prefer not to use module signing:
   - Disable Secure Boot in your BIOS/UEFI settings
   - The module will load without requiring key enrollment

The role automatically detects your system's configuration and handles module signing appropriately.

### MOK Key Management

The Machine Owner Key (MOK) is used to sign kernel modules for Secure Boot. Here are some useful MOK management commands:

```bash
# List enrolled keys
mokutil --list-enrolled

# Check if a key is enrolled
mokutil --test-key /var/lib/dkms/mok.pub

# Reset MOK list (removes all enrolled keys - use with caution!)
mokutil --reset

# Check Secure Boot status
mokutil --sb-state

# Revoke a MOK key
mokutil --revoke-import
```

Important notes about MOK keys:
- The private key (`/var/lib/dkms/mok.key`) should be kept secure and never shared
- The public key (`/var/lib/dkms/mok.pub`) is used for verification and can be shared
- Keys are persistent across kernel updates
- Multiple keys can be enrolled if needed
- If you reinstall your system, you'll need to re-enroll the keys

## Debugging

### ACPI Table Dumps
If you need to analyze ACPI tables for debugging WMI methods:

```bash
# Install acpica-tools
sudo dnf install acpica-tools

# Dump ACPI tables
sudo acpidump > acpi.dump

# Extract individual tables
acpixtract -a acpi.dump

# Decompile a specific table (e.g., DSDT)
iasl -d dsdt.dat
```

Note: ACPI table dumps (*.dat files) are excluded from git to keep the repository clean.

## Recent Changes

### Module Signing Improvements
- Added automatic module signing based on SELinux status
- Module will be signed automatically when SELinux is in enforcing mode
- Added configuration options to force signing on/off:
  - `acer_battery_force_signing: true` - Always sign the module
  - `acer_battery_force_no_signing: true` - Never sign the module
  - Both `false` (default) - Sign based on SELinux status

### Reliability Improvements
- Added source code integrity checks
- Implemented automatic backup and recovery
- Added module functionality verification
- Added comprehensive error handling for DKMS operations

## Configuration

### Module Signing
By default, the module will be signed only when SELinux is in enforcing mode. You can override this behavior:

```yaml
# In your playbook or host_vars:
acer_battery_force_signing: true    # Always sign
# or
acer_battery_force_no_signing: true # Never sign
```

### Error Recovery
The role now includes automatic error recovery:
- Backs up working source code
- Verifies source code integrity
- Validates module functionality
- Automatically restores from backup if needed

## Installation

1. Clone this repository:
```bash
git clone https://github.com/yourusername/ansible-acer-battery.git
cd ansible-acer-battery
```

2. Create an inventory file (e.g., `inventory`) with your Acer laptops:
```ini
[acer_laptops]
laptop1 ansible_host=192.168.1.100
laptop2 ansible_host=192.168.1.101
```

## Usage

1. Run the playbook:
```bash
# Check mode (dry-run)
ansible-playbook -i inventory site.yml --check

# Actual installation
ansible-playbook -i inventory site.yml
```

The role will automatically:
- Install required packages for your distribution (including kernel headers and build tools)
- Clone or update the Acer WMI Battery module from the upstream repository
- Configure DKMS for automatic rebuilding when kernel updates occur
- Build and install the module
- Configure module autoloading

### Distribution-Specific Notes

#### Debian/Ubuntu
- Automatically installs `linux-headers-$(uname -r)` and `build-essential`
- Uses APT for package management

#### RedHat/Fedora
- Automatically installs `kernel-headers`, `kernel-devel`, and development tools
- Uses DNF/YUM for package management
- Tested on both RHEL and Fedora

#### SUSE
- Automatically installs `linux-headers` and development tools
- Uses Zypper for package management

#### Arch Linux
- Automatically installs `linux-headers` and `base-devel`
- Uses Pacman for package management

### Upstream Updates

The role checks for updates from the upstream repository during each playbook run. When updates are found:
1. The repository is automatically updated
2. DKMS rebuilds the module if needed
3. The new version is loaded automatically

You can manually trigger an update by running the playbook again:
```bash
ansible-playbook -i inventory site.yml
```

## Troubleshooting

If the health mode interface is not available after installation:

1. Check if the module is loaded:
```bash
lsmod | grep acer_wmi_battery
```

2. Check kernel logs for any errors:
```bash
dmesg | grep -i acer
```

3. If you see module verification errors:
- Follow the Secure Boot instructions above
- Or temporarily disable Secure Boot for testing

4. After making changes:
```bash
sudo modprobe -r acer_wmi_battery  # Unload the module
sudo modprobe acer_wmi_battery     # Load it again
```

## Development

This project follows strict Python best practices:
- Package management with `uv`
- Type checking with `mypy`
- Code formatting with `black`
- Security scanning with `bandit`
- Test coverage with `pytest-cov`
- Comprehensive test suite
- Automated module signing for Secure Boot compatibility

### Setting up the Development Environment

1. Create a virtual environment:
```bash
uv venv
source .venv/bin/activate
```

2. Install development dependencies:
```bash
uv pip install -r requirements-dev.txt
```

3. Set up module signing (optional):
```bash
# Generate a new MOK key pair if needed
sudo dkms mok -g

# Import the public key
sudo mokutil --import /var/lib/dkms/mok.pub
```

### Running Tests

Run the full test suite:
```bash
pytest
```

Run specific test categories:
```bash
# Syntax tests
pytest tests/test_role.py::test_role_syntax

# Idempotency tests
pytest tests/test_role.py::test_role_idempotency

# DKMS configuration tests
pytest tests/test_dkms_config.py

# Module signing tests
pytest tests/test_module_signing.py
```

### Code Quality

Format code with black:
```bash
black .
```

Run type checking:
```bash
mypy .
```

Run security scan:
```bash
bandit -c pyproject.toml -r .
```

## Contributing

1. Fork the repository
2. Create your feature branch
3. Add tests for any new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

GPL-3.0-or-later
