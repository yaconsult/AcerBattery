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

## Development

This project follows strict Python best practices:
- Package management with `uv`
- Type checking with `mypy`
- Code formatting with `black`
- Security scanning with `bandit`
- Test coverage with `pytest-cov`
- Comprehensive test suite

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
