# Battery Monitor and Smart Device Control 🔋

This project is a PowerShell script designed to monitor the battery levels of a Windows laptop and control a smart device (like a plug or switch) via `Tuya's API` based on the battery charge state. The script can automatically turn the smart device on or off depending on the battery level, helping to preserve the battery health of your laptop by charging optimally.

Note: `Smart Life`, `TCP` and many other devices will also work under Tuya API.

## Features ✨

- **Battery Level Monitoring**: Continuously monitors the battery level of the device.
- **Smart Device Control**: Turns a smart device on or off based on predefined battery level thresholds.
- **Automatic Task Scheduling**: Sets up scheduled tasks to run the script periodically and during system shutdown events.
- **Configuration Management**: Easily configurable settings stored in `config.ini`.

## Requirements 🛠️

- Windows 10/11 operating system.
- An approved smart device that is controlled via Tuya's API.

## Approved Devices ✅

- **EIGHTREE Smart Plug**: [Available Here](https://amzn.to/4cmppw0)
- **RENO SUPPLIES Smart Plug**: [Available Here](https://amzn.to/4dJxDzl)
- **GNCC Mini Smart Plug**: [Available Here](https://amzn.to/3X5EwWo)
- **WISEBOT Mini Smart Plug**: [Available Here](https://amzn.to/3AzdUUC)
...and many more.

## Installation 🚀

### Step 1: Download and Extract

1. Download the script files.
2. Extract the contents to a folder on your Windows machine.

### Step 2: Configure the Script

1. Open the `config.ini` file created by the script.
2. Update the configuration settings as needed:
  - **BATTERY_HIGH**: The battery percentage above which the device should be turned off (default: 80 percent).
  - **BATTERY_LOW**: The battery percentage below which the device should be turned on (default: 20 percent).
  - **tokenExpiry**: The number of days before the token expires and needs to be refreshed (default: 10 days).
  - **idExpiry**: The number of minutes before the device ID expires and needs to be refreshed (default: 17 minutes).
  - **loopTime**: The interval between each check of the battery status (default: 600 seconds).
  - **wifiName**: The SSID of the Wi-Fi network that the script will monitor (default: SSID).
  - **deviceName**: The name of the device to control (default: DEVICENAME).
  - **userName**: Your Tuya account username (default: email@domain.com).
  - **password**: Your Tuya account password (default: password).
  - **countryCode**: The country code for your Tuya account (default: us).
  - **bizType**: The business type for Tuya (default: smart_life).
  - **from**: The source from which the request is being made (default: tuya).

### Step 3: Install

Run the `install.bat` file as an administrator to create and configure the necessary tasks.

This script will:
  - Create necessary configuration files.
  - Schedule tasks to run the PowerShell script at startup and during sleep events.
  - Register the script in the Group Policy for shutdown events.

## Usage 📖

After successful install, the script will run automatically according to the configured intervals. It will control the smart device based on the battery levels as specified in config.ini.

## Logging 📄

The script logs its activity under a logs folder with timestamps, helping you track its actions and any potential errors.

## Uninstallation 🗑️

Run the `uninstall.bat` file as an administrator to remove all configurations and tasks.

This script will:
  - Delete the scheduled tasks created by the installation.
  - Remove the script from Group Policy shutdown events.
  - Clean up any related configuration files.

## Troubleshooting 🛠️

- Ensure that your Wi-Fi SSID name is correctly specified in `config.ini`.
- Make sure that the smart device name matches the one used in your Tuya app.
- Check the logs for any error messages if the script is not functioning as expected.

## License

This project is licensed under the MIT License.
