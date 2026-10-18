# OpenCore Bootlinuxer

**Install OpenCore as a graphical bootloader on Linux (UEFI + GRUB)**

by BecabDev - made with <3 in Cannes

<img width="1101" height="648" alt="image" src="https://github.com/user-attachments/assets/bf89d7e5-19cc-4d3b-9d53-b192758db7a2" />


## Features

- installs or updates the latest [OpenCore](https://github.com/acidanthera/OpenCorePkg) release with the OpenCanopy gui
- imports grub entries into the OpenCore picker (hide, reorder, group in a subfolder, change logos, live preview)
- Grub hook so the entry picked in OpenCore boots directly
- Customization : timeout, picker, theme, mouse, resolution, UI scale
- Esp backup and full, verified uninstall (restores boot order, EFI BOOT, NVRAM)
- i18n : english and french

## Requirements

- Linux booted in UEFI mode, with grub (grubx64.efi on the ESP)
- Root access and Python3 with `curses`
- Secure Boot disabled in the firmware

## Usage

```bash
git clone https://github.com/becabdev/opencore-bootlinuxer bootlinuxer
cd bootlinuxer
chmod +x opencore-bootlinuxer.sh
sudo ./opencore-bootlinuxer.sh
```
## Notes

- backups and state are stored in /var/lib/opencore-bootlinuxer
- System detected automatically OpenCore (likes Windows) cant be edited from the preview
- systemd boot is not supported (grub only, but will be supported in the future).
- As always, there is a risk that it may cause your computer not to boot so keep a fresh copy of your distro installer on a usb stick
- Have fun !

## Credits

[OpenCorePkg](https://github.com/acidanthera/OpenCorePkg), [OcBinaryData](https://github.com/acidanthera/OcBinaryData) by Acidanthera.
