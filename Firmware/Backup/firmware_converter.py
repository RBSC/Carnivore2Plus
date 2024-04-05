import os
import sys

print ("\nCarnivore2+ Cartridge's Firmware Converter\nCopyright (c) 2024 RBSC * Version 1.00\n")

if not os.path.exists("Carnivore2+.pof"):
	print ("\nFirmware file Carnivore2+.pof not found!")	
	sys.exit(1)

file_stats = os.stat("Carnivore2+.pof")
if file_stats.st_size != 524508:
	print ("\nWrong size of .POF file!")	
	sys.exit(1)

file1 = open("Carnivore2+.pof","rb")
file2 = open("FIRMWARE.BIN","wb")
file3 = open("FIRMWARE.CRC","wt")

mycrc = 0x12345678

for x in range (0 , 524508):
	if x >= 0xa8 and x < 0xa8 + 524288:
		mybyte = file1.read(1)
		file2.write(mybyte)
		mycrc = mycrc + int.from_bytes(mybyte, "big")
	else:
		mybyte = file1.read(1)

file3.write("FirmwareCRC\n")
print("FIRMWARE.BIN CRC: " + hex(mycrc).upper().replace('X', 'x')[:10])
file3.write(hex(mycrc).upper().replace('X', 'x')[:10])
file3.write("\nEOF\n")

file1.close()
file2.close()
file2.close()

print ("\nAll done!\nFIRMWARE.BIN created, CRC saved into FIRMWARE.CRC file...\n")
sys.exit(0)