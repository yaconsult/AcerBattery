# Acer WMI Battery Ansible Role

[![Version](https://img.shields.io/badge/version-1.1.0-blue.svg)](https://github.com/yourusername/acer-battery-ansible/releases/tag/v1.1.0)

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
- Automatic module rebuilding when kernels are updated
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
- Git
- DKMS
- rsync

## Recent Changes

### Repository Access Improvements
- Updated default repository access to HTTPS (works out of the box with sudo)
- SSH repository access is still supported by overriding `acer_battery_repo_url`
- Improved error handling for repository operations

### Module Signing Improvements
- Added automatic module signing based on Secure Boot status
- Module will be signed automatically when required (or when forced)
- Added configuration options to force signing on/off:
  - `acer_battery_force_signing: true` - Always sign the module
  - `acer_battery_force_no_signing: true` - Never sign the module
  - Both `false` (default) - Sign based on system status

Note: With Secure Boot disabled, the module may still be signed by DKMS configuration,
but it is not required for loading.

### Reliability Improvements
- Added source code integrity checks
- Implemented automatic backup and recovery
- Added module functionality verification
- Added comprehensive error handling for DKMS operations
- Fixed Makefile formatting for proper compilation

## Installation

1. Clone this repository:
```bash
git clone https://github.com/yaconsult/ansible-acer-battery.git
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
By default, the role uses HTTPS to clone the upstream repository. If you want to use
SSH (for example, for a private fork), set:

```yaml
acer_battery_repo_url: "git@github.com:youruser/acer-wmi-battery.git"
```

### Installed source directory marker
By default, the role writes a small `ANSIBLE-MANAGED.txt` marker file into `{{ acer_battery_source_dir }}`
to document where the tree came from (this role + upstream repo) and where key hooks/logs live.

To disable it:

```yaml
acer_battery_install_managed_marker: false
```

### Module Signing
This role is designed to work across distributions regardless of whether Secure Boot and/or SELinux are enabled.

SELinux tools are optional. If `getenforce` is not installed on your system, the role will treat SELinux as
"not installed" and continue.

The module will be signed when Secure Boot is enabled (or when signing is explicitly forced). If Secure Boot is
disabled, signing is not required for loading.

You can override this behavior:

```yaml
# In your playbook or host_vars:
acer_battery_force_signing: true    # Always sign
# or
acer_battery_force_no_signing: true # Never sign
```

On Fedora/RHEL with Secure Boot enabled, the kernel may enforce additional restrictions ("lockdown").
If your module was signed with a MOK certificate but still fails to load, you may need to trust MOK
keys in the kernel keyring and reboot:

```bash
sudo mokutil --trust-mok
sudo reboot
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

## Using the Playbook

### Supported Distributions

The playbook currently supports the following Linux distributions:

- Debian/Ubuntu
- Fedora/RHEL/CentOS

### Prerequisites

- Ansible installed on your system
- A supported Acer laptop model (see [MODELS.md](https://github.com/frederik-h/acer-wmi-battery/blob/main/MODELS.md) in the repository)

### Usage

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/acer-battery-ansible.git
   cd acer-battery-ansible
   ```

2. Run the playbook:
   ```bash
   ansible-playbook -i localhost, -c local site.yml
   ```

   Or with sudo:
   ```bash
   sudo ansible-playbook -i localhost, -c local site.yml
   ```

### What the Playbook Does

1. Installs required packages based on your distribution
2. Clones the Acer WMI Battery repository
3. Builds and installs the kernel module using DKMS
4. Attempts to load the module
5. Provides troubleshooting information if the module fails to load

### Controlling Battery Health Mode

Once the module is loaded successfully, you can control the battery health mode by writing to the following file:

```bash
echo 0 | sudo tee /sys/bus/wmi/drivers/acer-wmi-battery/health_mode  # Standard Mode (100% charging)
echo 1 | sudo tee /sys/bus/wmi/drivers/acer-wmi-battery/health_mode  # Battery Health Mode (80% charging limit)
```

If your system exposes the control under a different sysfs path, these one-liners try both common locations:

```bash
# Enable charge limit (80%)
echo 1 | sudo tee /sys/bus/wmi/drivers/acer-wmi-battery/health_mode >/dev/null 2>&1 || \
  echo 1 | sudo tee /sys/devices/platform/acer-wmi-battery/health_mode

# Disable charge limit (100%)
echo 0 | sudo tee /sys/bus/wmi/drivers/acer-wmi-battery/health_mode >/dev/null 2>&1 || \
  echo 0 | sudo tee /sys/devices/platform/acer-wmi-battery/health_mode
```

### Practical usage examples

If you toggle this often, shell aliases make it quick:

```bash
alias charge_limit_off='echo 0 | sudo tee /sys/bus/wmi/drivers/acer-wmi-battery/health_mode'
alias charge_limit_on='echo 1 | sudo tee /sys/bus/wmi/drivers/acer-wmi-battery/health_mode'
alias charge_state='sudo cat /sys/bus/wmi/drivers/acer-wmi-battery/health_mode'
```

This repository also provides small helper scripts that try both sysfs paths:

```bash
sudo bash examples/charge_limit_on.sh
sudo bash examples/charge_limit_off.sh
```

If you want to see which sysfs node was detected on your system:

```bash
bash examples/find_health_mode_node.sh
```

To (re)load the module, prefer `modprobe` (works with DKMS-installed modules) over `insmod`:

```bash
alias charge_module='sudo modprobe acer_wmi_battery'
```

You can also use the helper installed by this role:

```bash
acer-battery-status
```

#### Automation example (charge to 100%, then limit + shutdown)

Some users prefer to temporarily allow charging to 100% (for calibration/travel), then re-enable
the 80% limit and shut down automatically. A simple approach is:

1. Set `health_mode` to `0` (unlimited)
2. Poll battery capacity periodically
3. When capacity reaches 100%, set `health_mode` to `1` and run `shutdown`

If you implement this yourself, ensure the module is loaded (`modprobe acer_wmi_battery`) and
use the sysfs path shown above for reads/writes.

This repository also includes a ready-to-use example script:

```bash
sudo bash examples/charge_full_then_limit_and_shutdown.sh
```

Useful options:

```bash
# Poll every 60 seconds
sudo bash examples/charge_full_then_limit_and_shutdown.sh --interval 60

# Charge only to 95%, then re-enable the limit and shut down
sudo bash examples/charge_full_then_limit_and_shutdown.sh --target 95

# Do not shut down at the end
sudo bash examples/charge_full_then_limit_and_shutdown.sh --no-shutdown

# Allow running even if AC adapter is not detected
sudo bash examples/charge_full_then_limit_and_shutdown.sh --allow-on-battery

# Dry-run (print actions without changing health_mode or shutting down)
sudo bash examples/charge_full_then_limit_and_shutdown.sh --dry-run
```

### Troubleshooting

If the module fails to load, try the following steps:

1. Reboot your system and then run: `sudo modprobe acer_wmi_battery`
2. Check kernel logs for errors: `dmesg | grep -i 'acer_wmi_battery'`
3. Verify your laptop model is supported: [MODELS.md](https://github.com/frederik-h/acer-wmi-battery/blob/main/MODELS.md)
4. If issues persist, try rebuilding the module: 
   ```bash
   sudo dkms remove acer-wmi-battery/main --all
   sudo dkms install acer-wmi-battery/main
   ```

### Kernel Updates

The role configures DKMS to automatically rebuild the module when you update your kernel.

Additionally, it installs OS-specific hooks as a fallback:

- Debian/Ubuntu: `/etc/kernel/postinst.d/99-acer-wmi-battery`
- Fedora/RHEL: `/etc/kernel/install.d/90-acer-wmi-battery.install`

On Fedora/RHEL, the hook logs to:

`/var/log/acer-wmi-battery-kernel-install.log`

This provides two layers of protection:
1. Standard DKMS automatic rebuilding
2. Custom kernel post-install hook as a fallback

After a kernel update, the module should be automatically rebuilt and loaded when you boot into the new kernel.

#### Verifying after a kernel update (recommended)

After installing a new kernel (before rebooting), you can verify the rebuild occurred:

```bash
sudo tail -200 /var/log/acer-wmi-battery-kernel-install.log
sudo dkms status | grep acer-wmi-battery
```

After rebooting into the new kernel:

```bash
uname -r
lsmod | grep acer_wmi_battery
```

If it is not loaded, try:

```bash
sudo modprobe acer_wmi_battery
```

#### Caveats

- **Missing headers/build tree:** if `/lib/modules/<kernel>/build` is not present at kernel install time, DKMS builds can fail. The Fedora/RHEL hook logs this; install the matching kernel headers/devel package and re-run `dkms build/install`.
- **Secure Boot:** if you enable Secure Boot, the module must be signed and the signing key must be enrolled (MOK).

   Fedora-specific notes:
   - DKMS signs modules using the key/certificate at `/var/lib/dkms/mok.key` and `/var/lib/dkms/mok.pub`.
     If you enrolled a different MOK certificate than the one DKMS is using, you may see errors like
     `Key was rejected by service`. Ensure the enrolled MOK matches DKMS' `mok.pub`, or update DKMS to
     use the enrolled key/cert.
   - Some systems also require trusting MOK keys for module loading:
     `sudo mokutil --trust-mok` then reboot.

   - Firmware/BIOS note: some systems require restoring default Secure Boot keys and/or marking Fedora's
     shim as trusted (e.g. an option like "Select an UEFI file as trusted for executing") if you see a
     "Security boot fail" screen after enabling Secure Boot.

     On some Acer/Insyde BIOS systems, Secure Boot options (including trusting an EFI file) may be hidden
     until a Supervisor password is set in BIOS/UEFI.

   - Dual-boot note: this Secure Boot flow has been validated on a Windows 11 + Fedora dual-boot system
     using the GRUB bootloader.

 - **SELinux / lockdown troubleshooting:** with Secure Boot enabled, `dmesg` access may be restricted even
   for root. Prefer `sudo journalctl -k -b` to inspect kernel messages.

### Module Loading

The playbook configures the module to be loaded automatically at boot time using multiple methods for maximum reliability:

1. **Kernel Module Configuration**: Adds the module to `/etc/modules-load.d/acer-wmi-battery.conf` to be loaded by the kernel module loading system.

2. **Systemd Service**: Creates a systemd service at `/etc/systemd/system/acer-wmi-battery.service` that loads the module after the system has fully booted, ensuring it's loaded even if the kernel module loading system fails.

This dual approach ensures that the module is loaded even if one method fails.

If the module is not automatically rebuilt after a kernel update, you can check its status using the provided utility:

```bash
acer-battery-status
```

This will show whether the module is loaded, the current battery health mode, and provide troubleshooting steps if needed.

You can also manually rebuild the module for your current kernel:

```bash
sudo dkms uninstall -m acer-wmi-battery -v main -k "$(uname -r)" || true
sudo dkms build -m acer-wmi-battery -v main -k "$(uname -r)"
sudo dkms install -m acer-wmi-battery -v main -k "$(uname -r)"
sudo modprobe acer_wmi_battery
```

You can also check the status of all DKMS modules:

```bash
sudo dkms status
```

## License

This playbook is licensed under the MIT License. The Acer WMI Battery module is licensed under the GPL-2.0 License.
