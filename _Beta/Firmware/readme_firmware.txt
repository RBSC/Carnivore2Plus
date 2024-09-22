--------------------------------------------------------------------------------
Carnivore2+ MultiFunctional Cartridge
Copyright (c) 2024 RBSC
Portions (c) Mitsutaka Okazaki
Portions (c) Kazuhiro Tsujikawa
Portions (c) Jose Tejada

ROMs are copyright by their respective owners. See readme file in BIOSes folder

Last updated: 28.07.2024
--------------------------------------------------------------------------------

The Altera firmware was created by RBSC. Commercial usage is not allowed!

IMPORTANT!
----------
Please note that for Carnivore2+ there are several variants of one and the same
firmware. The initial release contains the firmware with FMPAC (MSX Music) and
SFG-05 music modules. These firmwares have the same version - 3.01. To be able
to flash the selected firmware into the cartridge, the C2FWUPD utility should
be used.

When started, the utility offers either to backup the existing firmware and the
music module BIOS onto the disk or to upload the one of the available firmwares
and music module's BIOSes. When the backup option is selected, the utility will
copy the firmware onto the disk as FIRMWARE.BIN, create a file with CRC named
FIRMWARE.CRC and also copy the music module's BIOS as FIRMWARE.ROM. It will be
later possible to write this backed up data back into the cartridge.

When the firmware updating is selected, it's possible to either to upload the
previously made backup into the cartridge or to upload one of the available
firmwares and music module's BIOSes:

 - MSX Music (FMPAC) firmware and BIOS
 - SFG-05 FM firmware and BIOS
 - MSX Audio firmware and BIOS

Later, more firmware versions may become available. Each firmware set consists
of a BIN, CRC and ROM file. Please do not edit or delete any of those files!

To start using the newly-uploaded firmware and BIOS please power off your computer
and then power it on again.


IMPORTANT!
----------
Each firmware with a Music Module (FMPAC, SFG, MSX Audio, etc.) requires the BIOS
of that Music Module to be written into the cartridge. This is normally done
by the C2FWUPD utility. But in case updating the music module's BIOS fails, this
needs to be done manually with the help of C2MAN or C2MAN40 utility.

The procedure is as follows:

 - Copy all BIN files from "BIOSes" folder to a new folder
 - Copy C2MAN or C2MAN40 utility into the same folder
 - Run the utility and enter the Service Menu by pressing 9
 - Press 6 to update the Music Module's BIOS
 - Select the appropriate BIOS and confirm updating
 - Reboot your computer

The FMPAC (MSX Music) music module requires the FMPCCMFC.BIN file to be flashed.
The SFG-05 music module requires the SFGMCMFC.BIN file to be flashed into the
cartridge. If you don't flash the appropriate music module's BIOS after changing
the firmware, music players and games may fail to recognize the newly-installed
music module and will not play the music properly.

To identify which music module is currently available in the firmware, look for
the name of this module under the firmware version in the startup screen of
Carnivore2+ cartridge.


IMPORTANT!
----------
In case the firmware update fails and the cartridge no longer works, it's still
possible to restore it without USB Blaster. You can use Carnivore2 or another
cartridge that boots to DOS to run the C2FWUPD utility and try to update the
firmware once again. If the bricked Carnivore2+ cartridge doesn't allow other
cartridges to boot, put a strong magnet near the upper right corner of the cartridge
case until the SD LED lights up and reboot a system. The magnet will activate the
special switch that disables the bricked cartridge and allows to boot from other
devices. Remove the magnet once the other device boots to DOS.

If it's not possible to update the firmware with the C2FWUPD utility from an MSX
computer, it's still possible to use the USB Blaster programmer to directly upload
the POF file into the EPCS4 chip on the cartridge's board. Please refer to the user
manual on how to update the firmware with USB Blaster. The POF file can be found
in the "Backup" folder.
