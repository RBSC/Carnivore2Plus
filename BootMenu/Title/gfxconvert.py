import os
import binascii
from struct import *

file1 = open("gfxtitle.rle","rb")
file2 = open("gfxtitle.inc","wt")

mycnt = 0

file2.write(";\n; Carnivore2+ Cartridge's Title Screen\n; Copyright (c) 2024 RBSC\n; Version 1.00\n;\n\n")


for x in range (0,13384):
	if mycnt == 0:
		file2.write("\tdb\t")

	mybyte = file1.read(1)
	file2.write("#")
	mystr = str(binascii.hexlify(mybyte))[2:-1]
	file2.write(mystr)

	mycnt = mycnt + 1

	if mycnt == 51:
		mycnt = 0
		file2.write("\n")
	else:
		if x != 13383:
			file2.write(",")

file1.close()
file2.close()
