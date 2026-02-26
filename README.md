# Acer WMI Battery Ansible Role

[![Version](https://img.shields.io/badge/version-1.1.0-blue.svg)](https://github.com/yourusername/acer-battery-ansible/releases/tag/v1.1.0)

This Ansible role installs and configures the [Acer WMI Battery kernel module](https://github.com/frederik-h/acer-wmi-battery) for Acer laptops. The module enables battery threshold control on supported Acer laptops.

Note: multiple similarly named Acer battery/charge-limit projects exist online. This repository (role + examples)
specifically targets Frederik Himpe's upstream driver:
https://github.com/frederik-h/acer-wmi-battery

## TL;DR

Install (from this repo):

```bash
ansible-playbook -i localhost, -c local -K site.yml
```

Most common commands (once the module is loaded):

```bash
# Enable 80% charge limit
echo 1 | sudo tee /sys/bus/wmi/drivers/acer-wmi-battery/health_mode >/dev/null

# Disable 80% charge limit
echo 0 | sudo tee /sys/bus/wmi/drivers/acer-wmi-battery/health_mode >/dev/null

# Battery temperature (millidegree C)
cat /sys/bus/wmi/drivers/acer-wmi-battery/temperature
```

Portable example scripts (recommended):

```bash
# One-shot status dump of battery/power/temps
bash examples/battery_full_status.sh

# Read temperature with sysfs node auto-discovery
bash examples/battery_temperature.sh

# Toggle charge limit with sysfs node auto-discovery
sudo bash examples/charge_limit_on.sh
sudo bash examples/charge_limit_off.sh
```

If something fails to load/work (Secure Boot, missing sysfs nodes, etc.), jump to the Troubleshooting section.

These `examples/*.sh` scripts can be used even if you do not use this Ansible role, as long as the upstream
`frederik-h/acer-wmi-battery` module is installed and loaded and the expected sysfs nodes exist. The convenience
command `acer-battery-status` (and the `status` symlink) is installed by this role under `/usr/local/bin/`.

## About the Module

This role installs and configures the [acer-wmi-battery](https://github.com/frederik-h/acer-wmi-battery) kernel module, created by [Frederik Himpe](https://github.com/frederik-h). The module provides battery health control features for Acer laptops:

- **Health Mode**: Limits battery charging to 80% to preserve long-term battery capacity
- **Calibration Mode**: Enables battery capacity calibration for accurate capacity estimates
- **Battery Temperature**: Exposes battery temperature readings via sysfs

This Ansible role focuses solely on automating the installation and configuration of the upstream module. For module-specific issues or feature requests, please refer to the [upstream repository](https://github.com/frederik-h/acer-wmi-battery).

## Features

- Distribution-agnostic package management
- Automatic upstream repository updates
- DKMS integration for kernel updates
- Automatic module rebuilding when kernels are updated
- Boot-time module loading via systemd service (with DKMS self-healing)
- Comprehensive test suite
- Full idempotency support
- Automatic module signing for Secure Boot
- Works with or without SELinux (SELinux tools are optional)
- Source code integrity verification
- Automatic backup and recovery

## Battery Health Features

After installation, you can control the battery features through sysfs:

```bash
# Enable health mode (limit charging to 80%)
echo 1 | sudo tee /sys/bus/wmi/drivers/acer-wmi-battery/health_mode >/dev/null

# Disable health mode (allow full charging)
echo 0 | sudo tee /sys/bus/wmi/drivers/acer-wmi-battery/health_mode >/dev/null
```

The upstream driver also supports a battery **calibration mode**. This can take a long time and is recommended
only while connected to AC power. Start/stop it via sysfs:

```bash
# Start calibration
echo 1 | sudo tee /sys/bus/wmi/drivers/acer-wmi-battery/calibration_mode >/dev/null

# Stop calibration
echo 0 | sudo tee /sys/bus/wmi/drivers/acer-wmi-battery/calibration_mode >/dev/null
```

For the authoritative calibration procedure and caveats, see upstream:
https://github.com/frederik-h/acer-wmi-battery#calibration-mode

You can also read the battery temperature (in **millidegree Celsius**) via sysfs:

```bash
cat /sys/bus/wmi/drivers/acer-wmi-battery/temperature

# Convert to °C
awk '{ printf "%.1f°C\n", $1/1000 }' /sys/bus/wmi/drivers/acer-wmi-battery/temperature
```

Note: the exact sysfs path for `health_mode` can differ across laptop models and kernels. If the paths above do
not exist on your system, use the helper script in `examples/` to discover the correct node:

```bash
bash examples/find_health_mode_node.sh
```

If your system exposes the `temperature` node under a different sysfs path, you can discover it with:

```bash
bash examples/find_temperature_node.sh
```

These `find_*_node.sh` helpers first try a few common sysfs locations and then fall back to a broader scan under
`/sys` to improve portability across different kernel versions and laptop models.

If you prefer, you can use the helper scripts which automatically discover the correct node and write with sudo:

```bash
sudo bash examples/charge_limit_on.sh
sudo bash examples/charge_limit_off.sh
```

For temperature monitoring with automatic discovery:

```bash
bash examples/battery_temperature.sh
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
- Fixed DKMS Makefile generation so builds target the intended kernel (respects `KERNELRELEASE`) and avoid kernel-update autoinstall failures

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

## Development / Testing

This repository is primarily an Ansible role. The Python tooling is used for tests and linting.

The test suite is intended for development changes to the role and repository content (task files, templates,
packaging, and example script sanity checks such as shell syntax). It does **not** validate hardware-specific
behavior on your laptop.

For runtime issues (module not loading, missing sysfs nodes, Secure Boot issues, etc.), use the
Troubleshooting section below.

1. Create and activate a virtual environment:

```bash
uv venv
source .venv/bin/activate
```

2. Install Python dependencies:

```bash
uv pip install -r requirements.txt
```

3. Run linting and tests:

```bash
ruff check .
pytest
```

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

Note: while this role is intended to work across multiple Linux distributions, it has only been tested on Fedora so far.

### Prerequisites

- Ansible installed on your system
- A supported Acer laptop model (see [MODELS.md](https://github.com/frederik-h/acer-wmi-battery/blob/main/MODELS.md) in the repository)
- Sudo access (or equivalent privilege escalation). This role installs packages, writes into `/usr/src`, installs kernel hooks, and loads kernel modules, so it must be run with `become: true`.

### Why sudo/become is required

Most role actions require root privileges. Without sudo/become, you can only do limited read-only diagnostics.

The role needs sudo/become to:
- Install distribution packages (DKMS, kernel headers, build tooling)
- Write and manage files under `/usr/src`
- Run `dkms add/build/install/remove`
- Install kernel update hooks under `/etc/kernel/` and `/etc/kernel/install.d/`
- Configure automatic loading under systemd under `/etc/systemd/system/`
- Load the kernel module (`modprobe`)

Without sudo/become, you can still:
- Check whether the module is loaded (`lsmod | grep acer_wmi_battery`)
- Inspect DKMS state (`dkms status`)
- Inspect module metadata (`modinfo acer_wmi_battery`)

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

In normal use, you typically run this role once. After that, DKMS and the installed kernel update hooks should
automatically rebuild and install the module when a new kernel is installed. You only need to re-run the role
to upgrade/change configuration, rotate signing keys, or troubleshoot a broken installation.

### Controlling Battery Health Mode

Once the module is loaded successfully, you can control the battery health mode by writing to the following file:

```bash
echo 0 | sudo tee /sys/bus/wmi/drivers/acer-wmi-battery/health_mode >/dev/null  # Standard Mode (100% charging)
echo 1 | sudo tee /sys/bus/wmi/drivers/acer-wmi-battery/health_mode >/dev/null  # Battery Health Mode (80% charging limit)
```

Note: avoid `sudo echo 1 > /sys/.../health_mode` because the shell redirection (`>`) runs as your user and will
usually fail with "Permission denied". Use `sudo tee` (as shown above) or the helper scripts in `examples/`.

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

# Battery temperature (millidegree Celsius) + display in °C
alias battery_temp_raw='cat /sys/bus/wmi/drivers/acer-wmi-battery/temperature'
alias battery_temp='awk "{ printf \"%.1f°C\\n\", \$1/1000 }" /sys/bus/wmi/drivers/acer-wmi-battery/temperature'
```

This repository also provides small helper scripts that automatically discover the correct sysfs node:

```bash
sudo bash examples/charge_limit_on.sh
sudo bash examples/charge_limit_off.sh
```

If you want to see which sysfs node was detected on your system:

```bash
bash examples/find_health_mode_node.sh
```

#### Example scripts

The `examples/` directory contains portable scripts that work with the upstream
`frederik-h/acer-wmi-battery` driver even if you do not use this Ansible role.

Full documentation (dependencies, sudo requirements, installing into `PATH`, sample output):

examples/README.md

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

Why this is needed: `acer-wmi-battery` is an out-of-tree kernel module. Kernel modules are built against a
specific kernel build/ABI (and its headers). After a kernel update, the previously built `.ko` may no longer
match the running kernel ("version magic" mismatch) and can fail to load, so it must be rebuilt for the new
kernel.

Additionally, it installs OS-specific hooks as a fallback:

- Debian/Ubuntu: `/etc/kernel/postinst.d/99-acer-wmi-battery`
- Fedora/RHEL: `/etc/kernel/install.d/90-acer-wmi-battery.install`

On Fedora/RHEL, the hook logs to:

`/var/log/acer-wmi-battery-kernel-install.log`

This provides two layers of protection:
1. Standard DKMS automatic rebuilding
2. Custom kernel post-install hook as a fallback

After a kernel update, the module should be automatically rebuilt and loaded when you boot into the new kernel.

### Fedora release upgrades (DNF system-upgrade / GNOME/KDE Software)

Fedora version upgrades typically install a new kernel and update DKMS/build tooling. In most cases the module will
continue to work because:

- DKMS will rebuild the module for newly installed kernels
- This role also installs a Fedora/RHEL `kernel-install` hook as a fallback

However, major upgrades are more disruptive than normal kernel updates. Manual steps may be required if:

- DKMS/build dependencies were removed or changed during the upgrade
- Secure Boot state or enrolled keys changed (see the Secure Boot + BIOS section below)

Recommended checklist after completing the Fedora upgrade and rebooting:

```bash
uname -r
sudo dkms status | grep acer-wmi-battery
lsmod | grep acer_wmi_battery
status
```

If the module is not loaded:

1. Try loading it once:

```bash
sudo modprobe -v acer_wmi_battery
```

2. If you see `Key was rejected by service`, follow the Secure Boot recovery steps (MOK re-enrollment).

3. Otherwise (build/tooling issue), the recommended recovery is to re-run the role:

```bash
ansible-playbook -i localhost, -c local -K site.yml
```

On Fedora/RHEL, also check the kernel hook log to confirm the rebuild ran during the upgrade:

```bash
sudo tail -200 /var/log/acer-wmi-battery-kernel-install.log
```

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

#### Secure Boot + BIOS updates: module suddenly stops loading

If you recently performed a BIOS/UEFI update (common on dual-boot systems via Windows tools) and the module stopped working after reboot, Secure Boot may now be rejecting the kernel module signature.

Typical symptoms:

- The `status` command says the module is not loaded
- `sudo modprobe acer_wmi_battery` fails with:
  `Key was rejected by service`

Why it happens:

- Some BIOS/UEFI updates reset or change Secure Boot databases / enrolled keys.
- When Secure Boot is enabled, the kernel will refuse to load a DKMS module unless it is signed with a key that is enrolled (MOK).

Recovery (recommended):

1. Re-run this role (it will ensure the enrollment certificate exists at `/var/lib/dkms/mok.der`):

```bash
ansible-playbook -i localhost, -c local -K site.yml
```

2. Import the certificate for enrollment and reboot:

```bash
sudo mokutil --import /var/lib/dkms/mok.der
sudo reboot
```

3. At boot you will see the **MOK Manager** screen:

- Choose **Enroll MOK**
- Choose **Continue**
- Enter the one-time password you set during `mokutil --import`
- Reboot when prompted

4. Verify the module now loads:

```bash
sudo modprobe -v acer_wmi_battery
lsmod | grep acer_wmi_battery
status
```

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

#### Manual recovery: rebuild via Ansible

If a kernel update was installed but the module was not rebuilt before shutdown/reboot (or if the module fails
to load after boot), the recommended recovery path is to re-run this role with `become` enabled.

From the repository root:

```bash
ansible-playbook -i localhost, -c local -K site.yml
```

If you want to explicitly force a rebuild/install for the running kernel in the same run:

```bash
ansible-playbook -i localhost, -c local -K site.yml \
  -e acer_battery_force_rebuild_current_kernel=true
```

After the play completes:

```bash
sudo dkms status | grep acer-wmi-battery
sudo modprobe -v acer_wmi_battery
```

On Fedora/RHEL, you can also inspect the kernel-update hook log to see whether the DKMS rebuild happened at
kernel install time:

```bash
sudo tail -200 /var/log/acer-wmi-battery-kernel-install.log
```

### Module Loading

The playbook configures the module to be loaded automatically at boot time using a dedicated systemd oneshot service:

1. **Systemd Service**: Installs `/etc/systemd/system/acer-wmi-battery.service`, which attempts to `modprobe` the module and, if that fails, rebuilds/reinstalls it for the running kernel using DKMS and retries.

This approach is intentionally used instead of `/etc/modules-load.d/` because early-boot module loading can hit stale DKMS artifacts after kernel updates (e.g., an `Exec format error` due to a vermagic mismatch). The systemd service runs later in boot and includes self-healing logic.

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
