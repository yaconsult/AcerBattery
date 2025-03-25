# Acer WMI Battery Ansible Role

This Ansible role installs and configures the [Acer WMI Battery kernel module](https://github.com/frederik-h/acer-wmi-battery) for Acer laptops. The module enables battery threshold control on supported Acer laptops.

## About the Module

This role installs and configures the [acer-wmi-battery](https://github.com/frederik-h/acer-wmi-battery) kernel module, created by [Frederik Himpe](https://github.com/frederik-h). The module provides battery health control features for Acer laptops:

- **Health Mode**: Limits battery charging to 80% to preserve long-term battery capacity
- **Calibration Mode**: Enables battery capacity calibration for accurate capacity estimates

This Ansible role focuses solely on automating the installation and configuration of the upstream module. For module-specific issues or feature requests, please refer to the [upstream repository](https://github.com/frederik-h/acer-wmi-battery).

## Features

- Distribution-agnostic package management
- Automatic upstream repository updates via SSH
- DKMS integration for kernel updates
- Module autoloading configuration
- Comprehensive test suite
- Full idempotency support
- Automatic module signing for Secure Boot
- Source code integrity verification
- Automatic backup and recovery

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
- Git with SSH access
- DKMS
- rsync

## Recent Changes

### Repository Access Improvements
- Updated to use SSH for repository access
- Added support for private repository access
- Improved error handling for repository operations

### Module Signing Improvements
- Added automatic module signing based on SELinux and Secure Boot status
- Module will be signed automatically when required
- Added configuration options to force signing on/off:
  - `acer_battery_force_signing: true` - Always sign the module
  - `acer_battery_force_no_signing: true` - Never sign the module
  - Both `false` (default) - Sign based on system status

### Reliability Improvements
- Added source code integrity checks
- Implemented automatic backup and recovery
- Added module functionality verification
- Added comprehensive error handling for DKMS operations
- Fixed Makefile formatting for proper compilation

## Installation

1. Clone this repository:
```bash
git clone git@github.com:yaconsult/ansible-acer-battery.git
cd ansible-acer-battery
```

2. Create an inventory file (e.g., `inventory`) with your Acer laptops:
```ini
[acer_laptops]
localhost ansible_connection=local
```

3. Run the playbook:
```bash
ansible-playbook -i inventory site.yml
```

## Configuration

### Repository Access
By default, the role uses SSH to clone the repository. Make sure you have:
1. SSH key configured for GitHub access
2. SSH agent running with your key loaded

### Module Signing
The module will be signed when either:
1. SELinux is in enforcing mode
2. Secure Boot is enabled

You can override this behavior:

```yaml
# In your playbook or host_vars:
acer_battery_force_signing: true    # Always sign
# or
acer_battery_force_no_signing: true # Never sign
```

### Error Recovery
The role includes automatic error recovery:
- Backs up working source code
- Verifies source code integrity
- Validates module functionality
- Automatically restores from backup if needed

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Ensure all tests pass
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
