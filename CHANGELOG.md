# Changelog

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
