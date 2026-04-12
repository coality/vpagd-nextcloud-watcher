# vpagd-nextcloud-watcher

Watch Nextcloud directories for `.vpagd` files and automatically convert them to `.odt` format with French localized filenames.

## Project Overview

This project monitors a Nextcloud source directory for `.vpagd` files (which follow the naming convention `YYYY.MM.DD.vpagd`) and automatically converts them to `.odt` files using the external [vpagd2odt](https://github.com/coality/vpagd2odt) conversion tool.

The converted files are written to a target directory with French locale naming:
`Messe du dimanche 08 Mars 2026.odt`

## Features

- **Recursive monitoring**: Watches the source directory and all subdirectories
- **Automatic conversion**: Detects new and modified `.vpagd` files and converts them automatically
- **French localized output**: Generates French-formatted filenames with proper capitalization
- **Systemd service**: Runs as a system service for reliability
- **Configuration-driven**: All paths are configurable via a config file
- **Comprehensive logging**: Detailed logs for troubleshooting
- **Defensive code**: Strict error handling and validation
- **Testable structure**: Unit and integration tests included

## Requirements

### System Requirements

- Linux kernel with `inotify` support
- `bash` version 4.0 or higher
- `inotify-tools` package (provides `inotifywait`)
- `vpagd2odt` conversion tool

### External Dependency: vpagd2odt

This project depends on **vpagd2odt**, an external project available at:
https://github.com/coality/vpagd2odt

#### Installation of vpagd2odt

The `install.sh` script will automatically install `vpagd2odt` if it is not found. Alternatively, you can use the update script directly:

```bash
# Initial installation or update
./install_vpagd2odt.sh

# Check for updates
./install_vpagd2odt.sh --check
```

For manual installation, see the [vpagd2odt repository](https://github.com/coality/vpagd2odt).

### Required packages

**Debian/Ubuntu:**
```bash
sudo apt-get install inotify-tools
```

**Fedora/RHEL:**
```bash
sudo dnf install inotify-tools
```

**Arch Linux:**
```bash
sudo pacman -S inotify-tools
```

**openSUSE:**
```bash
sudo zypper install inotify-tools
```

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/yourusername/vpagd-nextcloud-watcher.git
cd vpagd-nextcloud-watcher
```

### 2. Run the installer

The installer checks prerequisites and guides you through setup. If `vpagd2odt` is not found, it will offer to install it automatically:

```bash
./install.sh
```

Or specify a custom installation path for vpagd2odt:

```bash
./install.sh /opt/bin
```

The installer will:
1. Check that prerequisites are installed (inotify-tools)
2. Check if vpagd2odt is installed, offer to install it if not
3. Create necessary directories
4. Verify project files are present

### 3. Create the configuration file

```bash
cp config/vpagd-nextcloud-watcher.conf.example config/vpagd-nextcloud-watcher.conf
```

### 4. Edit the configuration

Open the config file and set your paths:

```bash
nano config/vpagd-nextcloud-watcher.conf
```

Example configuration:

```ini
SOURCE_DIR="/path/to/nextcloud/vpagd"
TARGET_DIR="/path/to/output/odt"
VPAGD2ODT_BIN="/home/username/bin/vpagd2odt"
LOG_FILE="/home/username/vpagd-nextcloud-watcher/vpagd-watcher.log"
LOG_LEVEL="INFO"
```

### 5. Create directories

Ensure the source and target directories exist:

```bash
mkdir -p /path/to/nextcloud/vpagd
mkdir -p /path/to/output/odt
```

### 6. Make the script executable

```bash
chmod +x watch_vpagd.sh
```

## Configuration

All configuration is done via the `config/vpagd-nextcloud-watcher.conf` file.

| Parameter | Required | Description |
|-----------|----------|-------------|
| `SOURCE_DIR` | Yes | Path to the Nextcloud directory to watch for `.vpagd` files |
| `TARGET_DIR` | Yes | Path to the directory where `.odt` files will be written |
| `VPAGD2ODT_BIN` | Yes | Full path to the vpagd2odt binary |
| `LOG_FILE` | No | Path to the log file (default: `./vpagd-watcher.log`) |
| `LOG_LEVEL` | No | Log level: `DEBUG`, `INFO`, `WARN`, `ERROR` (default: `INFO`) |
| `LOCALE` | No | Output locale: `fr` for French, `en` for English (default: `fr`) |
| `NEXTCLOUD_OCC` | No | Path to Nextcloud occ command (e.g., `/var/www/nextcloud/occ`) |
| `NEXTCLOUD_USER` | No | Nextcloud username whose directory will be rescanned |

### Configuration file format

```ini
# Source directory to watch (recursively)
SOURCE_DIR="/path/to/nextcloud/vpagd"

# Target directory for converted .odt files
TARGET_DIR="/path/to/output/odt"

# Path to vpagd2odt binary
VPAGD2ODT_BIN="/home/user/bin/vpagd2odt"

# Log file location
LOG_FILE="/home/user/vpagd-nextcloud-watcher/vpagd-watcher.log"

# Log level: DEBUG, INFO, WARN, ERROR
LOG_LEVEL="INFO"

# Output locale: fr (French) or en (English)
LOCALE="fr"

# Nextcloud occ command (optional, for file indexing)
NEXTCLOUD_OCC="/var/www/nextcloud/occ"
NEXTCLOUD_USER="username"
```

## How to Use

### Basic Usage

Run the watcher manually for testing:

```bash
./watch_vpagd.sh
```

Or with a custom config file:

```bash
./watch_vpagd.sh -c /path/to/custom/config.conf
```

### Running as a System Service

#### Install the systemd service

Copy the service file to systemd directory:

```bash
sudo cp systemd/vpagd-nextcloud-watcher.service /etc/systemd/system/
```

Reload systemd to recognize the new service:

```bash
sudo systemctl daemon-reload
```

#### Start the service

```bash
sudo systemctl start vpagd-nextcloud-watcher
```

#### Enable on boot

To start the service automatically at boot:

```bash
sudo systemctl enable vpagd-nextcloud-watcher
```

#### Check service status

```bash
sudo systemctl status vpagd-nextcloud-watcher
```

#### View logs

```bash
sudo journalctl -u vpagd-nextcloud-watcher -f
```

#### Stop the service

```bash
sudo systemctl stop vpagd-nextcloud-watcher
```

#### Restart the service

```bash
sudo systemctl restart vpagd-nextcloud-watcher
```

### Running as a User Service

For a user-level service (no root required):

1. Copy the service file to user directory:
```bash
mkdir -p ~/.config/systemd/user
cp systemd/vpagd-nextcloud-watcher.service ~/.config/systemd/user/
```

2. Edit the service file to set correct paths. Update these lines:
```ini
WorkingDirectory=%h/vpagd-nextcloud-watcher
ExecStart=%h/vpagd-nextcloud-watcher/watch_vpagd.sh
Environment=CONFIG_FILE=%h/vpagd-nextcloud-watcher/config/vpagd-nextcloud-watcher.conf
```

3. Enable linger for the user (allows user services to start at boot):
```bash
sudo loginctl enable-linger $USER
```

4. Start the user service:
```bash
systemctl --user start vpagd-nextcloud-watcher
```

5. Enable at boot:
```bash
systemctl --user enable vpagd-nextcloud-watcher
```

### Testing the Installation

1. Create a test `.vpagd` file:
```bash
touch /path/to/nextcloud/vpagd/2026.03.08.vpagd
```

2. Wait a moment for the conversion

3. Check for the output file:
```bash
ls -la /path/to/output/odt/
```

4. You should see:
```
Messe du dimanche 08 Mars 2026.odt
```

## Localization

The output filename locale is configurable via the `LOCALE` setting.

### Supported locales

| Locale | Description | Example output |
|--------|-------------|----------------|
| `fr` | French (default) | `Messe du dimanche 08 Mars 2026.odt` |
| `en` | English | `Sunday Mass 08 March 2026.odt` |

### Changing the locale

Edit your config file and set:
```ini
LOCALE="en"
```

Then restart the service:
```bash
sudo systemctl restart vpagd-nextcloud-watcher
```

### Locale formatting rules

The day of week is calculated from the date in the filename.

**French (`fr`):**
- Format: `Messe du <jour> <jour> <mois> <année>.odt`
- Example: `Messe du samedi 07 Mars 2026.odt`
- Day name is lowercase, month name is capitalized

**English (`en`):**
- Format: `<Day> Mass <day> <month> <year>.odt`
- Example: `Saturday Mass 07 March 2026.odt`
- Day name is lowercase, month name is capitalized

## Nextcloud Integration

After each conversion, the watcher can scan the user's Nextcloud directory to ensure the new `.odt` file is indexed and visible in the Nextcloud web interface.

### How it works

When `NEXTCLOUD_OCC` and `NEXTCLOUD_USER` are configured, the watcher runs:
```bash
occ files:scan <username>
```

This rescans the entire Nextcloud directory for the specified user.

### Configuration

```ini
NEXTCLOUD_OCC="/var/www/nextcloud/occ"
NEXTCLOUD_USER="username"
```

### Requirements

- The Nextcloud installation path must be correct
- The user running the watcher must have permission to execute `occ`
- Typically, the service runs as root or as the Nextcloud user (e.g., `www-data`)

## Systemd Usage

### Service File Location

- System-wide: `/etc/systemd/system/vpagd-nextcloud-watcher.service`
- User-level: `~/.config/systemd/user/vpagd-nextcloud-watcher.service`

### Service Management Commands

| Action | System-wide | User-level |
|--------|-------------|------------|
| Start | `sudo systemctl start vpagd-nextcloud-watcher` | `systemctl --user start vpagd-nextcloud-watcher` |
| Stop | `sudo systemctl stop vpagd-nextcloud-watcher` | `systemctl --user stop vpagd-nextcloud-watcher` |
| Restart | `sudo systemctl restart vpagd-nextcloud-watcher` | `systemctl --user restart vpagd-nextcloud-watcher` |
| Status | `sudo systemctl status vpagd-nextcloud-watcher` | `systemctl --user status vpagd-nextcloud-watcher` |
| Enable | `sudo systemctl enable vpagd-nextcloud-watcher` | `systemctl --user enable vpagd-nextcloud-watcher` |
| Disable | `sudo systemctl disable vpagd-nextcloud-watcher` | `systemctl --user disable vpagd-nextcloud-watcher` |
| View logs | `sudo journalctl -u vpagd-nextcloud-watcher -f` | `journalctl --user -u vpagd-nextcloud-watcher -f` |

## Logs and Troubleshooting

### Log File Location

Logs are written to the file specified in `LOG_FILE` in your configuration. Default location when running manually is `./vpagd-watcher.log`.

### Log Levels

- `DEBUG`: Detailed information for debugging
- `INFO`: General operational information
- `WARN`: Warning messages (non-critical issues)
- `ERROR`: Error messages (critical issues)

### Viewing Logs

**When running manually:**
```bash
tail -f vpagd-watcher.log
```

**When running as systemd service:**
```bash
sudo journalctl -u vpagd-nextcloud-watcher -f
```

### Common Issues

#### "Config file not found"

Ensure the config file exists at the expected path:
```bash
ls -la config/vpagd-nextcloud-watcher.conf
```

#### "inotifywait not found"

Install inotify-tools:
```bash
sudo apt-get install inotify-tools
```

#### "VPAGD2ODT_BIN is not executable"

Check the binary exists and has execute permissions:
```bash
ls -la /path/to/vpagd2odt
chmod +x /path/to/vpagd2odt
```

#### "No files being converted"

1. Check the source directory contains `.vpagd` files
2. Verify filename format: `YYYY.MM.DD.vpagd` (e.g., `2026.03.08.vpagd`)
3. Check logs for warnings about invalid filenames
4. Ensure the watcher is actually running

#### Service fails to start

Check the service status:
```bash
sudo systemctl status vpagd-nextcloud-watcher
```

View detailed logs:
```bash
sudo journalctl -u vpagd-nextcloud-watcher -xe
```

## Testing

### Test Structure

The project includes a comprehensive test suite:

```
tests/
├── test_helper.sh              # Shared test utilities
├── run_tests.sh                # Test runner script
├── unit/
│   ├── test_date_conversion.sh      # Date conversion and French formatting tests
│   ├── test_filename_validation.sh  # Filename validation tests
│   ├── test_config_parsing.sh       # Config file parsing tests
│   └── test_conversion.sh            # Conversion functionality tests
└── integration/
    └── test_watch_integration.sh    # End-to-end watcher tests
```

### Running Tests

**Run all tests:**
```bash
./tests/run_tests.sh
```

**Run unit tests only:**
```bash
./tests/run_tests.sh unit
```

**Run integration tests only:**
```bash
./tests/run_tests.sh integration
```

### Test Requirements

- Unit tests require only `bash` and standard utilities
- Integration tests require `inotify-tools` (inotifywait)
- Tests create temporary directories in `tests/tmp/`

### Test Coverage

The test suite covers:

- **Filename validation**: Correct format `YYYY.MM.DD.vpagd`
- **Date extraction**: Year, month, day parsing from filenames
- **French date formatting**: Correct month names and capitalization
- **Config file parsing**: Key-value extraction, comments, whitespace
- **Conversion**: Output file creation, overwrite behavior
- **Watcher behavior**: New file detection, subdirectory support, regeneration

## Updating vpagd2odt

Since vpagd2odt is an external dependency, you may need to update it when new versions are released with bug fixes or new features.

### Using the update script

The project includes an `install_vpagd2odt.sh` script to help keep vpagd2odt up to date.

**Check for updates:**
```bash
./install_vpagd2odt.sh --check
```

**Update to the latest version:**
```bash
./install_vpagd2odt.sh
```

**Specify a custom installation directory:**
```bash
./install_vpagd2odt.sh --dir /opt/bin
```

### Update options

| Option | Description |
|--------|-------------|
| `-d, --dir PATH` | Installation directory (default: ~/bin) |
| `-b, --bin NAME` | Binary name (default: vpagd2odt) |
| `-c, --check` | Check for updates without installing |
| `-h, --help` | Show help message |

### Manual update

To manually update vpagd2odt:

1. Visit https://github.com/coality/vpagd2odt/releases
2. Download the latest release for your platform
3. Replace the existing binary in your installation directory
4. Restart the watcher service if it was running

## Limitations

### Known Limitations

1. **Filename format is strict**: Only `YYYY.MM.DD.vpagd` format is accepted. Other formats are silently ignored.

2. **Month/day validation is basic**: The code validates month (01-12) and day (01-31) ranges but does not validate actual calendar validity (e.g., it accepts `2026.02.30.vpagd`).

3. **Single conversion at a time**: The watcher processes files sequentially. High-volume scenarios might need modification.

4. **No file deletion handling**: If a `.vpagd` file is deleted, the corresponding `.odt` is not automatically removed.

5. **Requires filesystem support**: The service requires a filesystem that supports inotify events. Network filesystems (NFS, certain cloud mounts) may not work reliably.

6. **vpagd2odt must be reliable**: This project depends on vpagd2odt for the actual conversion. Any issues with that tool will affect this watcher.

### Expected Behavior

- Files matching the pattern are converted
- Files not matching the pattern are silently ignored (logged at DEBUG level)
- Modified files trigger re-conversion and overwrite the existing `.odt`
- The `.odt` file is always written directly to the target directory (not to subdirectories)

## License

This project is released under the MIT License. See the [LICENSE](LICENSE) file for details.
