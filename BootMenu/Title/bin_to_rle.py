#!/usr/bin/python
# -*- coding: utf-8 -*- 
import binascii,sys

if __name__=='__main__':
	if len(sys.argv)==3:
		file_bin=sys.argv[1] # исходный файл (Binary)
		file_rle=sys.argv[2] # конечный файл (RLE)
		quantity_limit=255 # RLE 8 бит 
	elif len(sys.argv)==4 and sys.argv[3]=='16':
		file_bin=sys.argv[1] # исходный файл (Binary)
		file_rle=sys.argv[2] # конечный файл (RLE)
		quantity_limit=65535 # RLE 16 бит 
	else:
		print ('Параметры заданы не правильно!')
		print ('Пример: '+sys.argv[0]+' test.bin test.rle 16')
		sys.exit(1)

# Целое (int) в байт(ы)
def int_to_bin(quantity_int):
	if quantity_limit<=255:
		quantity_int_to_bin=(quantity_int).to_bytes(1, byteorder='big')
	elif  quantity_limit<=65535:
		quantity_int_to_bin=(quantity_int).to_bytes(2, byteorder='big')
	else:
		print ('Слишком большое чмсло !', quantity_int)
		sys.exit(1)
	return quantity_int_to_bin

value_quantity=0
data_out=b''
value_curr=b''
file_bin=open(file_bin,'rb')
data_in=file_bin.read(1)
value_prev=data_in # Это для первого значения

while data_in:
	value_curr=data_in

	if value_prev==value_curr and value_quantity<quantity_limit:
			value_quantity=value_quantity+1
	else :
		data_out=data_out+value_prev+int_to_bin(value_quantity)
		value_quantity=1
		value_prev=value_curr

	# Читаем входной файл (следующий байт)
	data_in=file_bin.read(1)

# Нужно не забыть пследний байт в файле :)
if value_prev==value_curr :
		data_out=data_out+value_prev+int_to_bin(value_quantity)

file_out=open(file_rle,'wb')
file_out.write(data_out)

file_out.close()
file_bin.close()
