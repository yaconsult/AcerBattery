# Changelog

## Recent changes

### Fixed (project analysis review)
- Fixed module existence check using wrong hardcoded path (`/updates/dkms/`); now uses dynamic `find` to locate the module regardless of distro layout.
- Fixed hardcoded `-v main` in Load module task; now uses `{{ acer_battery_version }}` consistently.
- Fixed handlers (`rebuild_module`, `load_module`) missing `become: true` for privilege escalation.
- Fixed DKMS `MAKE` directive to explicitly pass `KERNELRELEASE=${kernelver}` to avoid `uname -r` fallback during cross-kernel builds.
- Fixed `sign-modules.sh.j2` using hardcoded `/var/lib/dkms/mok.*` paths; now uses `{{ acer_battery_mok_key }}` and `{{ acer_battery_mok_pub }}` template variables.
- Fixed `kernel-postinst.j2` silently swallowing build/install failures; now logs warnings on error while still exiting 0 to not block kernel installs.
- Fixed version inconsistencies across `galaxy.yml` (1.2.0), `pyproject.toml` (was 1.0.0), and README badge (was 1.1.0); all now 1.2.0.

### Removed
- Removed stale root-level `acer-wmi-battery.service` and `99-acer-wmi-battery` (authoritative versions live in `templates/`).
- Removed orphaned `modules-load.conf.j2` template (no longer used since switch to systemd service).
- Removed dead `Get real home directory` task (registered variable was never used).
- Removed stale `[coverage:run]` and `[coverage:report]` sections from `tests/ansible.cfg` (belong in `pyproject.toml`).

### Changed
- Renamed `/usr/local/bin/status` symlink to `/usr/local/bin/acer-status` to avoid namespace collisions.
- Renamed handlers to use uppercase names with `listen:` directives for ansible-lint compliance (production profile).
- Added `set -o pipefail`, `changed_when`, and `failed_when` to handlers for ansible-lint safety compliance.
- Added 11 new regression tests covering all fixes above; test suite now at 27 tests.

### Previous
- Example scripts now show time-to-full / time-to-empty (ETA) when available, with a derived fallback estimate.
- Added portable example docs under `examples/README.md` and shortened the root README accordingly.
- Added calibration mode helpers (`calibration_mode.sh` + `find_calibration_mode_node.sh`) with safe defaults and documentation.
- Added read-only utility examples:
  - `watch_battery_status.sh` (refreshing terminal view)
  - `battery_history_logger.sh` (CSV/TSV logger)
- Documented ways to fetch only the `examples/` folder (ZIP download, sparse-checkout, `svn export`).
- Improved boot-time module load robustness by relying on `acer-wmi-battery.service` (self-healing DKMS rebuild/retry) instead of early-boot `/etc/modules-load.d`.
- Fixed DKMS Makefile generation so kernel updates build/install correctly for the new kernel (respects `KERNELRELEASE`).

## [1.2.0] - 2026-01-28

### Added
- Added one-liner examples and helper scripts to enable/disable charge limiting via `health_mode`
- Added a Fedora/RHEL `kernel-install` hook to rebuild/install the DKMS module on kernel updates
- Added an optional `ANSIBLE-MANAGED.txt` marker file with key paths, hook paths, and troubleshooting hints

### Changed
- Improved Secure Boot/MOK handling to use the enrolled key material consistently (PEM for signing + DER for enrollment)
- Made DKMS force rebuild for the current kernel opt-in
- Improved lockdown-friendly diagnostics by preferring `journalctl` where appropriate
- Updated Ansible Galaxy metadata URLs to point to the correct repository

### Fixed
- Silenced pytest-asyncio loop-scope deprecation warnings via explicit configuration
- Removed default pytest coverage settings that produced “no data collected” warnings for this repo

## [1.1.0] - 2025-04-02

### Added
- Added support for Fedora and other RedHat-based distributions
- Added detailed debugging information for module loading
- Added comprehensive troubleshooting instructions
- Added better error handling throughout the playbook

### Changed
- Updated repository URL to use the maintained fork at frederik-h/acer-wmi-battery
- Improved git update task to handle non-git repositories
- Updated the health_mode path to the correct location
- Enhanced documentation with more detailed instructions

### Fixed
- Fixed module loading by using the correct module name (acer_wmi_battery)
- Fixed package installation for Fedora systems
- Fixed repository access issues by using HTTPS instead of SSH
- Fixed module verification script path

## [1.0.0] - Initial Release

### Added
- Initial release of the Acer WMI Battery Ansible playbook
- Support for Debian-based distributions
- DKMS integration for kernel updates
- Module autoloading configuration
- Secure Boot support with module signing
