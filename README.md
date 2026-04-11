[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/JonahEMorgan/linux-utils)
[![CC BY NC ND](https://licensebuttons.net/l/by-nc-nd/4.0/88x31.png)](https://creativecommons.org/licenses/by-nc-nd/4.0)

# Personal Artix Installation

All of my custom configuration files are stored here in case something bad happens to my install.

---

Steps to install:
- Install ventoy onto a flash drive
- Place ISOs for artix, recovery tools, other OSs, etc on the Ventoy partition
- Clone this repo to the ventoy partition
- Boot the artix live cd and mount the ventoy partition
- Edit the install script for your specific hardware
- Call the install script with your desired username and password as arguments
- Wait for the install to complete, and if it hangs, then run the unmount script and try to fix your issue
- Reboot and run the post-install script