# Acer WMI Battery Module Ansible Role

This Ansible role automates the installation and maintenance of the [Acer WMI Battery module](https://github.com/frederik-h/acer-wmi-battery) for Linux. The module provides battery health control features for Acer laptops, including:
- Health mode that limits battery charge to 80% to preserve battery capacity
- Battery calibration mode for accurate capacity estimates

## Requirements

- Ansible 2.9 or higher
- Debian/Ubuntu-based system
- Root/sudo access

## Installation

1. Add your target hosts to your Ansible inventory
2. Include the role in your playbook:

```yaml
- hosts: your_hosts
  roles:
    - acer_battery
```

## Usage

Run the playbook:

```bash
ansible-playbook -i inventory site.yml
```

The role will:
1. Install required dependencies
2. Clone and build the module
3. Set up DKMS for automatic rebuilding with kernel updates
4. Load the module and configure it to load at boot

## Configuration

Default variables in `roles/acer_battery/defaults/main.yml`:
- `acer_battery_version`: Module version (default: "1.0")

## Testing

Test the installation by checking the module status:
```bash
lsmod | grep acer_wmi_battery
```

## License

This Ansible role is licensed under MIT. The Acer WMI Battery module itself is under its original license.
