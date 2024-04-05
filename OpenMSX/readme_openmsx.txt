--------------------------------------------------------------------------------
Carnivore2+ MultiFunctional Cartridge
Copyright (c) 2024 RBSC
--------------------------------------------------------------------------------

OpenMSX supports the emulation of the Carnivore2/2+ cartridge since build 0_14_0-200:

https://openmsx.vampier.net

OpenMSX support for Carnivore2/2++
----------------------------------

To add Carnivore2+ device into OpenMSX please do the following:

1. Put "Carnivore2+.xml" file into this folder: ..\openMSX\share\extensions\
2. Put "Carnivore2+.rom" file into this folder: ..\openMSX\share\systemroms\other\
3. Run "openMSX Catapult", select "Settings", click "Edit configuration" and "OK"

The device called "Carnivore2+" will appear in the list of found devices. You can then attach a disk image to Carnivore2+
by specifying the location of the DSK file (your own CF card's image) in the Catapult's user interface. Click on the
"Hard Disk" button and locate the desired image file.

If you already have Carnivore2+ in your OpenMSX and you only want to update the FlashROM, you may copy the "Carnivore2+.rom"
file into this folder as "Carnivore2+.flash":

C:\Users\<user_name>\Documents\openMSX\persistent\Carnivore2+\untitled1\

where <user_name> is your Windows user name. Please be advised that all your previous data on the FlashROM will be gone!
So if you want to preserve the data, but to have the latest Boot Menu and IDE BIOS versions, you need to run OpenMSX, boot
to MSX-DOS and use the dedicated "C2MAN" or "C2MAN40" utility to update the Boot Menu and SD and IDE BIOSes using the
latest BIN files from the Carnivore's Github repository:

https://github.com/RBSC/Carnivore2Plus

With "Carnivore2+.xml" Carnivore2+ cartridge can be located in any unused slot. However, if you want to use the cartridge in
slots 1 or 2, there are 2 additional XML files - "Carnivore2+Slot1.xml" and "Carnivore2+Slot2.xml". This way you can use
Carnivore2+ in either slot 1 or slot 2, as well as in both slots. Copying these XML files to OpenMSX is similar to copying
"Carnivore2+.xml" that is descrived above.


IMPORTANT!
----------

Certain features of Boot Menu will not work until the support for them is added into OpenMSX:

 - FMPAC mono mode will not be enabled
 - Dual-Slot screen will not allow to run ROMs in the slave slot
 - The firmware version will not be shown correctly
 - Dual-PSG will not be supported
 - The EPCS4 flash chip detection will not work, so the firmware update utility will not work
 - There will be only one card device mounted by default, selecting other card or both card configuration will have no effect
 - SFG music module will not work
 - SN7 music module will not work
 - Memory management will not work
