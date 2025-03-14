# Acer WMI Battery Module Ansible Role

This Ansible role automates the installation and maintenance of the [Acer WMI Battery module](https://github.com/frederik-h/acer-wmi-battery) for Linux. The module provides battery health control features for Acer laptops, including:
- Health mode that limits battery charge to 80% to preserve battery capacity
- Battery calibration mode for accurate capacity estimates

## Prerequisites

- Linux system (Supported distributions: Debian/Ubuntu, RedHat/Fedora, SUSE, Arch Linux)
- Python 3.x
- `uv` package manager
- Root/sudo access
- Git with SSH configured

## Installation

1. Clone the repository:
```bash
git clone git@github.com:yaconsult/AcerBattery.git
cd AcerBattery
```

2. Set up the Python environment:
```bash
# Create and activate virtual environment using uv
uv venv
source .venv/bin/activate

# Install dependencies
uv pip install -r requirements.txt
```

3. Configure your inventory:
   - For local installation, use the provided `inventory` file
   - For remote hosts, modify the inventory file with your target hosts:
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

2. Verify the installation:
```bash
# Check if module is loaded
lsmod | grep acer_wmi_battery

# Check DKMS status
dkms status | grep acer-wmi-battery
```

3. Control battery features:
```bash
# Enable health mode (limit to 80% charge)
echo 1 > /sys/devices/platform/acer-wmi-battery/health_mode

# Disable health mode
echo 0 > /sys/devices/platform/acer-wmi-battery/health_mode

# Start battery calibration
echo 1 > /sys/devices/platform/acer-wmi-battery/calibration_mode
```

## Development

This project follows Python best practices and uses several tools to maintain code quality:

```bash
# Activate virtual environment
source .venv/bin/activate

# Format code
black .

# Run linters and type checking
flake8 .
mypy .

# Run security checks
bandit -r .

# Run tests with coverage
pytest --cov
```

## Distribution Support

The role automatically detects your Linux distribution and installs the appropriate packages. Currently supported distributions:

- Debian/Ubuntu: Uses `build-essential` and `linux-headers-*`
- RedHat/Fedora: Uses `gcc`, `make`, and `kernel-*` packages
- SUSE: Uses `gcc`, `make`, and `kernel-*` packages
- Arch Linux: Uses `base-devel` and `linux-headers`

To add support for additional distributions, modify the package mappings in `roles/acer_battery/defaults/main.yml`.

## Troubleshooting

1. If the module fails to load:
   ```bash
   # Check kernel logs
   dmesg | grep acer-wmi-battery
   
   # Rebuild module
   dkms rebuild -m acer-wmi-battery -v 1.0
   ```

2. If the playbook fails:
   - Check that your distribution is supported
   - Verify sudo/root access
   - Check system logs for detailed error messages

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and linters
5. Submit a pull request

## License

This Ansible role is licensed under MIT. The Acer WMI Battery module itself is under its original license.
