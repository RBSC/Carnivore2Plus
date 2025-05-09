;
; Carnivore2+ Cartridge's FlashROM Manager
; Copyright (c) 2025 RBSC
; Version 3.10
;
; WARNING!!
; The program's code and data before must not go over #4000 and below #C000 addresses!
; WARNING!!
;

; !COMPILATION OPTIONS!
MODE	equ	80		; 80 - default width
				; 40 - MSX1 width, rename the tool to "C2MAN40.COM"

SPC	equ	1		; 1 = for Arabic and Korean computers
				; 0 = for all other MSX computers
; !COMPILATION OPTIONS!


;--- Macro for printing a $-terminated string and 1 symbol

print	macro	
	push	de	
	ld	de,\1
	call	PrintMsg
	pop	de
	endm

prints	macro
	call	PrintSym
	endm


;--- System calls and variables

DOS:	equ	#0005		; DOS function calls entry point
ENASLT:	equ	#0024		; BIOS Enable Slot
WRTSLT:	equ	#0014		; BIOS Write to Slot
CALLSLT:equ	#001C		; Inter-slot call

SCR0WID	equ	#F3AE		; Screen0 width
TPASLOT1:	equ	#F342
TPASLOT2:	equ	#F343
VDPVER	equ	#F56A
CSRY	equ	#F3DC
CSRX	equ	#F3DD
CURSF	equ	#FCA9
ARG:	equ	#F847
EXTBIO:	equ	#FFCA
MNROM:	equ	#FCC1		; Main-ROM Slot number & Secondary slot flags table

CardMDR:	equ	#4F80
AddrM0:	equ	#4F80+1
AddrM1:	equ	#4F80+2
AddrM2:	equ	#4F80+3
DatM0:	equ	#4F80+4

AddrFR:	equ	#4F80+5

R1Mask:	equ	#4F80+6
R1Addr:	equ	#4F80+7
R1Reg:	equ	#4F80+8
R1Mult:	equ	#4F80+9
B1MaskR:	equ	#4F80+10
B1AdrD:	equ	#4F80+11

R2Mask:	equ	#4F80+12
R2Addr:	equ	#4F80+13
R2Reg:	equ	#4F80+14
R2Mult:	equ	#4F80+15
B2MaskR:	equ	#4F80+16
B2AdrD:	equ	#4F80+17

R3Mask:	equ	#4F80+18
R3Addr:	equ	#4F80+19
R3Reg:	equ	#4F80+20
R3Mult:	equ	#4F80+21
B3MaskR:	equ	#4F80+22
B3AdrD:	equ	#4F80+23

R4Mask:	equ	#4F80+24
R4Addr:	equ	#4F80+25
R4Reg:	equ	#4F80+26
R4Mult:	equ	#4F80+27
B4MaskR:	equ	#4F80+28
B4AdrD:	equ	#4F80+29

CardMod:	equ	#4F80+30

CardMDR2:	equ	#4F80+31
ConfFl:	equ	#4F80+32
ADESCR:	equ	#4010

;--- Important constants

L_STR:	equ	16	 	; number of entries on the screen
MAPPN:	equ	5		; max number of currently supported mappers

;--- DOS function calls

_TERM0:	equ	#00		; Program terminate
_CONIN:	equ	#01		; Console input with echo
_CONOUT:	equ	#02	; Console output
_DIRIO:	equ	#06		; Direct console I/O
_INNOE:	equ	#08		; Console input without echo
_STROUT:	equ	#09	; String output
_BUFIN:	equ	#0A		; Buffered line input

_CONST:	equ	#0B		; Console status
_FOPEN: equ	#0F		; Open file
_FCLOSE	equ	#10		; Close file
_FSEARCHF	equ	#11	; File Search First
_FSEARCHN	equ	#12	; File Search Next
_FCREATE	equ	#16	; File Create
_SDMA:	equ	#1A		; Set DMA address
_RBWRITE	equ	#26	; Random block write
_RBREAD:	equ	#27	; Random block read
_TERM:	equ	#62		; Terminate with error code
_DEFAB:	equ	#63		; Define abort exit routine
_DOSVER:	equ	#6F	; Get DOS version


;************************
;***                  ***
;***   MAIN PROGRAM   ***
;***                  ***
;************************

	org	#100			; Needed for programs running under MSX-DOS

;------------------------
;---  Initialization  ---
;------------------------

PRGSTART:
; Set screen
	call	DetVDP
	ld	(VDPVER),a

	call	CLRSCR
	call	KEYOFF

;--- Checks the DOS version and sets DOS2 flag
	ld	c,_DOSVER
	call	DOS
	or	a
	jp	nz,PRTITLE
	ld	a,b
	cp	2
	jp	c,PRTITLE

	ld	a,#FF
	ld	(DOS2),a		; #FF for DOS 2, 0 for DOS 1
;	print	USEDOS2_S		; !!! Commented out by Alexey !!!


; Print the title
PRTITLE:
	print	PRESENT_S

; Process command line options
	call	CmdLine

; Find used slot and make shadow copy
	call	FindSlot
	jp	c,Exit
	call	Testslot
	jp	z,Stfp30

; print warning for incompatible or uninit cartridge
	print	M_Wnvc
	call	SymbIn
	or	%00100000
	cp	"y"
	jr	z,Stfp30
	jp	Exit

Stfp30:       	
	print	M_Shad
	call	Shadow			; shadow bios for C2
	ld	a,(ShadowMDR)
	cp	#21			; shadowing failed?
	jr	z,Stfp30a
	print	Shad_S
	jr	Stfp30b
Stfp30a:
	print	Shad_F

Stfp30b:
	ld	a,(p1e)
	or	a
	jr	z,MainM			; no file parameter

	ld	a,1
	ld	de,BUFFER
	call	EXTPAR
	jr	c,MainM			; No parameter

	ld	ix,BUFFER
	call	FnameP

	jp	ADD_OF			; continue loading ROM image


; Main menu
MainM:
	xor	a
	ld	(CURSF),a

	print	MAIN_S

Ma01:
	ld	a,1
	ld	(CURSF),a

	call	SymbIn

	push	af
	xor	a
	ld	(CURSF),a
	pop	af

	cp	"0"
	jp	z,Exit
	cp	27
	jp	z,Exit
	cp	"1"
	jp	z,ADDimage
	cp	"2"
	jp	z,AddConfig
	cp	"3"
	jr	z,ShowMap
	cp	"4"
	jp	z,DoReset
	cp	"7"
	jr	z,RamCfg
	cp	"8"
	jp	z,CardCfg
	cp	"9"
	jp	z,UTIL
	jr	Ma01


;Show FlashROM block usage
ShowMap:
	print	ONE_NL_S
	call	CBAT
	print	MapBL
	call	PRBAT
	print	ONE_NL_S
	print	ANIK_S
	call	SymbIn
	jp	MainM


;**********************************************************************
;* RAM/SRAM Configuration Menu
;********************************************************************** 
RamCfg:
	xor	a
	ld	(CURSF),a

	print	UTIL_R			; print card configuration menu
RamCfg1:
	ld	a,1
	ld	(CURSF),a

	call	SymbIn

	push	af
	xor	a
	ld	(CURSF),a
	pop	af

	cp	"1"
	jp	z,RAM2Mapper
	cp	"2"
	jp	z,RAM2Shadow
	cp	"3"
	jp	z,RAMDefault
	cp	"4"
	jp	z,NoSRAM
	cp	27
	jp	z,MainM
	cp	"0"
	jp	z,MainM
	jr	RamCfg1	


; Disable FMPAC SRAM or MSX Audio SRAM
NoSRAM:
	ld	a,(ERMSlt)
	ld	h,#40			; set 1 page
	call	ENASLT

	ld	a,%10000000		; enable SD interface, disable RAM substitution
	ld	(CardMDR+#36),a

	ld	a,%11111111		; enable maper ports FC/FD/FE/FF and port 3C, as well as RAM; enable expanded slot and all other devices
	ld	(RSTINS),a		; patch registers for reset

	ld	a,(CardMDR+#3A)
	and	%11101011
	or	%00010100		; Disable FMPAC SRAM or MSX Audio SRAM and MSX Audio ADPCM
	ld	(CardMDR+#3A),a

	print	ImRST			; print reset msg
	ld	hl,RST2SPC
	jp	DoReset1


; Set 2MB RAM to mapper
RAM2Mapper:
	ld	a,(ERMSlt)
	ld	h,#40			; set 1 page
	call	ENASLT

	ld	a,#38			; Disable shadow, set delayed config, BIOSes are in FlashROM
	ld	(CardMDR),a

	ld	a,%10000000		; enable SD interface, disable RAM substitution
	ld	(CardMDR+#36),a

	ld	a,%11111111		; enable mapper ports FC/FD/FE/FF and port 3C, as well as RAM; enable expanded slot and all other devices
	ld	(RSTINS),a		; patch registers for reset

	ld	a,(CardMDR+#3A)
	and	%11101010
	or	%00010101		; Set 2MB RAM for RAM, disable SRAM for FMPAC and MSX Audio and MSX Audio ADPCM
	ld	(CardMDR+#3A),a

	print	ImRST			; print reset msg
	ld	hl,RST2SPC
	jp	DoReset1


; Set 2MB RAM to shadow
RAM2Shadow:
	ld	a,(ERMSlt)
	ld	h,#40			; set 1 page
	call	ENASLT

	ld	a,#38			; Disable shadow, set delayed config, BIOSes are in FlashROM
	ld	(CardMDR),a

	ld	a,%10000000		; enable SD interface, disable RAM substitution
	ld	(CardMDR+#36),a

	ld	a,%10101011		; disable mapper ports FC/FD/FE/FF and port 3C, as well as RAM
	ld	(RSTINS),a		; patch registers for reset

	ld	a,(CardMDR+#3A)
	and	%11101010
	or	%00010101		; Set 2MB RAM for shadow RAM, disable SRAM for FMPAC and MSX Audio and MSX Audio ADPCM
	ld	(CardMDR+#3A),a

	print	ImRST			; print reset msg
	ld	hl,RST2SPC
	jp	DoReset1


; Set default config (1MB+1MB)
RAMDefault:
	ld	a,(ERMSlt)
	ld	h,#40			; set 1 page
	call	ENASLT

	ld	a,#38			; Disable shadow, set delayed config, BIOSes are in FlashROM
	ld	(CardMDR),a

	ld	a,%10000000		; enable SD interface, disable RAM substitution
	ld	(CardMDR+#36),a

	ld	a,%11111111		; enable mapper ports FC/FD/FE/FF and port 3C, as well as RAM; enable expanded slot and all devices
	ld	(RSTINS),a		; patch registers for reset

	ld	a,(CardMDR+#3A)
	and	%11100000		; Set default config (1MB RAM + 1MB Shadow RAM), enable SRAM for FMPAC and MSX Audio and MSX Audio ADPCM
	ld	(CardMDR+#3A),a

	print	ImRST			; print reset msg
	ld	hl,RST2SPC
	jp	DoReset1


;**********************************************************************
;* Card Configuration Menu
;********************************************************************** 
CardCfg:
	xor	a
	ld	(CURSF),a

	print	UTIL_C			; print card configuration menu
CardCfg1:
	ld	a,1
	ld	(CURSF),a

	call	SymbIn

	push	af
	xor	a
	ld	(CURSF),a
	pop	af

	cp	"1"
	jr	z,EnableSD
	cp	"2"
	jr	z,EnableCF
	cp	"3"
	jr	z,EnBoth1
	cp	"4"
	jr	z,EnBoth2
	cp	27
	jp	z,MainM
	cp	"0"
	jp	z,MainM
	jr	CardCfg1	

; Enable SD
EnableSD:
	ld	a,(ERMSlt)
	ld	h,#40			; set 1 page
	call	ENASLT

;	ld	a,#20			; %00100000
;	ld	(CardMDR),a		; set immediate configuration change flag, registers at #4F80
	ld	a,#38			; Disable shadow, set delayed config, BIOSes are in FlashROM
	ld	(CardMDR),a

	ld	a,%11000001		; enable SD instead of CF (default)
	ld	(CardMDR+#36),a

	print	ImRST			; print reset msg
	jp	DoReset

; Enable CF
EnableCF:
	ld	a,(ERMSlt)
	ld	h,#40			; set 1 page
	call	ENASLT

;	ld	a,#20			; %00100000
;	ld	(CardMDR),a		; set immediate configuration change flag, registers at #4F80
	ld	a,#38			; Disable shadow, set delayed config, BIOSes are in FlashROM
	ld	(CardMDR),a

	ld	a,%00000001		; enable CF instead of SD
	ld	(CardMDR+#36),a
	print	ImRST			; print reset msg

	jp	DoReset

; Enable both w/o RAM
EnBoth1:
	ld	a,(ERMSlt)
	ld	h,#40			; set 1 page
	call	ENASLT

	ld	a,#38			; Disable shadow, set delayed config, BIOSes are in FlashROM
	ld	(CardMDR),a

	ld	a,%10101011		; disable mapper ports FC/FD/FE/FF and port 3C, as well as RAM
	ld	(RSTINS),a		; patch registers for reset

	ld	a,%11000010		; enable CF + SD - RAM
	ld	(CardMDR+#36),a

	ld	a,(CardMDR+#3A)
	and	%11101011
	or	%00010100		; Disable FMPAC SRAM or MSX Audio SRAM and MSX Audio DAC
	ld	(CardMDR+#3A),a

	print	ImRST			; print reset msg
	ld	hl,RST2SPC
	jp	DoReset1


; Enable both w/o MUSIC
EnBoth2:
	ld	a,(ERMSlt)
	ld	h,#40			; set 1 page
	call	ENASLT

	ld	a,#38			; Disable shadow, set delayed config, BIOSes are in FlashROM
	ld	(CardMDR),a

	ld	a,%11010111		; disable MUSIC module and its ports
	ld	(RSTINS),a		; patch registers for reset

	ld	a,%11000011		; enable CF + SD - MUSIC
	ld	(CardMDR+#36),a

	ld	a,(CardMDR+#3A)
	and	%11101011
	or	%00010100		; Disable FMPAC SRAM or MSX Audio SRAM and MSX Audio DAC
	ld	(CardMDR+#3A),a

	print	ImRST			; print reset msg
	ld	hl,RST2SPC
	jp	DoReset1


;
; Reset computer
;
DoReset:
; Restore slot configuration!
        ld      a,(ERMSlt)
        ld      h,#40
        call    ENASLT
	ld	hl,RSTCFG
DoReset1:
	xor	a
	ld	(AddrFR),a
	ld	a,#38			; Defconfig
	ld	(CardMDR),a
	ld	de,R1Mask
	ld	bc,26
	ldir

	in	a,(#F4)			; read from F4 port on MSX2+
	or	#80
	out	(#F4),a			; avoid "warm" reset on MSX2+

	rst	#30			; call to BIOS
   if SPC=0
	db	0
   else
	db	#80
   endif
	dw	0			; address


;
; Add new configuration entry
;
AddConfig:
	ld	hl,CFG_TEMPL		; template
	ld	de,BUFFER
	ld	bc,#40
	ldir				; copy empty template entry

	print	ConfName
	ld	a,30
	ld	(BUFFER+100),a
	xor	a
	ld	(BUFFER+101),a
	ld	de,BUFFER+100
	call	StringIn		; input name of the config
	ld	a,(BUFFER+101)
	or	a			; empty input?
	jp	z,MainM

	ld	c,a
	ld	hl,BUFFER+102
	ld	de,BUFFER+5
	ldir				; copy entry name

	ld	bc,0			; counter for enabled devices
	push	bc
	print	ExtSlot
ADCQ1:
	call	SymbIn
	or	%00100000
	call	SymbOut
	cp	"n"
	jr	z,ADCQ2
	cp	"y"
	jr	nz,ADCQ1
	push	af
	ld	hl,BUFFER+59
	ld	a,(hl)
	or	#80			; enable expanded slot bit
	ld	(hl),a	
	pop	af
	pop	bc
	inc	bc
	push	bc
ADCQ2:
	print	MapRAM
ADCQ3:
	call	SymbIn
	or	%00100000
	call	SymbOut
	cp	"n"
	jr	z,ADCQ4
	cp	"y"
	jr	nz,ADCQ3
	push	af
	ld	hl,BUFFER+59
	ld	a,(hl)
	or	#54			; enable RAM bits: 1010100
	ld	(hl),a	
	pop	af
	pop	bc
	inc	bc
	push	bc
ADCQ4:
	print	FmOPLL
ADCQ5:
	call	SymbIn
	or	%00100000
	call	SymbOut
	cp	"n"
	jr	z,ADCQ6
	cp	"y"
	jr	nz,ADCQ5
	push	af
	ld	hl,BUFFER+59
	ld	a,(hl)
	or	#28			; enable MUSIC bits: 101000
	ld	(hl),a
	pop	af
	pop	bc
	inc	bc
	push	bc
ADCQ6:
	print	IDEContr
ADCQ7:
	call	SymbIn
	or	%00100000
	call	SymbOut
	cp	"n"
	jr	z,ADCQ8
	cp	"y"
	jr	nz,ADCQ7
	push	af
	ld	hl,BUFFER+59
	ld	a,(hl)
	or	2			; enable IDE bit: 10
	ld	(hl),a	
	pop	af
	pop	bc
	inc	bc
	push	bc
ADCQ8:
	print	MultiSCC
ADCQ9:
	call	SymbIn
	or	%00100000
	call	SymbOut
	cp	"n"
	jr	z,ADCQ10
	cp	"y"
	jr	nz,ADCQ9
	push	af
	ld	hl,BUFFER+59
	ld	a,(hl)
	or	1			; enable MLTMAP/SCC bit: 1
	ld	(hl),a	
	ld	hl,BUFFER+60
	ld	a,(hl)
	or	#10			; enable SCC sound in main control register
	ld	(hl),a	
	pop	af
	pop	bc
	inc	bc
	push	bc

ADCQ10:
	pop	bc
	ld	a,c			; more than 1 device enabled?
	cp	2
	jr	c,ADCQ11
	ld	hl,BUFFER+59
	ld	a,(hl)
	or	#80			; enable expanded slot bit
	ld	(hl),a	

ADCQ11:
	ld	hl,BUFFER+59
	ld	a,(hl)
	cp	#FF			; all enabled?
	jr	nz,ADCQ12
	ld	hl,BUFFER+60
	ld	a,(hl)
	and	#FB			; enable restart for delayed reconfig
	ld	(hl),a
	ld	hl,BUFFER+62
	ld	a,1			; enable reset for full config
	ld	(hl),a

ADCQ12:	or	a			; nothing enabled?
	jr	nz,ADC01
	print	NothingE
	jp	MainM


ADC01:
	call	FrDIR
	jr	nz,ADC04		; No more free entries?
	print	ONE_NL_S
	print	DirOver_S
ADC02:
	call	SymbIn
	or	%00100000
	cp	"y"
	jr	z,ADC03
	cp	"n"
	jp	z,MainM
	jr	ADC02
ADC03:	call	CmprDIR			; compress directory
	jr	ADC01

ADC04:
	push	af			; save free record number
        ld      a,(ERMSlt)
        ld      h,#40
        call    ENASLT
	ld	a,#15
	ld	(R2Mult),a		; set 16kB Bank write
	xor	a
	ld	(EBlock),a
	ld	(AddrFR),a
        ld      a,(TPASLOT1)
        ld      h,#40
        call    ENASLT
 
	ld	a,1	
	ld	(PreBnk),a
        ld      a,(ERMSlt)
        ld      h,#80
        call    ENASLT

	pop	af
	ld	d,a
	call	c_dir			; calc address directory record
	push	ix
	pop	de			; set flash destination
	ld	hl,BUFFER		; set source
	ld	bc,#40			; record size
	call	FBProg			; save
	jr	c,ADC05

	ld      a,(TPASLOT2)
        ld      h,#80
        call    ENASLT
        ld      a,(TPASLOT1)
        ld      h,#40
        call    ENASLT       		; Select Main-RAM at bank 4000h~7FFFh

	print	EntryOK
	jp	MainM
ADC05:
	ld      a,(TPASLOT2)
        ld      h,#80
        call    ENASLT
        ld      a,(TPASLOT1)
        ld      h,#40
        call    ENASLT       		; Select Main-RAM at bank 4000h~7FFFh

	print	EntryFAIL
	jp	MainM


;
; ADD ROM image
;
ADDimage:
	print	ADD_RI_S
	ld	de,Bi_FNAM
	call	StringIn
	ld	a,(Bi_FNAM+1)
	or	a			; Empty input?
	jr	z,SelFile	

	ld	c,a
	ld	b,0
	ld	hl,Bi_FNAM+2
	add	hl,bc
	ld	(hl),0

	ld	hl,Bi_FNAM+2
	ld	b,13
ADDIM1:
	ld	a,(hl)
	cp	'.'
	jr	z,ADDIM2
	or	a
	jr	z,ADDIMC
	inc	hl
	djnz	ADDIM1

ADDIMC:
	ex	de,hl
	ld	hl,ROMEXT		; copy extension and zero in the end
	ld	bc,5
	ldir
	jr	ADDIM3

ADDIM2:
	inc	hl
	ld	a,(hl)
	or	a
	jr	z,ADDIM3
	cp	32			; empty extension?
	jr	c,ADDIMC

ADDIM3:
	ld	ix,Bi_FNAM+2
	call	FnameP
	jp	ADD_OF

SelFile:
	print	SelMode
	ld      c,_SDMA
	ld      de,BUFTOP
	call    DOS

SelFile0:
	ld	de,FCBROM
	ld	c,_FSEARCHF		; Search First File
	call	DOS
	or	a
	jr	z,SelFile1		; file found!
	print	NoMatch
	jp	MainM

SelFile1:
	ld	b,8
	ld	hl,BUFTOP+1
Sf1:
	ld	e,(hl)
	call	PrintSym
	inc	hl
	djnz	Sf1	
	ld	e,"."
	call	PrintSym
	ld	b,3
	ld	hl,BUFTOP+9
Sf2:
	ld	e,(hl)
	call	PrintSym
	inc	hl
	djnz	Sf2

Sf3:
	call	SymbIn
	cp	13			; Enter? -> select file
	jr	z,Sf5
	cp	27			; ESC? -> exit
	jp	z,MainM
	cp	9			; Tab? -> next file
	jr	nz,Sf3	

	ld	a,(F_V)			; verbose mode?
	or	a
	jr	nz,Sf3b

	ld	b,12
Sf3a:
	ld	e,8
	call	PrintSym		; Erase former file name with backspace
	djnz	Sf3a
	jr	Sf4

Sf3b:	ld	e,9
	call	PrintSym		;  Output a tab before new file

Sf4:
	ld	c,_FSEARCHN		; Search Next File
	call	DOS
	or	a
	jr	nz,SelFile0		; File not found? Start from beginning
	jr	SelFile1		; Print next found file

Sf5:
	ld	de,Bi_FNAM+2
	ld	hl,BUFTOP+1
	ld	bc,8
	ldir
	ld	a,"."
	ld	(de),a
	inc	de
	ld	bc,3
	ldir				; copy selected file name
	xor	a
	ld	(de),a			; zero in the end of the file

	ld	ix,Bi_FNAM+2
	call	FnameP

ADD_OF:
;Open file
	print	OpFile_S

	ld	a,(FCB)
	or 	a
	jr	z,opf1			; dp not print device letter
	add	a,#40			; 1 => "A:"
	ld	e,a
	call	PrintSym
	ld	e,":"
	call	PrintSym
opf1:	ld	b,8
	ld	hl,FCB+1
opf2:
	ld	e,(hl)
	call	PrintSym
	inc	hl
	djnz	opf2	
	ld	e,"."
	call	PrintSym
	ld	b,3
	ld	hl,FCB+9
opf3:
	ld	e,(hl)
	call	PrintSym
	inc	hl
	djnz	opf3
	print	ONE_NL_S

; load RCP file if exists
	xor	a
	ld	(RCPData),a		; erase RCP data

	ld	hl,FCB
	ld	de,FCBRCP
	ld	bc,40
	ldir				; copy FCB
	ld	hl,RCPExt
	ld	de,FCBRCP+9
	ld	bc,3
	ldir				; change extension to .RCP

	ld	de,FCBRCP
	ld	c,_FOPEN
	call	DOS			; Open RCP file
	or	a
	jr	nz,opf4
	ld      hl,30
	ld      (FCBRCP+14),hl     	; Record size = 30 bytes

	ld      c,_SDMA
	ld      de,BUFTOP
	call    DOS

	ld	hl,1
	ld      c,_RBREAD
	ld	de,FCBRCP
	call    DOS			; read RCP file

	push	af
	push	hl
	ld	de,FCBRCP
	ld	c,_FCLOSE
	call	DOS			; close RCP file
	pop	hl
	pop	af
	or	a
	jr	nz,opf4
	ld	a,l
	cp	1			; 1 record (30 bytes) read?
	jr	nz,opf4

	ld	a,(F_A)
	or	a
	jr	nz,opf32		; skip question

	print	RCPFound		; ask to skip autodetection

opf31:
	call	SymbIn			; load rcp?
	or	%00100000
	cp	"n"
	jr	z,opf33
	cp	"y"
	jr	nz,opf31
	call	SymbOut
	print	ONE_NL_S

opf32:
	ld	hl,BUFTOP
	ld	de,RCPData
	ld	bc,30
	ldir				; copy read RCP data to its place
;	ld	hl,RCPData+#04
;	ld	a,(hl)
;	and	%11011111
;	ld	(hl),a			; set ROM as source
;	ld	hl,RCPData+#0A
;	ld	a,(hl)
;	and	%11011111
;	ld	(hl),a			; set ROM as source
;	ld	hl,RCPData+#10
;	ld	a,(hl)
;	and	%11011111
;	ld	(hl),a			; set ROM as source
;	ld	hl,RCPData+#16
;	ld	a,(hl)
;	and	%11011111
;	ld	(hl),a			; set ROM as source

opf33:
	call	SymbOut
	print	ONE_NL_S

; ROM file open
opf4:
	ld	de,FCB
	ld	c,_FOPEN
	call	DOS			; Open file
	ld      hl,1
	ld      (FCB+14),hl     	; Record size = 1 byte
	or	a
	jr	z,Fpo

	print	F_NOT_F_S
	ld	a,(F_A)
	or	a
	jp	nz,Exit			; Automatic exit
	jp	MainM		
	
Fpo:
; set DMA
	ld      c,_SDMA
	ld      de,BUFTOP
	call    DOS
; get file size
	ld	hl,FCB+#10
	ld	bc,4
	ld	de,Size
	ldir

; print ROM size in hex
	ld	a,(F_V)			; verbose mode?
	or	a
	jr	z,vrb00

	print	FileSZH			; print file size
	ld	a,(Size+3)
	call	HEXOUT
	ld	a,(Size+2)
	call	HEXOUT
	ld	a,(Size+1)
	call	HEXOUT
	ld	a,(Size)
	call	HEXOUT

	print	ONE_NL_S

vrb00:

; File size <= 32 �� ?
;	ld	a,(Size+3)
;	or	a
;	jr	nz,Fptl
;	ld	a,(Size+2)
;	or	a
;	jr	nz,Fptl
;	ld	a,(Size+1)
;	cp	#80
;	jr	nc,Fptl
; ROM Image is small, use no mapper
; bla bla bla :)

FMROM:
   if MODE=80
	print	MROMD_S
   else
	print	MROMD_S
	print	ONE_NL_S
   endif

	ld	hl,(Size)
	exx
	ld	hl,(Size+2)
	ld	bc,0
	exx

	ld	a,%00000100
	ld	de,ssr08
	ld	bc,#2001		; >8Kb
	or	a
	sbc	hl,bc
	exx
	sbc	hl,bc
	exx
	jr	c,FMRM01

	ld	a,%00000101
	ld	de,ssr16
	ld	bc,#4001-#2001		; (#2000) >16kB
	sbc	hl,bc
	exx
	sbc	hl,bc
	exx
	jr	c,FMRM01

	ld	a,%00000110
	ld	de,ssr32
	ld	bc,#8001-#4001		; (#4000) >32kb
	sbc	hl,bc
	exx
	sbc	hl,bc
	exx
	jr	c,FMRM01

	ld	a,%00001110
	ld	de,ssr48
	ld	bc,#C001-#8001		; (#4000) >48kB
	sbc	hl,bc
	exx
	sbc	hl,bc
	exx
	jr	c,FMRM01

	ld	a,%00000111
	ld	de,ssr64
	ld	bc,#4000		; #10001-#C001 >64kB
	sbc	hl,bc
	exx
	sbc	hl,bc
	exx
	jr	c,FMRM01

	xor	a
	ld	de,ssrMAP


FMRM01:					; fix size
	ld	(SRSize),a
	call	PrintMsg
	print	ONE_NL_S

; !!!! file attribute fix by Alexey !!!!
	ld	a,(FCB+#0D)
	cp	#20
	jr	z,Fptl
	ld	a,#20
	ld	(FCB+#0D),a
; !!!! file attribute fix by Alexey !!!!

; Analyze ROM-Image

; load first 8000h bytes for analysis	
Fptl:	ld	hl,#8000
	ld      c,_RBREAD
	ld	de,FCB
	call    DOS
	ld	a,l
	or	h
	jp	z,FrErr

; descriptor analysis
;ROMABCD - % 0, 0, CD2, AB2, CD1, AB1, CD0, AB0	
;ROMJT0	 - CD, AB, 0,0,TEXT ,DEVACE, STAT, INIT
;ROMJT1
;ROMJT2
;ROMJI0	- high byte INIT jmp-address
;ROMJI1
;ROMJI2
	ld	bc,6
	ld	hl,ROMABCD
	ld	de,ROMABCD+1
	ld	(hl),b
	ldir				; clear descr tab


	ld	ix,BUFTOP		; test #0000
	call	fptl00
	ld	(ROMJT0),a
	and	#0F
	jr	z,fpt01
	ld	a,e
	ld	(ROMJI0),a
fpt01:
	ld	a,(SRSize)
	and	#0F		
	jr	z,fpt07			; MAPPER
	cp	6
	jr	c,fpt03			; <= 16 kB 
fpt07:
	ld	ix,BUFTOP+#4000		; test #4000
	call	fptl00
	ld	(ROMJT1),a
	and	#0F
	jr	z,fpt02
	ld	a,e
	ld	(ROMJI1),a
fpt02:
	ld	a,(SRSize)
	and	#0F
	jr	z,fpt08			; MAPPER
	cp	7
	jr	c,fpt03			; <= 16 kB 
fpt08:
	ld      c,_SDMA
	ld      de,BUFFER
	call    DOS

	ld	hl,#0010
	ld      c,_RBREAD
	ld	de,FCB
	call    DOS
	ld	a,l
	or	h
	jp	z,FrErr

	ld	ix,BUFFER		; test #8000
	call	fptl00
	ld	(ROMJT2),a
	and	#0F
	jr	z,fpt03
	ld	a,e
	ld	(ROMJI2),a

fpt03:

	ld      c,_SDMA
	ld      de,BUFTOP
	call    DOS
	
	jp	FPT10

fptl00:
	ld	h,(ix+1)
	ld	l,(ix)
	ld	bc,"A"+"B"*#100
	xor	a
	push	hl
	sbc	hl,bc
	pop	hl
	jr	nz,fptl01
	set	6,a
fptl01: ld	bc,"C"+"D"*#100
	or	a
	sbc	hl,bc
	jr	nz,fptl02
	set	7,a
fptl02:	ld	e,a	
	ld	d,0
	or	a
	jr	z,fptl03		; no AB,CD descriptor

	ld	b,4
	push	ix
	pop	hl
	inc	hl			; +1
fptl05:
	inc	hl			; +2
	ld	a,(hl)
	inc	hl
	or	(hl)			; +3
	jr	z,fptl04
	scf
fptl04:	rr	d
	djnz	fptl05
	rrc	d
	rrc	d
	rrc	d
	rrc	d
fptl03:
	ld	a,d
	or	e
	ld	d,a
	ld	e,(ix+3)
	bit	0,d
	jr	nz,fptl06
	ld	e,(ix+5)
	bit	1,d
	jr	nz,fptl06
	ld	e,(ix+7)
	bit	2,d
	jr	nz,fptl06
	ld	e,(ix+9)
fptl06:
;	ld	e,a
;	ld	a,d
	ret
FPT10:

; file close NO! saved for next block
;	ld	de,FCB
;	ld	c,_FCLOSE
;	call	DOS

; print test ROM descriptor table
	ld	a,(F_V)			; verbose mode?
	or	a
	jr	z,vrb02

	print	TestRDT
	ld	a,(ROMJT0)
	call	HEXOUT
	ld	e," "
	call	PrintSym
	ld	a,(ROMJT1)
	call	HEXOUT
	ld	e," "
	call	PrintSym
	ld	a,(ROMJT2)
	call	HEXOUT
	print	ONE_NL_S
	ld	a,(ROMJI0)
	call	HEXOUT
	ld	e," "
	call	PrintSym
	ld	a,(ROMJI1)
	call	HEXOUT
	ld	e," "
	call	PrintSym
	ld	a,(ROMJI2)
	call	HEXOUT
	print	ONE_NL_S

vrb02:
; Map / miniROm select
	ld	a,(SRSize)
	and	#0F
	jr	z,FPT01A		; MAPPER ROM
	cp	7
	jp	c,FPT04			; MINI ROM

;	print	MRSQ_S
;FPT03:					; 32 < ROM =< 64
;	call	SymbIn
;	cp	"n"
;	jr	z,FPT01			; no minirom (mapper)
;	cp	"y"			; yes minirom
;	jr	nz,FPT03

	jr	FPT01B			; Mapper detected!

FPT01A:
	xor	a
	ld	(SRSize),a	
FPT01B:
	ld	a,(RCPData)
	or	a			; RCP data available?
	jp	z,DTMAP

	ld	de,FCB
	ld	c,_FCLOSE
	call	DOS			; close file

	ld	hl,RCPData
	ld	de,Record+#04
	ld	a,(hl)
	ld	(de),a			; copy mapper type
	inc	hl
	ld	de,Record+#23
	ld	bc,29
	ldir				; copy the RCP record to directory record

	print	UsingRCP
	jp	SFM80

; Mapper types Singature
; Konami:
;    LD    (#6000),a
;    LD    (#8000),a
;    LD    (#a000),a
; 
;    Konami SCC:
;    LD    (#5000),a
;    LD    (#7000),a
;    LD    (#9000),a
;    LD    (#b000),a
; 
;    ASCII8:
;    LD    (#6000),a
;    LD    (#6800),a
;    LD    (#7000),a
;    LD    (#7800),a
; 
;    ASCII16:
;    LD    (#6000),a
;    LD    (#7000),a
;
;    32 00 XX
; 
;    For Konami games is easy since they always use the same register addresses.
; 
;    But ASC8 and ASC16 is more difficult because each game uses its own addresses and instructions to access them.
;    I.e.:
;    LD    HL,#68FF 2A FF 68
;    LD    (HL),A   77
;
;    BIT E 76543210
; 	   !!!!!!!. 5000h
;          !!!!!!.- 6000h
;          !!!!!.-- 6800h
;	   !!!!.--- 7000h
;	   !!!.---- 7800h
;          !!.----- 8000h
;          !.------ 9000h
;	   .------- A000h
;    BIT D 76543210
;	          . B000h
DTMAP:
   if MODE=80
	print	Analis_S
   else
	print	Analis_S
	print	ONE_NL_S
   endif

	ld	de,0
DTME6:				; point next portion analis
	ld	ix,BUFTOP
	ld	bc,#8000
DTM01:	ld	a,(ix)
	cp	#2A
	jr	nz,DTM03
	ld	a,(ix+1)
	cp	#FF
	jr	nz,DTM02
	ld	a,(ix+3)
	cp	#77
	jr	nz,DTM02
	ld	a,(ix+2)
	cp	#60
	jr	z,DTM60	
	cp	#68
	jr	z,DTM68
	cp	#70
	jr	z,DTM70
	cp	#78
	jr	z,DTM78
	jr	DTM02
DTM03:	cp	#32
	jr	nz,DTM02
	ld	a,(ix+1)
	cp	#00
	jr	nz,DTM02
	ld	a,(ix+2)
	cp	#50
	jr	z,DTM50
	cp	#60
	jr	z,DTM60
	cp	#68
	jr	z,DTM68
	cp	#70
	jr	z,DTM70
	cp	#78
	jr	z,DTM78
	cp	#80
	jr	z,DTM80
	cp	#90
	jr	z,DTM90
	cp	#A0
	jr	z,DTMA0
	cp	#B0
	jr	z,DTMB0
	
DTM02:	inc	ix
	dec	bc
	ld	a,b
	or	c
	jr	nz,DTM01
	jr	DTME
DTM50:
	set	0,e
	jr	DTM02
DTM60:
	set	1,e
	jp	DTM02
DTM68:
	set	2,e
	jr	DTM02
DTM70:
	set	3,e
	jr	DTM02
DTM78:
	set	4,e
	jr	DTM02
DTM80:
	set	5,e
	jr	DTM02
DTM90:
	set	6,e
	jr	DTM02
DTMA0:
	set	7,e
	jr	DTM02

DTMB0:
	set	0,d
	jr	DTM02
	

DTME:
	ld	(BMAP),de		; save detected bit mask

	ld	a,(F_V)			; verbose mode?
	or	a
	jr	z,DTME23
; print bitmask
	ld	a,(BMAP+1)
	call	HEXOUT
	ld	a,(BMAP)
	call	HEXOUT	
	ld	e," "
	call	PrintSym

DTME23:
	ld	a,0

;    BIT E 76543210
; 	   !!!!!!!. 5000h
;          !!!!!!.- 6000h
;          !!!!!.-- 6800h
;	   !!!!.--- 7000h
;	   !!!.---- 7800h
;          !!.----- 8000h
;          !.------ 9000h
;	   .------- A000h
;    BIT D 76543210
;	          . B000h
	ld	a,(BMAP+1)
	bit	0,a
;	cp	%00000001
	ld	a,(BMAP)
;	jr	z,DTME2			; Konami5
	jr	nz,DTME2			; Konami5

	ld	b,4			; AsCII 16
	cp	%00001010		; 6000h 7000h
	jp	z,DTME1		
;	cp	%00000010		; Zanax-EX
;	jr	z,DTME1

	ld	b,1			; Konami (4)
	cp	%10100010		; 6000h 8000h A000h
	jp	z,DTME1
	cp	%10100000		; Aleste
	jp	z,DTME1
	cp	%00100010		; 6000h 8000h
	jp	z,DTME1			;
	cp	%00100000		; 8000h
	jp	z,DTME1


	ld	b,3			; ASCII 8
	cp	%00011110		; 6000h,6800h,7000h,8700h
	jr	z,DTME1
	cp	%00011100
	jr	z,DTME1
	cp	%00011000		; 0018
	jr	z,DTME1

DTME3:					; Mapper not detected
					; second portion ?
					; next block file read
	ld      c,_SDMA
	ld      de,BUFTOP
	call    DOS
	ld	hl,#8000
	ld      c,_RBREAD
	ld	de,FCB
	call    DOS
	ld	a,l
	or	h
	ld	de,(BMAP)		; load previos bitmask
	jp	z,DTME5
	set	7,d			; bit second seach
	jp	DTME6			; next analise search

DTME5:					; fihish file
	ld	a,e
	ld	b,4
	cp	%00000010		; 0002 = ASCII 16 ZanacEX
	jr	z,DTME1
	cp	%00001000		; 0008 = ASCII 16
	jr	z,DTME1
	cp	%01001000		; 0048 = ASCII 16
	jr	z,DTME1
	ld	b,3
	cp	%00001110		; 000E = ASCII 8
	jr	z,DTME1
	cp	%00000100		; 0004 = ASCII 8
	jr	z,DTME1
	cp	%00100000		; 0010 = ASCII 8
	jr	z,DTME1
	ld	b,0
	jr	DTME1
DTME2:
	cp	%01001001		; 5000h,7000h,9000h	
	ld	b,2			; Konami 5 (SCC)
	jr	z,DTME1
	cp	%01001000		; 5000h,7000h
	jr	z,DTME1
	cp	%01101001		; 
	jr	z,DTME1
	cp	%11101001		; 01E9
	jr	z,DTME1
	cp	%01101000		; 0168
	jr	z,DTME1
	cp	%11001000		; 01C8
	jr	z,DTME1
	cp	%01000000		; 0140
	jr	z,DTME1

	ld	b,3
	cp	%00011000
	jr	z,DTME1
	ld	b,1
	cp	%10100000
	jr	z,DTME1
	jr	DTME3	
DTME1:
	ld	a,b
	ld	(DMAP),a		; save detected Mapper type
	or	a
	jr	nz,DTME21
	
;mapper not found
	ld	a,(SRSize)
	or	a
	jr	z,DTME22		; size > 64k ? not minirom

	print	MD_Fail

	ld	a,(F_A)
	or	a
	jr	nz,FPT04		; flag auto yes

	print	MRSQ_S
FPT03:					; 32 < ROM =< 64
	call	SymbIn
	or	%00100000
	cp	"n"
	jp	z,MTC			; no minirom (mapper), select manually
	cp	"y"			; yes minirom
	jr	nz,FPT03

FPT04:
	ld	a,(RCPData)
	or	a			; RCP data available?
	jp	z,FPT05

	ld	hl,RCPData
	ld	de,Record+#04
	ld	a,(hl)
	ld	(de),a			; copy mapper type
	inc	hl
	ld	de,Record+#23
	ld	bc,29
	ldir				; copy the RCP record to directory record

	print	UsingRCP
	jp	SFM80

; Mini ROM set
FPT05:
	print	NoAnalyze
	ld	a,5
	ld	(DMAP),a		; Minirom
	jr	DTME22

DTME21:
	xor	a
	ld	(SRSize),a

DTME22:

					; file close
	ld	de,FCB
	ld	c,_FCLOSE
	call	DOS


	ld	a,(DMAP)
	ld	b,a
	call	TTAB
	inc	hl
	ex	hl,de			; print selected MAP
	call	PrintMsg
	print	ONE_NL_S

	ld	a,(SRSize)
	and	#0F
	jp	nz,DE_F1		; do not confirm the mapper type

	ld	a,(F_A)
	or	a
	jp	nz,DE_F1		; do not confirm the type mapper (auto)

	ld	a,(DMAP)
	or	a
	jr	z,MTC
	print	CTC_S			; (y/n)?
DTME4:
	call	SymbIn
	or	%00100000
	cp	"y"
	jp	z,DE_F0
	cp	"n"
	jr	nz,DTME4
	call	SymbOut
	print	ONE_NL_S
MTC:					; manually select mapper type
	print	CoTC_S
	ld	a,1
MTC2:	ld	(DMAPt),a		; print all tab MAP
	ld	b,a
	call	TTAB
	ld	a,(hl)
	or	a
	jr	z,MTC1	
	push	hl
	ld	a,(DMAPt)
	ld	e,a
	ld	d,0
	ld	hl,BUFFER
	ld	b,2
	ld	c," "
	ld	a,%00001000		; print 2 decimal digit number
	call	NUMTOASC
	print	BUFFER+1
	ld	e,":"
	call	PrintSym
	ld	e," "
	call	PrintSym
	pop	hl
	inc	hl
	ex	hl,de
	call	PrintMsg
	print	ONE_NL_S
	ld	a,(DMAPt)
	inc	a
	jr	MTC2
MTC1:
	print	Num_S

MTC3:		
	call	SymbIn			; input one character
	cp	"1"
	jr	c,MTC3
	cp	MAPPN + "1"		; number of supported mappers + 1
	jr	nc,MTC3
	push	af
	ld	e,a
	call	PrintSym		; print selection
	print	ONE_NL_S
	pop	af
	sub	a,"0"

;	ld	de,Binpsl		; input 2 digit number
;	call	StringIn
;	ld	b,0
;	ld	a,(Binpsl+1)
;	cp	1
;	jr	z,MTC4
;	cp	2
;	jr	z,MTC5	
;	jr	MTC
;MTC4:	ld	a,(Binpsl+2)
;	sub	a,"0"
;	jr	MTC6
;MTC5:	ld	a,(Binpsl+2)
;	sub	a,"0"
;	inc	a
;	xor	a
;	ld	b,a
;MTC7:	dec	b
;	jr	z,MTC8
;	add	a,10
;	jr	MTC7
;MTC8:	ld	b,a
;	ld	a,(Binpsl+3)
;	sub	a,"0"
;	add	b

MTC6:
; chech inp
	ld	hl,DMAPt
	cp	(hl)
	jp	nc,MTC
	or	a
	jp	z,MTC
	ld	b,a
	push	af
	push	bc

   if MODE=80
	print	SelMapT
   else
	print	SelMapT
	print	ONE_NL_S
   endif

	pop	bc
	pop	af
	jp	DTME1

DE_F0:
	call	SymbOut
	print	ONE_NL_S

DE_F1:
; Save MAP config to Record form
	ld	a,(DMAP)
	ld	b,a
	call	TTAB
	ld	a,(hl)
	ld	(Record+04),a		; type descriptos symbol
	ld	bc,35			; TAB register map
	add	hl,bc
	ld	de,Record+#23		; Record register map
	ld	bc,29			; (6 * 4) + 5
	ldir

	ld	a,(SRSize)
	ld	(Record+#3D),a

; Correction start metod

; ROMJT0
	ld	ix,ROMJT0
	and	#0F
	jp	z,Csm01			; mapper ROM
;Mini ROM-image
;	
	cp	5			; =< 8Kb
	jr	nc,Csm04

	ld	a,#84			; set size 8kB no Ch.reg
	ld	(Record+#26),a		; Bank 0
	ld	a,#8C			; set Bank off
	ld	(Record+#2C),a		; Bank 1
	ld	(Record+#32),a		; Bank 2
	ld	(Record+#38),a		; Bank 3
Csm08:	ld	a,(ix)
	cp	#41
	ld	a,#40
	jr	nz,Csm06		; start on reset
	ld	a,(ix+3)
	and	#C0
	ld	(Record+#28),a		; set Bank Addr	
	cp	#40
	jr	z,Csmj4			; start on #4000
	cp	#80	
	jr	z,Csmj8			; start Jmp(8002)
Csm06:
	ld	a,(ix+3)
	and	#C0
	ld	(Record+#28),a		; set Bank Addr	

	ld	a,01			; start on reset
Csm05:	ld	(Record+#3E),a		
	jp	Csm80

Csmj4:	ld	a,2
	jr	Csm05
Csmj8:	ld	a,6
	jr	Csm05

;
Csm04:	cp	6			; =< 16 kB
	jr	nc,Csm07

	ld	a,#85			; set size 16kB noCh.reg
	ld	(Record+#26),a		; Bank 0
	ld	a,#8D			; set Bank off
	ld	(Record+#2C),a		; Bank 1
	ld	(Record+#32),a		; Bank 2
	ld	(Record+#38),a		; Bank 3
	jp	Csm08

Csm07:	cp	7			; =< 32 kb
	jr	nc,Csm09
	ld	a,#85			; set size 16kB noCh.reg
	ld	(Record+#26),a		; Bank 0
	ld	a,#85			; set size 16kB noCh.reg
	ld	(Record+#2C),a		; Bank 1
	ld	a,#8D			; set Bank off
	ld	(Record+#32),a		; Bank 2
	ld	(Record+#38),a		; Bank 3
	ld	a,(ix)
	ld	b,a
;	cp	#41
	or	a
;	jr	z, Csm071
	jr	nz,Csm071
	ld	a,(ix+1)
	cp	#41
	jr	nz,Csm06
	ld	a,(ix+4)
	and	#C0
	cp	#80
	jr	nz,Csm06
	jr	Csmj8			; start Jmp(8002)	
Csm071:	ld	a,(ix+3)	
	and	#C0
	cp	#40			; #4000
	jr	nz,Csm072
	ld	a,b
	cp	#41
	jp	nz,Csm06		; R
	ld	a,2
	jp	Csm05			; start Jmp(4002)
	cp	#00			; #0000 subrom
	jr	nz,Csm072
	ld	(Record+#28),a		; Bank1 #0000 
	ld	a,#40
	ld	(Record+#2E),a		; Bank2 #4000
	jp	Csm06			; start on reset 	
Csm072:	cp	#80
	jp	nz,Csm06		; start on reset
	ld	(Record+#28),a		; Bank1 #0000 
	ld	a,#C0
	ld	(Record+#2E),a		; Bank2 #4000
	ld	a,6
	jp	Csm05			; start Jmp(8002)

Csm09:
	cp	7			; 64 kB ROM
	jr	nz,Csm10
	ld	a,#87			; set size 64kB noCh.reg
	ld	(Record+#26),a		; Bank 0
	ld	a,#8D			; set Bank off
	ld	(Record+#2C),a		; Bank 1
	ld	(Record+#32),a		; Bank 2
	ld	(Record+#38),a		; Bank 3
	ld	a,0
	ld	(Record+#28),a		; Bank 0 Address=0
	ld	a,(ix)
	or	a
	jp	nz,Csm06		; start on Reset
	ld	a,(ix+1)
	or	a
	jr	z,Csm11
	cp	#41
	jp	nz,Csm06
	ld	a,2			; start jmp(4002)
	jp	Csm05				
Csm11:	ld	a,(ix+2)
	cp	#41
	jp	nz,Csm06
	ld	a,6			; staer jmp(8002)
	jp	Csm05		


Csm10:
;                               	; %00001110 48 kB
	ld	a,#85			; set size 16kB noCh.reg
	ld	(Record+#26),a		; Bank 0
	ld	a,#85			; set size 16kB noCh.reg
	ld	(Record+#2C),a		; Bank 1
	ld	a,#85			; set size 16kB noCh.reg
	ld	(Record+#32),a		; Bank 2
	ld	a,#8D			; set Bank off
	ld	(Record+#38),a		; Bank 3
	ld	a,1
	ld	(Record+#2B),a		; correction for bank 1
	ld	a,(ix)
	or	a			
	jr	z,Csm12
	cp	41
	jr	nz,Csm13
	ld	a,2			; start jmp(4002)
	jp	Csm05
Csm13:	ld	a,(ix+3)
	and	#C0
	jp	nz,Csm06		; start on Reset
	xor	a			; 0 address
	ld	(Record+#28),a
	ld	a,#40
	ld	(Record+#2E),a
	ld	a,#80
	ld	(Record+#34),a
	jp	Csm06			; start on Reset
Csm12:	ld	a,(ix+1)
	or	a
	jr	z,Csm14
	ld	a,(ix+4)
	and	#C0
	cp	#40
	jr	nz,Csm15
	xor	a			; 0 address
	ld	(Record+#28),a
	ld	a,#40
	ld	(Record+#2E),a
	ld	a,#80
	ld	(Record+#34),a
	ld	a,(ix+1)
	cp	#41
	jp	nz,Csm06
	ld	a,2			; start jmp(4002)
	jp	Csm05
Csm15:	jp	Csm06

Csm14:	ld	a,(ix+2)
	or	a
	jp	nz,Csm06
	xor	a			; 0 address
	ld	(Record+#28),a
	ld	a,#80
	ld	(Record+#2E),a
	ld	a,(ix+2)
	cp	#41	
	jp	nz,Csm06
	ld	a,6			; start jmp(8002)
	jp	Csm05

Csm01:

; Mapper ROM IMAGE start Bank #4000
; 
	ld	a,(ix+1)		; ROMJT1 (#8000)
	or	a
	jr	z,Csm02	
Csm03:
	ld	a,01			; Complex start
	ld	(Record+#3E),a		; need Reset
	jr	Csm80
Csm02:
	ld	a,(ix)			; ROMJT0 (#4000)
	cp	#41
	jr	nz,Csm03		; Reset
	ld	a,02			; Start to jump (#4002)	
	ld	(Record+#3E),a

Csm80:	cp	1			; reset needed?
	jr	nz,Csm80a
	ld	a,(Record+#3C)
	and	%11111011		; set reset bit to match 01 at #3E
	ld	(Record+#3C),a
	jr	Csm80b
Csm80a:
	cp	2
	jr	nz,Csm80b
	ld	a,(Record+#3C)
	or	%00000100		; zero reset bit to match 02 at #3E
	ld	(Record+#3C),a

Csm80b:
; test print Size-start metod
	ld	a,(F_V)			; verbose mode?
	or	a
	jr	z,Csm81

	print	Strm_S
	ld	a,(Record+#3D)
	call	HEXOUT
	ld	e,"-"
	call	PrintSym
	ld	a,(Record+#3E)
	call	HEXOUT
	print	ONE_NL_S


; Search free space in flash
Csm81:	ld	a,(Record+#3D)
	and	#0F
	jp	z,SFM80			; mapper ROM
	cp	7
	jp	nc,SFM80		; no multi ROM
; search exist multi rom record
	call	SFMR
	jr	nc,SFM01
;no find
	ld	a,(TPASLOT1)		; reset 1 page
	ld	h,#40
	call	ENASLT

	ld	a,(F_V)			; verbose mode?
	or	a
	jp	z,SFM80

	print	NFNR_S

	jp	SFM80

SFM01:
;find
	ld	e,a
	push	de

	ld	a,(TPASLOT1)		; reset 1 page
	ld	h,#40
	call	ENASLT

	ld	a,(F_V)			; verbose mode?
	or	a
	jr	z,SFM01A

	print	FNRE_S

	pop	de
	push	de
	ld	a,d			; print N record
	call	HEXOUT
	ld	e,"-"
	call	PrintSym
	ld	a,(ix+2)		; print N FlashBlock
	call	HEXOUT
	ld	e,"-"
	call	PrintSym
	pop	de

	push	de
	ld	a,e			; print N Bank
	call	HEXOUT
	print	ONE_NL_S

SFM01A:
	pop	de

;	pop	af	;?

	ld	a,(Record+#3D)
	and	#0F
	cp	6
	ld	a,e
	jr	c,SFM70
	rlc	a
SFM70:	
	ld	(Record+#25),a		; R1Reg
	inc	a
	ld	(Record+#2B),a		; R2Reg
	inc	a
	ld	(Record+#31),a		; R3Reg
	inc	a
	ld	(Record+#37),a		; R4Reg

	ld	a,e
	rlc	a
	rlc	a
	rlc	a
	rlc	a
	ld	b,a
	ld	a,(Record+#3D)
	and	#0F
	or	b
	ld	(Record+#3D),a

	ld	d,1
	ld	e,(ix+2)
	ld	a,d
	ld	(multi),a

	jp	DEFMR1

SFM80:
	xor	a
	ld	(multi),a

; compile BAT table ( 8MB/64kB = 128 )
	call	CBAT
	
	ld	a,(F_V)			; verbose mode?
	or	a
	jr	z,sfm81

	print	MapBL
	call	PRBAT

sfm81:
; Size  - size file 4 byte
; 
; calc blocks len
;
	ld	a,(Size+3)
	or	a
	jp	nz,DEFOver
	ld	a,(Size+2)
	cp	128
	jp	nc,DEFOver
	ld	d,a
	ld	bc,(Size)
	ld	a,b
	or	c
	jr	z,DEF01
	inc	d	 		; add block
DEF01:					; d- block len
; search empty space
;
	ld	bc,6			; Blocks 0 (BB & DIR), 1-2 (IDE BIOS), 3 (MUSIC BIOS), 4-5 (SD BIOS) are reserved for Carnivore2+

DEF03:	ld	e,c
	push	de			; save first empty BAT pointer and len

DEF05:	ld	hl,BAT
	add	hl,bc			; set BAT poiner
	ld	a,(hl)
	or	a			; empty ?
	jr	nz,DEF02		; not empty
	dec	d
	jr	z,DEF04			; successfully found
	inc	c
	bit	7,c			; >127 ?
	jr	z,DEF05			; next BAT
	pop	de			; outside BAT table
	jr	DEFOver
DEF02:	pop	de
	inc	c
	bit	7,c			; >127 ?
	jr	nz,DEFOver		; outside BAT table
	jr	DEF03			; next BAT

DEFOver:
	print	FileOver_S
	ld	a,(F_A)
	or	a
	jp	nz,Exit			; Automatic exit
	jp	MainM

DEF04:	pop 	de			; E - find start block D -Len
;
; save start block and length
DEFMR1:
	ld	(Record+02),de		; Record+02 - start block
					; Record+03 - len
	ld	a,#FF
	ld	(Record+01),a		; set "not erase" byte

	ld	a,(F_V)			; verbose mode?
	or	a
	jr	z,DEF09

	print	FFFS_S
	ld	a,(Record+02)
	call	HEXOUT
	ld	e," "
	call	PrintSym
	ld	a,(Record+03)
	call	HEXOUT
	print	ONE_NL_S

; search free DIR record
DEF09:	call	FrDIR
	jr	nz,DEF06
; Directory overfilling?
	print	DirOver_S
DEF07:
	call	SymbIn
	or	%00100000
	cp	"y"
	jr	z,DEF08
	cp	"n"
	jp	z,MainM
	jr	DEF07
DEF08:	call	CmprDIR
	jr	DEF09

DEF06:	
	ld	(Record),a		; save DIR number

	ld	a,(F_V)			; verbose mode?
	or	a
	jr	z,DEF06A

	print	FDE_S
	ld	a,(Record)
	call	HEXOUT
	print	ONE_NL_S

; Filename -> Record name
DEF06A:	ld	a," "
	ld	bc,30-1
	ld	de,Record+06
	ld	hl,Record+05
	ld	(hl),a
	ldir				; clear record name
	ld	hl,FCB+1
	ld	de,Record+05
	ld	bc,8			; move file name without extension
	ldir

	ld	a,(F_V)			; verbose mode?
	or	a
	jr	z,DEF13

	ld	a,"."
	ld	(de),a
	inc	de
	ld	bc,3			; transfer extension in verbose mode
	ldir

; print Record name
DEF13:
   if MODE=80
	print	NR_I_S
   else
	print	NR_I_S
	print	ONE_NL_S
   endif

	ld	b,30
	ld	hl,Record+05
DEF12:
	ld	e,(hl)
	call	PrintSym
	inc	hl
	djnz	DEF12

	ld	a,(F_A)
	or	a
	jr	nz,DEF10		; Flag automatic confirm

	print	ONE_NL_S
	print	NR_L_S

	ld	a,30
	ld	(BUFFER),a
	ld	de,BUFFER
	call	StringIn
	ld	a,(BUFFER+1)	
	or	a
	jr	z,DEF10
	ld	a," "
	ld	bc,30-1
	ld	de,Record+06
	ld	hl,Record+05
	ld	(hl),a
	ldir				; clear record name
	ld	a,(BUFFER+1)
	ld	b,0
	ld	c,a
	ld	hl,BUFFER+2
	ld	de,Record+05
	ldir
	jr	DEF13
DEF10:
	ld	a,(F_A)
	or	a
	jr	nz,DEF11
	print	LOAD_S
DEF10A:
	call	SymbIn
	or	%00100000
	cp	"y"
	jr	z,DEF10C
	cp	"n"
	jr	nz,DEF10B
	call	SymbOut
	print	ONE_NL_S
	jp	MainM
DEF10B:
;	cp	"e"			; edit was disabled as it caused some issues
;	jr	z,EditCf
	jr	DEF10A
DEF10C:
	call	SymbOut
DEF11:
	print	ONE_NL_S
	call	LoadImage		; save program into FlashROM
	call	SaveDIR			; save directory entry for program

	ld	a,(F_R)
	or	a			; restart?
	jr	nz,Reset1

	ld	a,(F_A)
	or	a
	jp	nz,Exit			; automatic exit
	jp	MainM

Reset1:
; Restore slot configuration!
        ld      a,(ERMSlt)
        ld      h,#40
        call    ENASLT

	xor	a
	ld	(AddrFR),a
	ld	a,#38
	ld	(CardMDR),a
	ld	hl,RSTCFG
	ld	de,R1Mask
	ld	bc,26
	ldir

	in	a,(#F4)			; read from F4 port on MSX2+
	or	#80
	out	(#F4),a			; avoid "warm" reset on MSX2+

	rst	#30			; call to BIOS
   if SPC=0
	db	0
   else
	db	#80
   endif
	dw	0			; address


; Edit was disabled as it caused some issues
;EditCf:
;	ld	hl,Record
;	ld	a,#FF
;	ld	de,BUFFER
;	ld	(de),a
;	inc	de
;	ld	(de),a
;	inc	de
;	ld	bc,#40
;	ldir
;	call	Redit
;	jr	z,DEF11a
;	ld	hl,BUFFER+2
;	ld	de,Record
;	ld	bc,#40
;	ldir
;DEF11a:
;	print	CLS_S
;	jp	DEF10	


;-----------------------------------------------------------------------------
LoadImage:
; Erase block's and load ROM-image

; Reopen file image

        ld      bc,24			; Prepare the FCB
        ld      de,FCB+13
        ld      hl,FCB+12
        ld      (hl),b
        ldir                    	; Initialize the second half with zero
	ld	de,FCB
	ld	c,_FOPEN
	call	DOS			; Open file
	ld      hl,1
	ld      (FCB+14),hl     	; Record size = 1 byte
	or	a
	jr	z,LIF01			; file open
	print	F_NOT_F_S
	scf				; set carry flag because of an error
	ret
LIF01:	ld      c,_SDMA
	ld      de,BUFTOP
	call    DOS

	ld	a,(multi)
	or	a
	jp	nz,LIFM1		; no erase!

; 1st operation - erase flash block(s)
	print	FLEB_S
	xor	a
	ld	(EBlock0),a
	ld	a,(Record+02)		; start block
	ld	(EBlock),a
	ld	a,(Record+03)		; len b
	or	a
	jp	z,LIF04
	ld	b,a
LIF03:	push	bc
	call	FBerase
	jr	nc,LIF02
	pop	bc			
	print 	FLEBE_S
	jp	LIF04
LIF02:
	ld	a,(EBlock)
	call	HEXOUT
	ld	e," "
	call	PrintSym
	pop	bc
	ld	hl,EBlock
	inc	(hl)
	djnz	LIF03
	print	ONE_NL_S

; 2nd operation - loading ROM-image to flash
LIFM1:
        ld      a,(ERMSlt)
        ld      h,#40
        call    ENASLT
	ld	a,#14			; #14 #84
	ld	(R2Mult),a		; set 8kB Bank
	ld	a,(Record+02)		; start block (absolute block 64kB)
	ld	(EBlock),a
	ld	(AddrFR),a
        ld      a,(TPASLOT1)
        ld      h,#40
        call    ENASLT

; set inblock shift
	ld	a,(multi)
	or	a
	jr	z,LIFM2
	ld	a,(Record+#3D)
	ld	e,a
	and	#0F
	cp	4			; 8 kB
	ld	c,1
	jr	z,LIFM3
	cp	5			; 16 kB
	ld	c,2
	jr	z,LIFM3
	ld	c,4			; 32 kB

LIFM3:
	ld	a,e
	rr	a
	rr	a
	rr	a
	rr	a
	and	#0F
	ld	b,a
	or	a
	ld	a,0
	jr	z,LIFM2
LIFM4:	add	a,c
	dec	b
	jr	nz,LIFM4

LIFM2:	ld	(PreBnk),a

	print	LFRI_S
;calc loading cycles
; Size 3 = 0 ( or oversize )
; Size 2 (x 64 kB ) - cycles for (Eblock) 
; Size 1,0 / 2000h - cycles for FBProg portions

;Size / #2000 
	ld	h,0
	ld	a,(Size+2)
	ld	l,a
	xor	a
	ld	a,(Size+1)
	rl	a
	rl	l
	rl	h			; 00008000
	rl	a
	rl	l
	rl	h			; 00004000
	rl	a
	rl	l
	rl	h			; 00002000
	ld	b,a
	ld	a,(Size)
	or	b
	jr	z,Fpr03
	inc	hl			; rounding up
Fpr03:	ld	(C8k),hl		; save Counter 8kB blocks

Fpr02:	

; !!!! file attribute fix by Alexey !!!!
	ld	a,(FCB+#0D)
	cp	#20
	jr	z,Fpr02a
	ld	a,#20
	ld	(FCB+#0D),a
; !!!! file attribute fix by Alexey !!!!

;load portion from file
Fpr02a:	ld	c,_RBREAD
	ld	de,FCB
	ld	hl,#2000
	call	DOS
	ld	a,h
	or	l
	jp	z,Ld_Fail
;program portion
	ld	hl,BUFTOP
	ld	de,#8000
	ld	bc,#2000
 
;      	ld      a,(ERMSlt)
;	ld	e,#94			; sent bank2 to 8kb
;	call	WRTSLT

	call	FBProg2
	jp	c,PR_Fail
	ld	e,">"			; flashing indicator
	call	PrintSym
	ld	a,(PreBnk)
	inc	a			; next PreBnk 
	and	7
	ld	(PreBnk),a	
	jr	nz,FPr01
	ld	hl,EBlock
	inc	(hl)	
FPr01:	ld	bc,(C8k)
	dec	bc
	ld	(C8k),bc
	ld	a,c
	or	b
	jr	nz,Fpr02	

; finish loading ROMimage

	ld	de,FCB
	ld	c,_FCLOSE
	call	DOS			; close file

	ret


; save directory record
SaveDIR:
        ld      a,(ERMSlt)
        ld      h,#40
        call    ENASLT
	ld	a,#15
	ld	(R2Mult),a		; set 16kB Bank write
	xor	a
	ld	(EBlock),a
	ld	(AddrFR),a
        ld      a,(TPASLOT1)
        ld      h,#40
        call    ENASLT
 
	ld	a,1	
	ld	(PreBnk),a

        ld      a,(ERMSlt)
        ld      h,#80
        call    ENASLT

	ld	a,(Record)
	ld	d,a
	call	c_dir			; calc address directory record
	push	ix
	pop	de			; set flash destination

	ld	a,(RCPData)
	or	a			; RCP data available?
	jr	z,SaveDIR0

	push	de
	ld	hl,RCPData
	ld	de,Record+#04
	ld	a,(hl)
	ld	(de),a			; copy mapper type
	inc	hl
	ld	de,Record+#23
	ld	bc,29
	ldir				; copy the RCP record to directory record
	pop	de

SaveDIR0:
	ld	hl,Record		; set source
	ld	bc,#40			; record size
	call	FBProg			; save
	jr	c,PR_Fail
	print	Prg_Su_S

LIF04:
; file close
	push	af
	ld	de,FCB
	ld	c,_FCLOSE
	call	DOS
	pop	af
	ret

PR_Fail:
	print	FL_erd_S
	scf				; set carry flag because of an error
	jr	LIF04

Ld_Fail:
	ld	de,FCB
	ld	c,_FCLOSE
	call	DOS			; close file

	print	ONE_NL_S
	print	FR_ER_S
	scf				; set carry flag because of an error
	jr	LIF04

FBProg:
; Block (0..2000h) programm to flash
; hl - buffer source
; de = flash destination
; bc - size
; (Eblock),(Eblock0) - start address in flash
; output CF - flashing failed flag
	exx
        ld      a,(ERMSlt)
        ld      h,#40
        call    ENASLT  
	ld	a,(PreBnk)
	ld	(R2Reg),a
	ld	a,(EBlock)
	ld	(AddrFR),a
        ld      a,(TPASLOT1)
        ld      h,#40
        call    ENASLT
        ld      a,(ERMSlt)
        ld      h,#80
        call    ENASLT 
	ld	hl,#8AAA
	ld	de,#8555
	exx
	di
Loop1:
	exx
	ld	(hl),#AA		; (AAA)<-AA
	ld	a,#55		
	ld	(de),a			; (555)<-55
	ld	(hl),#A0		; (AAA)<-A0
	exx
	ld	a,(hl)
	ld	(de),a			; byte programm

	call	CHECK			; check
	jp	c,PrEr
	inc	hl
	inc	de
	dec	bc
	ld	a,b
	or	c
	jr	nz,Loop1
	jr	PrEr

FBProg2:
; Block (0..2000h) programm to flash
; hl - buffer source
; de = #8000
; bc - Length
; (Eblock)x64kB, (PreBnk)x8kB(16kB) - start address in flash
; output CF - flag Programm fail
	exx
        ld      a,(ERMSlt)
        ld      h,#40
        call    ENASLT  
	ld	a,(PreBnk)
	ld	(R2Reg),a
	ld	a,(EBlock)
	ld	(AddrFR),a
        ld      a,(TPASLOT1)
        ld      h,#40
        call    ENASLT
        ld      a,(ERMSlt)
        ld      h,#80
        call    ENASLT 
	ld	hl,#8AAA
;	ld	de,#8555
	exx
	ld	de,#8000
	di
Loop2:
	exx
	ld	(hl),#50		; double byte programm
	exx
	ld	a,(hl)
	ld	(de),a			; 1st byte programm
	inc	hl
	inc	de
	ld	a,(hl)			; 2nd byte programm
	ld	(de),a
	call	CHECK			; check
	jp	c,PrEr
	inc	hl
	inc	de
	dec	bc
	dec	bc
	ld	a,b
	or	c
	jr	nz,Loop2
PrEr:
;    	save flag CF - fail
	exx
	push	af
	ei

        ld      a,(TPASLOT2)
        ld      h,#80
        call    ENASLT          	; Select Main-RAM at bank 8000h~BFFFh
	pop	af
	exx
	ret


; Move BIOS (CF card IDE, SD and MUSIC) to shadow RAM
Shadow:
; Eblock, Eblock0 - block address
	ld	a,(ERMSlt)
	ld	h,#40			; Set 1 page
	call	ENASLT
	ld	a,(ERMSlt)
	ld	h,#80			; Set 2 page
	call	ENASLT
	di

	ld	a,#21
	ld	(CardMDR),a

	ld	hl,B23ON
	ld	de,CardMDR+#0C		; set Bank 2 3
	ld	bc,12
	ldir
	ld	a,1			; copy from 1st 64kb block
	ld	(AddrFR),a

	xor	a

; Quick test RAM availability
	ld	hl,#A000
	ld	a,(hl)
	ld	b,a
	xor	a
	ld	(hl),a
	cp	(hl)
	ld	(hl),b
	jr	nz,Sha02

; Work cycle
Sha01:
	ld	(CardMDR+#0E),a		; R2Reg
	ld	(CardMDR+#14),a		; R3Reg
	ld	hl,#8000
	ld	de,#A000
	ld	bc,#2000
	push	hl
	push	de
	push	bc
	ldir
	pop	bc
	pop	de
	pop	hl
	push	af

Sha01t: ld	a,(F_A)
	or	a			; skip testing in auto mode
	jr	nz,Sha01e

	ld	a,(de)			; test copied data
	cp	(hl)
	jr	nz,Sha02		; failed check
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	inc	de
	inc	de
	inc	de
	inc	de
	dec	bc
	dec	bc
	dec	bc
	dec	bc			; check every forth byte (for performance reasons)
	ld	a,b
	or	a
	jr	nz,Sha01t
	ld	a,c
	or	a
	jr	nz,Sha01t	

Sha01e:
	pop	af
	inc	a
	cp	40 			; 8 * 5 128k+64k+128k (IDE+FM+SD BIOSES)
	jr	c,Sha01

	ld	a,#23
	ld	(CardMDR),a
	ld	(ShadowMDR),a		; shadowing enabled
	push	af

Sha02:  pop	af
	xor	a
	ld	(AddrFR),a	
	ld	a,#08
	ld	(CardMDR+#15),a 	; off Bank3 R3Mult
	ld	hl,B2ON
	ld	de,CardMDR+#0C		; set Bank2
	ld	bc,6
	ldir

	ei
	ld      a,(TPASLOT2)
        ld      h,#80
        call    ENASLT
        ld      a,(TPASLOT1)
        ld      h,#40
        call    ENASLT       		; Select Main-RAM at bank 4000h~7FFFh
	ret


FBerase:
; Flash block erase 
; Eblock, Eblock0 - block address
	ld	a,(ERMSlt)
	ld	h,#40			; Set 1 page
	call	ENASLT
	di
	ld	a,(ShadowMDR)
	and	#FE
	ld	(CardMDR),a
	xor	a
	ld	(AddrM0),a
	ld	a,(EBlock0)
	ld	(AddrM1),a
	ld	a,(EBlock)		; block address
	ld	(AddrM2),a
	ld	a,#AA
	ld	(#4AAA),a
	ld	a,#55
	ld	(#4555),a
	ld	a,#80
	ld	(#4AAA),a		; Erase Mode
	ld	a,#AA
	ld	(#4AAA),a
	ld	a,#55
	ld	(#4555),a
	ld	a,#30			; command Erase Block
	ld	(DatM0),a

	ld	a,#FF
    	ld	de,DatM0
    	call	CHECK
; save flag CF - erase fail
	push	af
	ld	a,(ShadowMDR)
	ld	(CardMDR),a
	ei
        ld      a,(TPASLOT1)
        ld      h,#40
        call    ENASLT          	; Select Main-RAM at bank 4000h~7FFFh
	pop	af
	ret

;**********************
CHECK:
    	push	bc
    	ld	c,a
CHK_L1: ld	a,(de)
    	xor	c
    	jp	p,CHK_R1		; Jump if readed bit 7 = written bit 7
    	xor	c
    	and	#20
    	jr	z,CHK_L1		; Jump if readed bit 5 = 1
    	ld	a,(de)
    	xor	c
    	jp	p,CHK_R1		; Jump if readed bit 7 = written bit 7
    	scf
	ld	a,#F0
	ld	(de),a			; Return FlashROM to command mode
CHK_R1:	pop bc
	ret	


; Search free DIR record
; output A - DIR number, otherwise NZ - free record found
FrDIR:
	ld	a,(ERMSlt)
	ld	h,#40			; set 1 page
	call	ENASLT

	ld	hl,B2ON
	ld	de,CardMDR+#0C		; set Bank2
	ld	bc,6
	ldir
 
	ld	a,(ERMSlt)		; set 2 page
	ld	h,#80
	call	ENASLT
	ld	a,1
	ld	(CardMDR+#0E),a 	; set 2nd bank to directory map

	ld	d,0
FRD02:	call	c_dir
	ld	a,(ix)
	cp	#ff			; empty or last record?
	jr	nz,FRD00
	ld	a,(ix+1)
	cp	#ff			; active record?
	jr	nz,FRD00
	ld	a,d
	cp	#ff			; last record?
	jr	nz,FRD01
FRD00:	inc	d
	ld	a,d
	or	a
	jr	nz,FRD02		; next DIR
	xor	a
	or	a
	jr	FRD03			; not found Zero
FRD01:	ld	a,d
	or	a			; not zero?
FRD03:	push	af
	ld	a,(TPASLOT1)		; reset 1 page
	ld	h,#40
	call	ENASLT
	ld	a,(TPASLOT2)		; reset 2 page
	ld	h,#80
	call	ENASLT
	pop	af
	ret


SFMR:
; Search Free multi-Rom Flash-Block
; out	d - record num ix-record
;	a - bank number
;	Flag C- non find nc-find

	ld	a,(ERMSlt)
	ld	h,#40			; set 1 page
	call	ENASLT

	ld	hl,B2ON
	ld	de,CardMDR+#0C		; set Bank2
	ld	bc,6
	ldir
	ld	a,1
	ld	(CardMDR+#0E),a 	; set 2nd bank to directory map

	ld	a,(ERMSlt)		; set 2 page
	ld	h,#80
	call	ENASLT

	ld	d,1
sfr06:	call	c_dir			; output ix - dir point
	jr	nz,sfr01		; valid dir
sfr02:	inc	d
	jp	z,sfr00			; finish directory
	jr	sfr06	
sfr01:	ld	a,(ix+#3D)
	and	#0F
	ld	b,a
	ld	a,(Record+#3D)
	and	#0F
	cp	b
	jr	nz,sfr02

	push	de

; control print
;	push	bc
;	push	ix	
;	ld	e,"m"
;	call	PrintSym
;	pop	ix
;	pop	bc

; bank1 to 8kB #6000-7FFF
	ld	a,#04
	ld	(R1Mult),a
	ld	a,#07
	ld	(B1MaskR),a
	ld	a,#60
	ld	(B1AdrD),a
; test free room
	ld	a,(ix+02)		; N Flash Block
	ld	(AddrFR),a 
	ld	a,b			; size descriptor
	cp	4			; 8 kB
	ld	c,1
	jr	z,sfr10
	cp	5			; 16 kB
	ld	c,2
	jr	z,sfr10
	ld	c,4			; 32 kB
sfr10:
	ld	a,0			; start N place

	ex	af,af'
	ld	e,0			; start n-bank


sfr15:	ld	a,e	
	add	a,c
	ld	d,a			; stop n-bank

srf13:	ld	a,e
	ld	(R1Reg),a 

	ld	hl,#6000
sfr12:	ld	a,(hl)
	inc	a			; FF+1 = 0
	jr	nz,sfr14 		; not clear
	inc	hl
	ld	a,h
	cp	#80
	jr	nz,sfr12		; next byte
sfr11:					; All byte = FF
	inc	e			; next 8k
	ld	a,e
	cp	d	
	jr	nz,srf13 		; next 8k Bank
; clear space finded
	xor	a
	ld	(AddrFR),a 		; set system flash block
	ld	(R1Reg),a 
	ld	a,#15
	ld	(R1Mult),a
	ld	a,#40
	ld	(B1AdrD),a
	ex	af,af'
	or	a			; clear flag C
	pop	de	
	ret

; non clear block
sfr14:
	ex	af,af'
	inc	a			; next Flashblock place
	ex	af,af'

;	push	de
;	push	bc
;	push	hl
;	dec	a
;	call	HEXOUT
;	ld	e,"<"
;	call	PrintSym
;	pop	hl
;	push	hl
;	ld	a,h
;	call	HEXOUT
;	pop	hl
;	push	hl
;	ld	a,l
;	call	HEXOUT
;	ld	e," "
;	call	PrintSym
;	pop	hl
;	pop	bc
;	pop	de

	ld	e,d			; new start bank = d (top prev)
	ld	a,d
	or	a
	cp	8
	jr	c,sfr15			; next block
	xor	a
	ld	(AddrFR),a 		; set system flash block
	ld	(R1Reg),a 
	ex	af,af'
	pop	de
	jp	sfr02			; next record

sfr00:
; out of directory (not found)
	xor	a
	ld	(AddrFR),a 		; set system flash block
	ld	(R1Reg),a 
	ld	a,#15
	ld	(R1Mult),a
	ld	a,#40
	ld	(B1AdrD),a
	scf
	ret	

CBAT: 
; compile BAT table ( 8MB/64kB = 128 )

	ld      bc,127	       		 ; Prepare the BAT
        ld      de,BAT+1
        ld      hl,BAT
        ld      (hl),b
        ldir                    	; Initialize with zero
	
; Set flash configuration
	ld	a,(ERMSlt)
	ld	h,#40			; set 1 page
	call	ENASLT

;	di
	ld	hl,B2ON
	ld	de,CardMDR+#0C		; set Bank2
	ld	bc,6
	ldir
 
	ld	a,(ERMSlt)		; set 2 page
	ld	h,#80
	call	ENASLT
	xor	a

	ld	a,1
	ld	(CardMDR+#0E),a 	; set 2nd bank to directory map

	ld	d,1			; starting dir entry
CBT06:	call	c_dir			; output ix - dir point
	jr	nz,CBT01		; valid dir
CBT02:	inc	d
	jr	z,CBT03			; finish dir
	jr	CBT06	
CBT01:	
	ld	a,(ix+02)		; start block
	ld	c,a
	ld	b,0
	ld	hl,BAT
	add	hl,bc			; calc BAT pointer hl
	ld	b,(ix+03)		; len Blocks
CBT04:	xor	a
	cp	b
	jr	z,CBT02			; len 0 - system block
	cp	(hl)
	ld	a,d
	jr	z,CBT05			; empty Block <- DIR number
	ld	a,(hl)			; not empty <- FF (multi ROM)
	or	#80
CBT05:	ld	(hl),a			; save BAT element
	inc	hl
	dec	b			; next BAT
	jr	nz,CBT04
		
	jr	CBT02			; next DIR	

CBT03:					; finish CBAT
	ld	a,(TPASLOT1)		; reset 1 page
	ld	h,#40
	call	ENASLT
	ld	a,(TPASLOT2)		; reset 2 page
	ld	h,#80
	call	ENASLT
	ret

B1ON:	db	#F8,#50,#00,#85,#03,#40
B2ON:	db	#F0,#70,#01,#15,#7F,#80
B23ON:	db	#F0,#80,#00,#04,#7F,#80	; for shadow source bank
	db	#F0,#A0,#00,#34,#7F,#A0	; for shadow destination bank

c_dir:
; input d - dir idex num
; outut	ix - dir point enter
; output Z - last/empty/deleted entry
 	ld	b,0
	or	a 
	ld	a,d
	rl	a
	rl	b
	rl	a
	rl	b
	rl	a
	rl	b
	rl	a
	rl	b
	rl	a
	rl	b
	rl	a
	rl	b
	ld	c,a
	ld	ix,#8000
	add	ix,bc			; 8000h + b*64

	ld	a,(ix)
	cp	#FF			; last record?
	ret	z

	ld	a,(ix+1)
	or	a			; deleted record ?
	ret


;-------------------------------
TTAB:
;	ld	b,(DMAP)
	inc	b
	ld	hl,CARTTAB
	ld	de,64
TTAB1:	dec	b
	ret	z
	add	hl,de
	jr	TTAB1


FrErr:
; file close
	ld	de,FCB
	ld	c,_FCLOSE
	call	DOS

; print error message
	print	FR_ER_S

; return main	
	jp	MainM		

Exit:
	ld      a,(TPASLOT2)
        ld      h,#80
        call    ENASLT
        ld      a,(TPASLOT1)
        ld      h,#40
        call    ENASLT

	ld	de,EXIT_S
	xor	a
	ld	(CURSF),a
	jp	termdos



;-----------------------------------------------------------------------------

FnameP:
; File Name prepearing
; input	ix - buffer file name
; output - FCB	
	ld	b,8+3
	ld	hl,FCB
	ld	(hl),0
fnp3:	inc	hl
	ld	(hl)," "
	djnz	fnp3	

        ld      bc,24			; Prepare the FCB
        ld      de,FCB+13
        ld      hl,FCB+12
        ld      (hl),b
        ldir                    	; Initialize the second half with zero
;
; File name processing
	ld	hl,FCB+1
;	ld	ix,BUFFER

	ld	b,8
	ld	a,(ix+1)
	cp	":"
	jr	nz,fnp0
; device name
	ld	a,(ix)
	and	a,%11011111
	sub	#40
	ld	(FCB),a
	inc	ix
	inc	ix
; file name
fnp0:	ld	a,(ix)
	or	a
	ret	z
	cp	"."
	jr	z,fnp1
	ld	(hl),a
	inc	ix
	inc	hl
	djnz	fnp0
	ld	a,(ix)
	cp	"."
	jr	z,fnp1
	dec	ix
; file ext
fnp1:
	ld	hl,FCB+9
	ld	b,3
fnp2:	ld	a,(ix+1)
	or 	a
	ret	z
	ld	(hl),a
	inc	ix
	inc	hl
	djnz	fnp2	

	ret


; Print message
; in: DE=message's address
PrintMsg:
	push	hl
	push	de
	push	bc
	push	ix
	push	iy
	ld	c,_STROUT
	call	DOS
	pop	iy
	pop	ix
	pop	bc
	pop	de
	pop	hl
	ret


; Input string
; in: DE=address for string
StringIn:
	push	hl
	push	de
	push	bc
	push	ix
	push	iy
	ld	c,_BUFIN
	call	DOS
	pop	iy
	pop	ix
	pop	bc
	pop	de
	pop	hl
	ret


; Input one symbol
; out: A=symbol
SymbIn:
	push	hl
	push	de
	push	bc
	push	ix
	push	iy
	ld	c,_INNOE
	call	DOS
	pop	iy
	pop	ix
	pop	bc
	pop	de
	pop	hl
	ret


; Output one symbol
; in: A=symbol
SymbOut:
	push	de
	ld	e,a
	call	PrintSym
	pop	de
	ret


; Output one symbol
; in: E=symbol
PrintSym:
	push	hl
	push	de
	push	bc
	push	ix
	push	iy
	push	af
	ld	c,_CONOUT
	call	DOS
	pop	af
	pop	iy
	pop	ix
	pop	bc
	pop	de
	pop	hl
	ret


;---- Out to conlose HEX byte
; A - byte
HEXOUT:
	push	ix
	push	iy
	push	hl
	push	de
	push	bc
	push	af
	rrc	a
	rrc	a
	rrc	a
	rrc	a
	and	#0F
	ld	b,0
	ld	c,a
	ld	hl,ABCD
	add	hl,bc
	ld	e,(hl)
	ld	c,_CONOUT
	call	DOS
	pop	af
	and	#0F
	ld	b,0
	ld	c,a
	ld	hl,ABCD
	add	hl,bc
	ld	e,(hl)
	ld	c,_CONOUT
	call	DOS
	pop	bc
	pop	de
	pop	hl
	pop	iy
	pop	ix
	ret


HEX:
;--- HEX
; input  a- Byte
; output a - H hex symbol
;        b - L hex symbol
	ld	c,a
	and 	#0F
	add	a,48
	cp	58
	jr	c,he2
	add	a,7
he2:	ld	b,a
	ld	a,c
	rrc     a
	rrc     a
	rrc     a
	rrc     a
	and 	#0F
	add	a,48
	cp	58
	ret	c
	add	a,7	
   	ret


NO_FND:
AutoSeek:
; return reg A - slot
;	    
;	     
	ld	a,b
	xor	3			; Reverse the bits to reverse the search order (0 to 3)
	ld	hl,MNROM
	ld	d,0
	ld	e,a
	add	hl,de
	bit	7,(hl)
	jr	z,primSlt		; Jump if slot is not expanded
	or	(hl)			; Set flag for secondary slot
	sla	c
	sla	c
	or	c			; Add secondary slot value to format FxxxSSPP
primSlt:
	ld	(ERMSlt),a
; ---
;	ld	b,a			; Keep actual slot value
;
;	bit	7,a
;	jr	nz,SecSlt		; Jump if Secondary Slot
;	and	3			; Keep primary slot bits
;SecSlt:
;	ld	c,a
;
;	ld	a,b			; Restore actual slot value
; ---
	ld	h,#40
	call	ENASLT			; Select a Slot in Bank 1 (4000h ~ 7FFFh)

	ld	hl,ADESCR
	ld	de,DESCR
	ld	b,7
ASt00	ld	a,(de)
	cp	(hl)
	ret	nz
	inc	hl
	inc	de
	djnz	ASt00
	ld	a,(ERMSlt)
	ld	(ix),a
	inc	ix
	ret
Testslot:
	ld	a,(ERMSlt)
	ld	h,#40
	call	ENASLT

	ld	hl,ADESCR
	ld	de,DESCR
	ld	b,7
ASt01:	ld	a,(de)
	cp	(hl)
	jr	nz,ASt02
	inc	hl
	inc	de
	djnz	ASt01
	jr	ASt03
ASt02:
	ld	de,DESCR
	ld	b,7
ASt04:	ld	a,(de)
	cp	#FF
	jr	nz,ASt03
	inc	de
	djnz	ASt04
ASt03:
	push	af
        ld      a,(TPASLOT1)
        ld      h,#40
        call    ENASLT	
	pop	af
	ret

;*********************************************
;input a - Slot Number
;*********************************************	
ChipErase:
	print	EraseWRN1
	call	SymbIn
	or	%00100000
	cp	"y"
	jr	z,CEra1
	ld	a,'n'
	call	SymbOut
	print	ONE_NL_S
	jp	UTIL
CEra1:
	call	SymbOut
	print	ONE_NL_S
	print	EraseWRN2
	call	SymbIn
	or	%00100000
	cp	"y"
	jr	z,CEra2
	ld	a,'n'
	call	SymbOut
	print	ONE_NL_S
	jp	UTIL
CEra2:
	call	SymbOut
	print	ONE_NL_S
	print	Erasing
	ld	a,(ERMSlt)		; slot number
	ld	(cslt),a
	ld	h,#40
	call	ENASLT
	di
	ld	a,(ShadowMDR)
	and	#FE
	ld	(CardMDR),a
	ld	a,#95			; enable write to bank (current #85)
	ld	(R1Mult),a  

	di
	ld	a,#AA
	ld	(#4AAA),a
	ld	a,#55
	ld	(#4555),a
	ld	a,#80
	ld	(#4AAA),a		; Erase Mode
	ld	a,#AA
	ld	(#4AAA),a
	ld	a,#55
	ld	(#4555),a
	ld	a,#10			; Command Erase Block
	ld	(#4AAA),a

	ld	a,#FF
    	ld	de,#4000
    	call	CHECK
	push	af
	ld	a,(ShadowMDR)
	ld	(CardMDR),a
	ei
        ld      a,(TPASLOT1)
        ld      h,#40
        call    ENASLT			; Select Main-RAM at bank 4000h~7FFFh
	pop	af

	jp	nc,ChipErOK
	print	EraseFail
	print	ANIK_S
	call	SymbIn
	jp	UTIL
ChipErOK:
	print	EraseOK
	print	ANIK_S
	call	SymbIn
	jp	UTIL



;**********************************************************************
;* Service Menu
;********************************************************************** 
UTIL:
	xor	a
	ld	(CURSF),a

	print	UTIL_S
UT01:
	ld	a,1
	ld	(CURSF),a

	call	SymbIn

	push	af
	xor	a
	ld	(CURSF),a
	pop	af

	cp	"1"
	jp	z,D_Compr
	cp	"2"
	jp	z,DEFINI
	cp	"3"
	jp	z,DIRINI
	cp	"4"
	jp	z,BootINI
	cp	"5"
	jp	z,IDE_INI
	cp	"6"
	jp	z,UTILM
	cp	"7"
	jp	z,SD_INI
	cp	"8"
	jp	z,ChipErase
	cp	27
	jp	z,MainM
	cp	"0"
	jp	z,MainM
	jr	UT01	


UTILM:
	xor	a
	ld	(CURSF),a

	print	UTIL_M
MUT02:
	ld	a,1
	ld	(CURSF),a

	call	SymbIn

	push	af
	xor	a
	ld	(CURSF),a
	pop	af

	cp	"1"
	jp	z,MUT03
	cp	"2"
	jp	z,MUT04
	cp	"3"
	jp	z,MUT05
	cp	27
	jp	z,UTIL
	cp	"0"
	jp	z,UTIL
	jr	MUT02	

MUT03:
	ld	hl,FMPACNam		; FMPCCMFC.BIN
	jr	MUT06
MUT04:
	ld	hl,SFGNam		; SFGMCMFC.BIN
	jr	MUT06
MUT05:
	ld	hl,MSXANam		; MSXACMFC.BIN
MUT06:
	ld	de,MUSICNam
	ld	bc,11
	ldir				; copy music module name to template
	jp	MUSIC_INI


D_Compr:
	print	DirComr_S
DCMPR1:
	call	SymbIn
	or	%00100000
	cp	"y"
	jr	z,DCMPR2
	cp	"n"
	jr	nz,DCMPR1
	call	SymbOut
	print	ONE_NL_S
	jp	UTIL

DCMPR2:
	call	SymbOut
	call	CmprDIR
	print	DirComr_E
	print	ANIK_S
	call	SymbIn
	jp	UTIL


SET2PD:
	ld	a,(ERMSlt)
	ld	h,#40			; set 1 page
	call	ENASLT

	ld	hl,B2ON
	ld	de,CardMDR+#0C		; set Bank2
	ld	bc,6
	ldir
 
	ld	a,(ERMSlt)		; set 2 page
	ld	h,#80
	call	ENASLT
	ld	a,1
	ld	(CardMDR+#0E),a 	; set 2nd bank to directory map

        ld      a,(TPASLOT1)
        ld      h,#40
        call    ENASLT
	ret


CmprDIR:
; Compress directory 
; Set flash configuration
	call	SET2PD

; copy valid record 1st 8kB
	xor	a
	ld	(Dpoint+2),a		; start number record
	ld	hl,#8000
	ld	(Dpoint),hl
CVDR:
; clear buffer #FF
	ld	bc,#2000-1
	ld	hl,BUFTOP
	ld	de,BUFTOP+1
	ld	a,#FF
	ld	(hl),a
	ldir
; copy valid dir record -  to BUFFTOP
	ld	de,BUFTOP
	ld	hl,(Dpoint)
CVDR2:	ld	a,(hl)	
	inc	hl
	cp	#FF			; b1 empty ?
	jr	z,CVDR1			; empty
	ld	a,(hl)
	cp	#FF			; b2 erased ?
	jr	nz,CVDR1		; erase
	push	hl
	push	de
	inc	hl
	inc	hl
	inc	hl
	inc	hl			; Point to name at +#5
	ld	de,RAM_TEMPL		; Point to "RAM: "
	ex	hl,de
	ld	b,5
CVDR24:
	ld	a,(de)
	cp	(hl)
	jr	nz,CVDR25
	inc	hl
	inc	de
	djnz	CVDR24
	pop	de
	pop	hl
	jr	CVDR1			; skip "RAM: " entries
CVDR25:
	pop	de
	pop	hl
	ld	bc,#3F			; not empty not erase -> copy		
	ld	a,(Dpoint+2)
	ld	(de),a			; 1st byte = new number record
	inc	a
	ld	(Dpoint+2),a		; increment number
	inc	de	
	ldir				; copy other bytes from old record
	ld	(Dpoint),hl		; save sourse pointer		
	bit	7,a			; if numper >= 80 (half table)
	jr	nz,CVDR4 		; next 8Kb 
CVDR3:	ld	a,h
	cp	#C0	 		; out or range directory #C000 address
	jr	c,CVDR2			; go to next record
	jr	CVDR4  			; finish copy
CVDR1:	ld	bc,#3F			; skipping record
	add	hl,bc			; hl = hl + #3F
	ld	(Dpoint),hl		; save sourse pointer	
	jr	CVDR3			; go to test tabl ending
CVDR4:
; save 1-st 8k directory
; clear (1/2)
	xor	a
	ld	(EBlock),a
	ld	a,#40
	ld	(EBlock0),a
	call	FBerase
; programm (1/2)

	ld	hl,DEF_CFG
	ld	de,BUFTOP
	ld	bc,#40
	ldir				; update DefConfig

	xor	a
	ld	(EBlock),a
	inc	a
	ld	(PreBnk),a
	ld	hl,BUFTOP
	ld	de,#8000
	ld	bc,#2000
	call	FBProg
; clear buffer #FF
	ld	bc,#2000-1
	ld	hl,BUFTOP
	ld	de,BUFTOP+1
	ld	a,#FF
	ld	(hl),a
	ldir

; set flash configuration
	call	SET2PD

; 2-nd 8kB block directory
	ld	a,(Dpoint+2)
	bit	7,a
	jr	z,CVDR20		; no 2-nd Block

; copy valid record 2-nd 8kB
; de - new TOPBUFF
; hl - continue directory >= A000	
	ld	de,BUFTOP
	ld	hl,(Dpoint)
	ld	a,h
	cp	#C0
	jr	nc,CVDR20
CVDR12:	ld	a,(hl)	
	inc	hl
	cp	#FF
	jr	z,CVDR11
	ld	a,(hl)
	cp	#FF
	jr	nz,CVDR11
	ld	bc,#3F
	ld	a,(Dpoint+2)
	ld	(de),a
	inc	a
	ld	(Dpoint+2),a
	inc	de
	ldir
CVDR13:	ld	(Dpoint),hl	
	ld	a,h
	cp	#C0	 		; out or range directory
	jr	c,CVDR12
	jr	CVDR20    		; finish copy
CVDR11:	ld	bc,#3F
	add	hl,bc

	jr	CVDR13

CVDR20:
;  clear (2/2)
	xor	a
	ld	(EBlock),a
	ld	a,#60
	ld	(EBlock0),a
	call	FBerase
;  programm (2/2)
	ld	hl,BUFTOP
	ld	de,#A000
	ld	bc,#2000
	call	FBProg
;  clear autostart
;	xor	a
;	ld	(EBlock),a
;	ld	a,#80
;	ld	(EBlock0),a
;	call	FBerase

	ld      a,(TPASLOT2)
	ld      h,#80
	call    ENASLT
	ld      a,(TPASLOT1)
	ld      h,#40
	call    ENASLT       		; Select Main-RAM at bank 4000h~7FFFh
	ret


;	
; Init DefConfig Record
;
DEFINI:
	print	DEFINI_S		; warning message 
DUT02:
	call	SymbIn
	or	%00100000
	cp	"y"
	jr	z,DUT03
	cp	"n"
	jr	nz,DUT02
	call	SymbOut
	print	ONE_NL_S
	jp	UTIL

DUT03:
	call	SymbOut

	call	SET2PD

	ld	hl,#8000
	ld	de,BUFTOP
	ld	bc,#2000
	ldir				; copy directory 1/2

	xor	a
	ld	(EBlock),a
	ld	a,#40
	ld	(EBlock0),a
	call	FBerase			; erase directory block 1/2

	ld	hl,DEF_CFG
	ld	de,BUFTOP
	ld	bc,#40
	ldir				; update DefConfig

	xor	a
	ld	(EBlock),a
	inc	a
	ld	(PreBnk),a
	ld	hl,BUFTOP
	ld	de,#8000
	ld	bc,#2000
	call	FBProg
	jr	c,DUT04
	print	DEFINC_S
	jr	DUT05
DUT04:
	print	DEFINC_F
DUT05:
	print	ANIK_S
	call	SymbIn
	jp	UTIL

;	
; Erase directory + add 00 Record (empty SCC)
;
DIRINI:
	print	DIRINI_S		; warning message 
UT02:
	call	SymbIn
	or	%00100000
	cp	"y"
	jr	z,UT03
	cp	"n"
	jr	nz,UT02
	call	SymbOut
	print	ONE_NL_S
	jp	UTIL

UT03:
	call	SymbOut

; erase directory area
	xor	a
	ld	(EBlock),a
	ld	a,#40			; 1st 1/2 Directory
	ld	(EBlock0),a
	call	FBerase	
	ld	a,#60			; 2nd 1/2 Directory
	ld	(EBlock0),a
	call	FBerase		

	call	SET2PD

; Form 00 - record "DefConfig"
	ld	a,(ERMSlt)
	ld	e,#15
	ld	hl,R2Mult
	call	WRTSLT			; set 16 kB Bank1
	xor	a
	ld	(EBlock),a		; Block = 0 system (x 64kB)
	inc	a
	ld	(PreBnk),a		; Bank=1 (x 16kB)

	ld	hl,DEF_CFG
	ld	de,#8000
	ld	bc,#40
	call	FBProg
	jr	c,UT04
	print	DIRINC_S
	jr	UT05
UT04:
	print	DIRINC_F
UT05:
	print	ANIK_S
	call	SymbIn
	jp	UTIL


; Get an answer Yes/No
QFYN:
	call	SymbIn
	or	%00100000
	cp	"y"
	jr	z,QFYNE
	cp	"n"
	jr	nz,QFYN
	call	SymbOut
	print	ONE_NL_S
	pop	hl			; pop call address
	jp	UTIL
QFYNE:
	call	SymbOut
	print	ONE_NL_S
	ret	


; Write IDE BIOS
IDE_INI:
	ld	a,(F_SU)
	or	a			; override flag present?
	jr	nz,IDE_INI1
	ld	a,(ShadowMDR)
	cp	#21			; no shadowing of bioses?
	jr	nz,IDE_INI1
	print	NO_B_UPD
	print	ANIK_S
	call	SymbIn
	jp	UTIL

IDE_INI1:
	print	IDE_I_S
	call	QFYN

; prepare standart "ROMFILE"
	ld	a,#01
	ld	(Record+2),a		; set state block #10000
	ld	a,#02
	ld	(Record+3),a		; set length 2 bl #10000-#2FFFF

	ld	hl,IDEFNam
	jp	Ifop


; Write SD BIOS
SD_INI:
	ld	a,(F_SU)
	or	a			; override flag present?
	jr	nz,SD_INI1
	ld	a,(ShadowMDR)
	cp	#21			; no shadowing of bioses?
	jr	nz,SD_INI1
	print	NO_B_UPD
	print	ANIK_S
	call	SymbIn
	jp	UTIL

SD_INI1:
	print	SD_I_S
	call	QFYN

	ld	a,#04
	ld	(Record+2),a		; set state block #10000
	ld	a,#02
	ld	(Record+3),a		; set length 2 bl #10000-#2FFFF
	ld	hl,SDFNam
	jr	Ifop


; Write MUSIC BIOS
MUSIC_INI:
	ld	a,(F_SU)
	or	a			; override flag present?
	jr	nz,MUSIC_INI1
	ld	a,(ShadowMDR)
	cp	#21			; no shadowing of bioses?
	jr	nz,MUSIC_INI1
	print	NO_B_UPD
	print	ANIK_S
	call	SymbIn
	jp	UTIL

MUSIC_INI1:
	print	MUSIC_W			; print warning for incompatible BIOS
	print	MUSIC_I_S
	call	QFYN

	ld	a,#03
	ld	(Record+2),a		; set start block #30000
	ld	a,#01
	ld	(Record+3),a		; set length 1 bl #30000-#3FFFF
	ld	hl,MUSICNam

Ifop:
	ld	de,FCB
	ld	bc,1+8+3
	ldir				; set file name
        ld      bc,24           	; Prepare the FCB
        ld      de,FCB+13
        ld      hl,FCB+12
        ld      (hl),b
        ldir 

	ld	de,FCB
	ld	c,_FOPEN
	call	DOS			; Open file
	ld      hl,1
	ld      (FCB+14),hl     	; Record size = 1 byte
	or	a
	jr	z,Ifop01			; file open
	print	F_NOT_F_S
	jp	UTIL
Ifop01:
	ld	hl,FCB+#10
	ld	bc,4
	ld	de,Size
	ldir				; Get File Size

	ld	a,(F_V)			; verbose mode?
	or	a
	jr	z,Ifop02
	print	FileSZH
	ld	a,(Size+3)
	call	HEXOUT
	ld	a,(Size+2)
	call	HEXOUT
	ld	a,(Size+1)
	call	HEXOUT
	ld	a,(Size)
	call	HEXOUT			; print ROM size in hex
	print	ONE_NL_S

Ifop02:
	ld      c,_SDMA
	ld      de,BUFTOP
	call    DOS

	ld	c,_RBREAD
	ld	de,FCB
	ld	hl,#2000
	call	DOS			; Load first 8kb
	ld	a,h
	or	l	
	jr	nz,Ifop03
	print	FR_ERS			; Read error
	jr	Ifop041
Ifop03:
	ld	de,FCB
	ld	c,_FCLOSE
	call	DOS			; close file

	ld	hl,BUFTOP
	ld	a,(hl)
	inc	hl
	cp	"A"
	jr	nz,Ifop04
	ld	a,(hl)
	inc	hl
	cp	"B"
	jr	nz,Ifop04
	inc	hl
	ld	a,(hl)
	cp	#40			; test "AB" + high address value for SD/IDE BIOSes
	jr	z,Ifop0
	inc	hl
	inc	hl
	ld	a,(hl)
	cp	#40			; test "AB" + high address value for call FMPAC BIOS
	jr	z,Ifop0
	ld	a,(hl)
	cp	#2e			; test "AB" + high address value of call SFG BIOS
	jr	z,Ifop0
Ifop04:
	print	BadFile			; Broken or incompatible file
Ifop041:
	ld	de,FCB
	ld	c,_FCLOSE
	call	DOS			; close file
	jp	UTIL

Ifop0:
; load BIOS
	xor	a
	ld	(multi),a
	call	LoadImage
	jr	c,Ifop1			; if failed, C flag is set
	print	Flash_C_S
Ifop0a:
	ld	de,FCB
	ld	c,_FCLOSE
	call	DOS			; close file

	print	ANIK_S
	call	SymbIn

	ld	a,(ERMSlt)
	ld	h,#40			; Set 1 page
	call	ENASLT
	xor	a
	ld	(AddrFR),a		; Set back the first 64kb

	jp	UTIL

Ifop1:
	ld	de,FCB
	ld	c,_FCLOSE
	call	DOS			; close file
Ifop2:
	print	FL_er_S
	jr	Ifop0a


BootINI:
	print	Boot_I_S
	call	QFYN

	ld	hl,BootFNam
	ld	de,FCB
	ld	bc,1+8+3
	ldir				; set file name
        ld      bc,24           	; Prepare the FCB
        ld      de,FCB+13
        ld      hl,FCB+12
        ld      (hl),b
        ldir				; Initialize the second half with zero
	ld	de,FCB
	ld	c,_FOPEN
	call	DOS			; Open file
	ld      hl,1
	ld      (FCB+14),hl     	; Record size = 1 byte
	or	a
	jr	z,Boot03		; file open
	print	F_NOT_F_S
	jp	UTIL
Boot03:	ld      c,_SDMA
	ld      de,BUFTOP
	call    DOS			; set DMA

	ld	hl,FCB+#10
	ld	bc,4
	ld	de,Size
	ldir				; Get File Size

	ld	a,(F_V)			; verbose mode?
	or	a
	jr	z,Boot031
	print	FileSZH
	ld	a,(Size+3)
	call	HEXOUT
	ld	a,(Size+2)
	call	HEXOUT
	ld	a,(Size+1)
	call	HEXOUT
	ld	a,(Size)
	call	HEXOUT			; print ROM size in hex
	print	ONE_NL_S

Boot031:
	ld	bc,(Size+1)		; Check size: must be 32768 bytes for Boot Menu
	ld	a,(Size)	
	or	a
	jr	nz,Boot035
	or	b
	jr	nz,Boot035
	ld	a,c
	cp	#C0			; 49kb?
	jr	z,Boot04
Boot035:
	print	BadFile			; Incorrect file size or format
Boot0351:
	ld	de,FCB
	ld	c,_FCLOSE
	call	DOS			; close file
	jp	UTIL
Boot04:
	ld	c,_RBREAD
	ld	de,FCB
	ld	hl,#2000
	call	DOS			; Load first 8kb
	ld	a,h
	or	l	
	jr	nz,Boot045
Boot04Er:
	print	FR_ERS			; Read error
	jr	Boot0351
Boot045:
	ld	hl,BUFTOP
	ld	a,(hl)
	inc	hl
	cp	"A"
	jr	nz,Boot035
	ld	a,(hl)
	inc	hl
	cp	"B"
	jr	nz,Boot035
	ld	a,(hl)
	inc	hl
	cp	#1F
	jr	nz,Boot035
	ld	a,(hl)
	cp	#40
	jr	nz,Boot035
Boot05:
;Erase boot menu		
	print	BootWrit
	xor	a
	ld	(EBlock),a
	ld	a,#00			; 1st boot menu block
	ld	(EBlock0),a
	call	FBerase	
	ld	a,#20			; 2nd boot menu block
	ld	(EBlock0),a
	call	FBerase	
	ld	a,#80			; 3rd boot menu block
	ld	(EBlock0),a
	call	FBerase
	ld	a,#A0			; 4th boot menu block
	ld	(EBlock0),a
	call	FBerase	
	ld	a,#C0			; 5th boot menu block
	ld	(EBlock0),a
	call	FBerase
	ld	a,#E0			; 6th boot menu block
	ld	(EBlock0),a
	call	FBerase	

;Program 1st 8kb and DefConfig
	call	SET2PD

	ld	a,(ERMSlt)
	ld	e,#15
	ld	hl,R2Mult
	call	WRTSLT			; set 16 kB Bank1

	xor	a
	ld	(PreBnk),a		; 0-page #00 (Boot)
	ld	(EBlock),a
	ld	hl,BUFTOP
	ld	de,#8000
	ld	bc,#2000
	call	FBProg			; 1st 8kb block
	jp	c,Boot07

; Load second 8kb
	ld	c,_RBREAD
	ld	de,FCB
	ld	hl,#2000
	call	DOS
	ld	a,h
	or	l
	jp	z,Boot06
; Program 2-nd boot menu
	ld	hl,BUFTOP
	ld	de,#A000
	ld	bc,#2000	
	call	FBProg			; 2nd 8kb block
	jp	c,Boot07

; Load third 8kb
	ld	c,_RBREAD
	ld	de,FCB
	ld	hl,#2000
	call	DOS
	ld	a,h
	or	l
	jp	z,Boot06		; no more data?
; Program 3rd boot menu
	ld	a,2			; 2-page #80
	ld	(PreBnk),a
	ld	hl,BUFTOP
	ld	de,#8000
	ld	bc,#2000	
	call	FBProg			; 1st 8kb block
	jr	c,Boot07

; Load forth 8kb
	ld	c,_RBREAD
	ld	de,FCB
	ld	hl,#2000
	call	DOS
	ld	a,h
	or	l
	jr	z,Boot06		; no more data?
; Program 4th boot menu
	ld	hl,BUFTOP
	ld	de,#A000
	ld	bc,#2000	
	call	FBProg			; 2nd 8kb block
	jr	c,Boot07

; Load fifth 8kb
	ld	c,_RBREAD
	ld	de,FCB
	ld	hl,#2000
	call	DOS
	ld	a,h
	or	l
	jr	z,Boot06		; no more data?
; Program 5th boot menu
	ld	a,3			; 3-page #C0
	ld	(PreBnk),a
	ld	hl,BUFTOP
	ld	de,#8000
	ld	bc,#2000	
	call	FBProg			; 2nd 8kb block
	jr	c,Boot07

; Load sixth (last) 8kb
	ld	c,_RBREAD
	ld	de,FCB
	ld	hl,#2000
	call	DOS
	ld	a,h
	or	l
	jr	z,Boot06		; no more data?
; Program 6th (last) boot menu
	ld	hl,BUFTOP
	ld	de,#A000
	ld	bc,#2000	
	call	FBProg			; 2nd 8kb block
	jr	nc,Boot06

Boot07:
	ld	de,FCB
	ld	c,_FCLOSE
	call	DOS			; close file

	print	FL_er_S
	print	ANIK_S
	call	SymbIn
	jp	UTIL
Boot06:
	ld	de,FCB
	ld	c,_FCLOSE
	call	DOS			; close file

	print	Flash_C_S
	print	ANIK_S
	call	SymbIn
	jp	UTIL


;-------------------------------------------------------------------------
;--- NAME: EXTPAR
;      Extracts a parameter from the command line
;    INPUT:   A  = Parameter to extract (the first one is 1)
;             DE = Buffer to put the extracted parameter
;    OUTPUT:  A  = Total number of parameters in the command line
;             CY = 1 -> The specified parameter does not exist
;                       B undefined, buffer unmodified
;             CY = 0 -> B = Parameter length, not including the tailing 0
;                       Parameter extracted to DE, finished with a 0 byte
;                       DE preserved

EXTPAR:	or	a			; Terminates with error if A = 0
	scf
	ret	z

	ld	b,a
	ld	a,(#80)			; Terminates with error if
	or	a			; there are no parameters
	scf
	ret	z
	ld	a,b

	push	af,hl
	ld	a,(#80)
	ld	c,a			; Adds 0 at the end
	ld	b,0			; (required under DOS 1)
	ld	hl,#81
	add	hl,bc
	ld	(hl),0
	pop	hl
	pop	af

	push	hl,de,ix
	ld	ix,0			; IXl: Number of parameter
	ld	ixh,a			; IXh: Parameter to be extracted
	ld	hl,#81

;* Scans the command line and counts parameters

PASASPC:
	ld	a,(hl)			; Skips spaces until a parameter
	or	a			; is found
	jr	z,ENDPNUM
	cp	" "
	inc	hl
	jr	z,PASASPC

	inc	ix			; Increases number of parameters
PASAPAR:	ld	a,(hl)		; Walks through the parameter
	or	a
	jr	z,ENDPNUM
	cp	" "
	inc	hl
	jr	z,PASASPC
	jr	PASAPAR

;* Here we know already how many parameters are available

ENDPNUM:
	ld	a,ixl		; Error if the parameter to extract
	cp	ixh			; is greater than the total number of
	jr	c,EXTPERR		; parameters available

	ld	hl,#81
	ld	b,1			; B = current parameter
PASAP2:	ld	a,(hl)			; Skips spaces until the next
	cp	" "			; parameter is found
	inc	hl
	jr	z,PASAP2

	ld	a,ixh			; If it is the parameter we are
	cp	b			; searching for, we extract it,
	jr	z,PUTINDE0		; else...
	                                 
	inc	b
PASAP3:	ld	a,(hl)			; ...we skip it and return to PASAP2
	cp	" "
	inc	hl
	jr	nz,PASAP3
	jr	PASAP2

;* Parameter is located, now copy it to the user buffer

PUTINDE0:
	ld	b,0
	dec	hl
PUTINDE:	inc	b
	ld	a,(hl)
	cp	" "
	jr	z,ENDPUT
	or	a
	jr	z,ENDPUT
	ld	(de),a			; Parameter is copied to (DE)
	inc	de
	inc	hl
	jr	PUTINDE

ENDPUT:	xor	a
	ld	(de),a
	dec	b

	ld	a,ixl
	or	a
	jr	FINEXTP
EXTPERR:	scf
FINEXTP:	pop	ix
		pop     de
		pop	hl
	ret


termdos:
	call	PrintMsg

	ld	c,_TERM0
	jp	DOS



;--- NAME: NUMTOASC
;      Converts a 16 bit number into an ASCII string
;    INPUT:      DE = Number to convert
;                HL = Buffer to put the generated ASCII string
;                B  = Total number of characters of the string
;                     not including any termination character
;                C  = Padding character
;                     The generated string is right justified,
;                     and the remaining space at the left is padded
;                     with the character indicated in C.
;                     If the generated string length is greater than
;                     the value specified in B, this value is ignored
;                     and the string length is the one needed for
;                     all the digits of the number.
;                     To compute length, termination character "$" or 00
;                     is not counted.
;                 A = &B ZPRFFTTT
;                     TTT = Format of the generated string number:
;                            0: decimal
;                            1: hexadecimal
;                            2: hexadecimal, starting with "&H"
;                            3: hexadecimal, starting with "#"
;                            4: hexadecimal, finished with "H"
;                            5: binary
;                            6: binary, starting with "&B"
;                            7: binary, finishing with "B"
;                     R   = Range of the input number:
;                            0: 0..65535 (unsigned integer)
;                            1: -32768..32767 (twos complement integer)
;                               If the output format is binary,
;                               the number is assumed to be a 8 bit integer
;                               in the range 0.255 (unsigned).
;                               That is, bit R and register D are ignored.
;                     FF  = How the string must finish:
;                            0: No special finish
;                            1: Add a "$" character at the end
;                            2: Add a 00 character at the end
;                            3: Set to 1 the bit 7 of the last character
;                     P   = "+" sign:
;                            0: Do not add a "+" sign to positive numbers
;                            1: Add a "+" sign to positive numbers
;                     Z   = Left zeros:
;                            0: Remove left zeros
;                            1: Do not remove left zeros
;    OUTPUT:    String generated in (HL)
;               B = Length of the string, not including the padding
;               C = Length of the string, including the padding
;                   Tailing "$" or 00 are not counted for the length
;               All other registers are preserved

NUMTOASC:
	push	af,ix,de,hl
	ld	ix,WorkNTOA
	push	af,af
	and	%00000111
	ld	(ix+0),a		; Type
	pop	af
	and	%00011000
	rrca
	rrca
	rrca
	ld	(ix+1),a		; Finishing
	pop	af
	and	%11100000
	rlca
	rlca
	rlca
	ld	(ix+6),a		; Flags: Z(zero), P(+ sign), R(range)
	ld	(ix+2),b		; Number of final characters
	ld	(ix+3),c		; Padding character
	xor	a
	ld	(ix+4),a		; Total length
	ld	(ix+5),a		; Number length
	ld	a,10
	ld	(ix+7),a		; Divisor = 10
	ld	(ix+13),l		; User buffer
	ld	(ix+14),h
	ld	hl,BufNTOA
	ld	(ix+10),l		; Internal buffer
	ld	(ix+11),h

ChkTipo:
	ld	a,(ix+0)	; Set divisor to 2 or 16,
	or	a			; or leave it to 10
	jr	z,ChkBoH
	cp	5
	jp	nc,EsBin
EsHexa:	ld	a,16
	jr	GTipo
EsBin:	ld	a,2
	ld	d,0
	res	0,(ix+6)		; If binary, range is 0-255
GTipo:	ld	(ix+7),a

ChkBoH:	ld	a,(ix+0)		; Checks if a final "H" or "B"
	cp	7			; is desired
	jp	z,PonB
	cp	4
	jr	nz,ChkTip2
PonH:	ld	a,"H"
	jr	PonHoB
PonB:	ld	a,"B"
PonHoB:	ld	(hl),a
	inc	hl
	inc	(ix+4)
	inc	(ix+5)

ChkTip2:	ld	a,d		; If the number is 0, never add sign
	or	e
	jr	z,NoSgn
	bit	0,(ix+6)		; Checks range
	jr	z,SgnPos
ChkSgn:	bit	7,d
	jr	z,SgnPos
SgnNeg:	push	hl			; Negates number
	ld	hl,0			; Sign=0:no sign; 1:+; 2:-
	xor	a
	sbc	hl,de
	ex	de,hl
	pop	hl
	ld	a,2
	jr	FinSgn
SgnPos:	bit	1,(ix+6)
	jr	z,NoSgn
	ld	a,1
	jr	FinSgn
NoSgn:	xor	a
FinSgn:	ld	(ix+12),a

ChkDoH:	ld	b,4
	xor	a
	cp	(ix+0)
	jp	z,EsDec
	ld	a,4
	cp	(ix+0)
	jp	nc,EsHexa2
EsBin2:	ld	b,8
	jr	EsHexa2
EsDec:	ld	b,5

EsHexa2:	push	de
Divide:	push	bc,hl			; DE/(IX+7)=DE, remaining A
	ld	a,d
	ld	c,e
	ld	d,0
	ld	e,(ix+7)
	ld	hl,0
	ld	b,16
BucDiv:	rl	c
	rla
	adc	hl,hl
	sbc	hl,de
	jr	nc,$+3
	add	hl,de
	ccf
	djnz	BucDiv
	rl	c
	rla
	ld	d,a
	ld	e,c
	ld	a,l
	pop	hl
	pop	bc

ChkRest9:	cp	10		; Converts the remaining
	jp	nc,EsMay9		; to a character
EsMen9:	add	a,"0"
	jr	PonEnBuf
EsMay9:	sub	10
	add	a,"A"

PonEnBuf:	ld	(hl),a		; Puts character in the buffer
	inc	hl
	inc	(ix+4)
	inc	(ix+5)
	djnz	Divide
	pop	de

ChkECros:	bit	2,(ix+6)	; Checks if zeros must be removed
	jr	nz,ChkAmp
	dec	hl
	ld	b,(ix+5)
	dec	b			; B=num. of digits to check
Chk1Cro:	ld	a,(hl)
	cp	"0"
	jr	nz,FinECeros
	dec	hl
	dec	(ix+4)
	dec	(ix+5)
	djnz	Chk1Cro
FinECeros:	inc	hl

ChkAmp:	ld	a,(ix+0)		; Puts "#", "&H" or "&B" if necessary
	cp	2
	jr	z,PonAmpH
	cp	3
	jr	z,PonAlm
	cp	6
	jr	nz,PonSgn
PonAmpB:	ld	a,"B"
	jr	PonAmpHB
PonAlm:	ld	a,"#"
	ld	(hl),a
	inc	hl
	inc	(ix+4)
	inc	(ix+5)
	jr	PonSgn
PonAmpH:	ld	a,"H"
PonAmpHB:	ld	(hl),a
	inc	hl
	ld	a,"&"
	ld	(hl),a
	inc	hl
	inc	(ix+4)
	inc	(ix+4)
	inc	(ix+5)
	inc	(ix+5)

PonSgn:	ld	a,(ix+12)		; Puts sign
	or	a
	jr	z,ChkLon
SgnTipo:	cp	1
	jr	nz,PonNeg
PonPos:	ld	a,"+"
	jr	PonPoN
	jr	ChkLon
PonNeg:	ld	a,"-"
PonPoN	ld	(hl),a
	inc	hl
	inc	(ix+4)
	inc	(ix+5)

ChkLon:	ld	a,(ix+2)		; Puts padding if necessary
	cp	(ix+4)
	jp	c,Invert
	jr	z,Invert
PonCars:	sub	(ix+4)
	ld	b,a
	ld	a,(ix+3)
Pon1Car:	ld	(hl),a
	inc	hl
	inc	(ix+4)
	djnz	Pon1Car

Invert:	ld	l,(ix+10)
	ld	h,(ix+11)
	xor	a			; Inverts the string
	push	hl
	ld	(ix+8),a
	ld	a,(ix+4)
	dec	a
	ld	e,a
	ld	d,0
	add	hl,de
	ex	de,hl
	pop	hl			; HL=initial buffer, DE=final buffer
	ld	a,(ix+4)
	srl	a
	ld	b,a
BucInv:	push	bc
	ld	a,(de)
	ld	b,(hl)
	ex	de,hl
	ld	(de),a
	ld	(hl),b
	ex	de,hl
	inc	hl
	dec	de
	pop	bc
	ld	a,b			; *** This part was missing on the
	or	a			; *** original routine
	jr	z,ToBufUs		; ***
	djnz	BucInv
ToBufUs:
	ld	l,(ix+10)
	ld	h,(ix+11)
	ld	e,(ix+13)
	ld	d,(ix+14)
	ld	c,(ix+4)
	ld	b,0
	ldir
	ex	de,hl

ChkFin1:	ld	a,(ix+1)	; Checks if "$" or 00 finishing is desired
	and	%00000111
	or	a
	jr	z,Fin
	cp	1
	jr	z,PonDolar
	cp	2
	jr	z,PonChr0

PonBit7:	dec	hl
	ld	a,(hl)
	or	%10000000
	ld	(hl),a
	jr	Fin

PonChr0:	xor	a
	jr	PonDo0
PonDolar:	ld	a,"$"
PonDo0:	ld	(hl),a
	inc	(ix+4)

Fin:	ld	b,(ix+5)
	ld	c,(ix+4)
	pop	hl
	pop     de
	pop	ix
	pop	af
	ret

WorkNTOA:	defs	16
BufNTOA:	ds	10


;--- EXTNUM16
;      Extracts a 16-bit number from a zero-finished ASCII string
;    Input:  HL = ASCII string address
;    Output: BC = Extracted number
;            Cy = 1 if error (invalid string)
;
;EXTNUM16:	call	EXTNUM
;	ret	c
;	jp	c,INVPAR		; Error if >65535
;
;	ld	a,e
;	or	a			; Error if the last char is not 0
;	ret	z
;	scf
;	ret


;--- NAME: EXTNUM
;      Extracts a 5 digits number from an ASCII string
;    INPUT:      HL = ASCII string address
;    OUTPUT:     CY-BC = 17 bits extracted number
;                D  = number of digits of the number
;                     The number is considered to be completely extracted
;                     when a non-numeric character is found,
;                     or when already five characters have been processed.
;                E  = first non-numeric character found (or 6th digit)
;                A  = error:
;                     0 => No error
;                     1 => The number has more than five digits.
;                          CY-BC contains then the number composed with
;                          only the first five digits.
;    All other registers are preserved.

EXTNUM:	push	hl,ix
	ld	ix,ACA
	res	0,(ix)
	set	1,(ix)
	ld	bc,0
	ld	de,0
BUSNUM:	ld	a,(hl)			; Jumps to FINEXT if no numeric character
	ld	e,a			; IXh = last read character
	cp	"0"
	jr	c,FINEXT
	cp	"9"+1
	jr	nc,FINEXT
	ld	a,d
	cp	5
	jr	z,FINEXT
	call	POR10

SUMA:	push	hl			; BC = BC + A 
	push	bc
	pop	hl
	ld	bc,0
	ld	a,e
	sub	"0"
	ld	c,a
	add	hl,bc
	call	c,BIT17
	push	hl
	pop	bc
	pop	hl

	inc	d
	inc	hl
	jr	BUSNUM

BIT17:	set	0,(ix)
	ret
ACA:	db	0			; b0: num>65535. b1: more than 5 digits

FINEXT:	ld	a,e
	cp	"0"
	call	c,NODESB
	cp	"9"+1
	call	nc,NODESB
	ld	a,(ix)
	pop	ix
	pop	hl
	srl	a
	ret

NODESB:	res	1,(ix)
	ret

POR10:	push	de,hl			; BC = BC * 10 
	push	bc
	push	bc
	pop	hl
	pop	de
	ld	b,3
ROTA:	sla	l
	rl	h
	djnz	ROTA
	call	c,BIT17
	add	hl,de
	call	c,BIT17
	add	hl,de
	call	c,BIT17
	push	hl
	pop	bc
	pop	hl
	pop	de
	ret
PRBAT:
	print	ONE_NL_S
	print	MapTop
	ld	de,#0
	ld	bc,#0810
	ld	hl,BAT
PRB0:
	push	hl
	push	bc
	push	de
	push	de
	print	ONE_NL_S
	pop	de
	ld	a,e
	call	HEXOUT
	print	Bracket
	pop	de
	pop	bc
	pop	hl
PRB1:	
	inc	e
	push	hl
	push	bc
	push	de
	ld	a,b
	cp	8
	jr	nz,PRB2	
	ld	a,c
	cp	11
	jr	c,PRB2
	ld	a,#FF
	jr	PRB3
PRB2:	ld	a,(hl)
	and	a,#7F			; remove the "multiple entries" flag
PRB3:	call	HEXOUT

   if MODE=80
	print	Space
   endif
	pop	de
	pop	bc
	pop	hl
	inc	hl
	dec	c
	jr	nz,PRB1
	ld	c,16		
	dec	b
	jr	nz,PRB0
	print	ONE_NL_S
	ret


; Clear screen and set mode 40/80 depending on VDP version
CLRSCR:
	ld	a,(VDPVER)
	or	a			; v991x?
	jr	z,Set40

   if MODE=80
	cp	2			; v995x?
	jr	nc,Set80
   endif

	ld	a,#80
	ld	hl,#15C
	push	ix
	push	iy
	rst	#30
   if SPC=0
	db	0
   else
	db	#80
   endif
	dw	#000C			; read byte at address #15C
	pop	iy
	pop	ix
	ei
	cp	#C3			; MSX2?
	jr	nz,Set40

   if MODE=40
	ld	a,(SCR0WID)
	cp	41
	jr	c,Set40
   endif

Set80:
	ld	a,80			; 80 symbols for screen0
	ld	(SCR0WID),a		; set default width of screen0
	jr	SetScr
Set40:
	ld	a,40			; 40 symbols for screen0
	ld	(SCR0WID),a		; set default width of screen0
SetScr:
	push	ix
	push	iy
	xor	a
	rst	#30			; for compatibility with korean and arabix MSXx
   if SPC=0
	db	0
   else
	db	#80
   endif
	dw	#005F
	pop	iy
	pop	ix

	xor	a
	ld	(CURSF),a		; disable cursor

	ld	a,(SCR0WID)
	cp	80
	ret	z

   if MODE=80
	print	NOTE
;	call	SymbIn			; print note and ask for action if VDP < v9938
;	or	%00100000
;	call	SymbOut
;	push	af
;	print	CRLF			; skip 2 lines
;	pop	af
;	cp	"y"
;	ret	z

	pop	hl
	ld	c,_TERM0
	jp	DOS			; exit to DOS
   endif

	ret


; Hide functional keys
KEYOFF:	
	push	ix
	push	iy
	rst	#30			; for compatibility with korean and arabix MSXx
   if SPC=0
	db	0
   else
	db	#80
   endif
	dw	#00CC
	pop	iy
	pop	ix
	ret

; Unhide functional keys
KEYON:
	push	ix
	push	iy
	rst	#30			; for compatibility with korean and arabix MSXx
   if SPC=0
	db	0
   else
	db	#80
   endif
	dw	#00CF
	pop	iy
	pop	ix
	ret


FindSlot:
; Auto-detection 
	ld	ix,TRMSlt		; Tabl Find Slt cart
        ld      b,3             	; B=Primary Slot
BCLM:
        ld      c,0             	; C=Secondary Slot
BCLMI:
        push    bc
        call    AutoSeek
        pop     bc
        inc     c
	bit	7,a	
	jr      z,BCLM2			; not extended slot	
        ld      a,c
        cp      4
        jr      nz,BCLMI		; Jump if Secondary Slot < 4
BCLM2:  dec     b
        jp      p,BCLM			; Jump if Primary Slot < 0
	ld	a,#FF
	ld	(ix),a			; finish autodetect
; slot analise
	ld	ix,TRMSlt
	ld	a,(ix)
	or	a
	jr	z,BCLNS			; No detection
; print slot table
	ld	(ERMSlt),a		; save first detected slot

	print	Findcrt_S

BCLT1:	ld	a,(ix)
	cp	#FF
	jr	z,BCLTE
	and	3
	add	a,"0"
	ld	e,a
	call	PrintSym		; print primary slot number
	ld	a,(ix)
	bit	7,a
	jr	z,BCLT2			; not extended
	rrc	a
	rrc	a
	and	3
	add	a,"0"
	ld	e,a
	call	PrintSym		; print extended slot number
BCLT2:	ld	e," "
	call	PrintSym
	inc	ix
	jr	BCLT1

BCLTE:
	ld	a,(F_A)
	or	a               
	jr	nz,BCTSF 		; Automatic flag (No input slot)
	print	FindcrI_S
	jp	BCLNE
BCLNS:
	print	NSFin_S
	jp	BCLNE1
BCLNE:
	ld	a,(F_A)
	or	a
	jr	nz,BCTSF 		; Automatic flag (No input slot)

; input slot number
BCLNE1:	ld	de,Binpsl
	call	StringIn
	ld	a,(Binpsl+1)
	or	a
	jr	z,BCTSF			; no input slot
	ld	a,(Binpsl+2)
	sub	a,"0"
	and	3
	ld	(ERMSlt),a
	ld	a,(Binpsl+1)
	cp	2
	jr	nz,BCTSF		; no extended
	ld	a,(Binpsl+3)
	sub	a,"0"
	and	3
	rlc	a
	rlc	a
	ld	hl,ERMSlt
	or	(hl)
	or	#80
	ld	(hl),a	


BCTSF:
; test flash
;*********************************
	ld	a,(ERMSlt)
;TestROM:
	ld	(cslt),a
	ld	h,#40
	call	ENASLT
	ld	a,#21
	ld	(CardMDR),a
	ld	hl,B1ON
	ld	de,CardMDR+#06		; set Bank1
	ld	bc,6
	ldir

	ld	a,#95			; enable write  to bank (current #85)
	ld	(R1Mult),a  

	di
	ld	a,#AA
	ld	(#4AAA),a
	ld	a,#55
	ld	(#4555),a
	ld	a,#90
	ld	(#4AAA),a		; Autoselect Mode ON

	ld	a,(#4000)
	ld	(Det00),a		; Manufacturer Code 
	ld	a,(#4002)
	ld	(Det02),a		; Device Code C1
	ld	a,(#401C)
	ld	(Det1C),a		; Device Code C2
	ld	a,(#401E)
	ld	(Det1E),a		; Device Code C3
	ld	a,(#4006)
	ld	(Det06),a		; Extended Memory Block Verify Code

	ld	a,#F0
	ld	(#4000),a		; Autoselect Mode OFF
	ei
        ld      a,(TPASLOT1)
        ld      h,#40
        call    ENASLT          	; Select Main-RAM at bank 4000h~7FFFh
	
; Print result
	print 	SltN_S
	ld	a,(cslt)
	ld	b,a
	cp	#80
	jp	nc,Trp01		; exp slot number
	and	3
	jr	Trp02
Trp01:	rrc	a
	rrc	a
	and	%11000000
	ld	c,a
	ld	a,b
	and	%00001100
	or	c
	rrc	a
	rrc	a
Trp02:	call	HEXOUT	
	print	ONE_NL_S

	ld	a,(F_V)			; verbose mode?
	or	a
	jp	z,Trp02a

	print	MfC_S
	ld	a,(Det00)
	call	HEXOUT
	print	ONE_NL_S

	print	DVC_S
	ld	a,(Det02)
	call	HEXOUT
	ld	e," "
	call	PrintSym
	ld	a,(Det1C)
	call	HEXOUT
	ld	e," "
	call	PrintSym
	ld	a,(Det1E)
	call	HEXOUT
	print	ONE_NL_S

	print	EMB_S
	ld	a,(Det06)
	call	HEXOUT
	print	ONE_NL_S

Trp02a:	ld	a,(Det00)
	cp	#20
	jp	nz,Trp03	
	ld	a,(Det02)
	cp	#7E
	jp	nz,Trp03
	print	M29W640			; print base model number M29W640G
	ld	e,"x"
	ld	a,(Det1C)
	cp	#0C
	jr	z,Trp05
	cp	#10
	jr	z,Trp08
	jr	Trp04			; M29W640Gx
Trp05:	ld	a,(Det1E)
	cp	#01
	jr	z,Trp06
	cp	#00
	jr	z,Trp07
	jr	Trp04
Trp08:	ld	a,(Det1E)
	cp	#01
	jr	z,Trp09
	cp	#00
	jr	z,Trp10
	jr	Trp04
Trp06:	ld	e,"H"			; M29W640GH
	jr	Trp04
Trp07:	ld	e,"L"			; M29W640GL
	jr	Trp04
Trp09:	ld	e,"T"			; M29W640GT
	jr	Trp04
Trp10:	ld	e,"B"			; M29W640GB
Trp04:
	call	PrintSym
	print	ONE_NL_S

	ld	a,(Det06)
	cp	80
	jp	c,Trp11		

	ld	a,(F_V)			; verbose mode?
	or	a
	ret	z

	print	EMBF_S
	xor	a
	ret
Trp11:
	ld	a,(F_V)			; verbose mode?
	or	a
	ret	z

	print	EMBC_S	
	xor	a
	ret	
Trp03:
	print	NOTD_S
	scf
	ret


;------------------------------------------------------------------------------
;
; Main data area for strings, must be below #4000!
;

DEF_CFG:
	db	#00,#FF,00,00,"C"
	db	"DefConfig: RAM+DISK+MUSIC+SCC "
	db	#F8,#50,#00,#85,#3F,#40
	db	#F8,#70,#01,#8C,#3F,#60		
	db      #F8,#90,#02,#8C,#3F,#80		
	db	#F8,#B0,#03,#8C,#3F,#A0	
	db	#FF,#38,#00,#01,#FF

RSTCFG:
	db	#F8,#50,#00,#85,#03,#40
	db	0,0,0,0,0,0
	db	0,0,0,0,0,0
	db	0,0,0,0,0,0
	db	#FF,#30

RST2SPC:
	db	#F8,#50,#00,#85,#3F,#40
	db	#F8,#70,#01,#8C,#3F,#60
	db	#F8,#90,#02,#8C,#3F,#80
	db	#F8,#B0,#03,#8C,#3F,#A0
RSTINS:	db	#FF,#38

CFG_TEMPL:
	db	#00,#FF,00,00,"C"
	db	"                              "
	db	#F8,#50,#00,#8C,#3F,#40
	db	#F8,#70,#01,#8C,#3F,#60		
	db      #F8,#90,#02,#8C,#3F,#80		
	db	#F8,#B0,#03,#8C,#3F,#A0	
	db	#00,#A8,#00,#01,#FF


CARTTAB: ; (N x 64 byte) 
	db	"U"					;1
	db	"Unknown mapper                   $"	;34
	db	#F8,#50,#00,#84,#FF,#40			;6
	db	#F8,#70,#01,#84,#FF,#60			;6	
	db      #F8,#90,#02,#84,#FF,#80			;6	
	db	#F8,#B0,#03,#84,#FF,#A0			;6
	db	#FF,#BC,#00,#02,#FF			;5

CRTT1:	db	"k"
	db	"Konami 4                         $"
	db	#F8,#50,#00,#04,#FF,#40			
	db	#F8,#60,#01,#84,#FF,#60				
	db      #F8,#80,#02,#84,#FF,#80				
	db	#F8,#A0,#03,#84,#FF,#A0			
	db	#FF,#AC,#00,#02,#FF
CRTT2:	db	"K"
	db	"Konami 5 (Konami SCC)            $"
	db	#F8,#50,#00,#84,#FF,#40			
	db	#F8,#70,#01,#84,#FF,#60				
	db      #F8,#90,#02,#84,#FF,#80				
	db	#F8,#B0,#03,#84,#FF,#A0			
	db	#FF,#BC,#00,#02,#FF
CRTT3:	db	"a"
	db	"ASCII 8                          $"
	db	#F8,#60,#00,#84,#FF,#40			
	db	#F8,#68,#00,#84,#FF,#60				
	db      #F8,#70,#00,#84,#FF,#80				
	db	#F8,#78,#00,#84,#FF,#A0			
	db	#FF,#AC,#00,#02,#FF
CRTT4:	db	"A"
	db	"ASCII 16                         $"		
	db	#F8,#60,#00,#85,#FF,#40			
	db	#F8,#70,#00,#85,#FF,#80				
	db      #F8,#60,#00,#85,#FF,#C0				
	db	#F8,#70,#00,#85,#FF,#00			
	db	#FF,#8C,#00,#01,#FF
CRTT5:	db	"M"
	db	"Mini ROM (no mapper)             $"		
	db	#F8,#60,#00,#06,#7F,#40			
	db	#F8,#70,#01,#08,#7F,#80				
	db      #F8,#70,#02,#08,#3F,#C0				
	db	#F8,#78,#03,#08,#3F,#A0			
	db	#FF,#8C,#07,#01,#FF
	
	db	0			; end of mapper table


;------------------------------------------------------------------------------

;
; Text strings
;
MAIN_S:	db	13,10
	db	"Main Menu",13,10
	db	"---------",13,10
	db	" 1 - Write ROM image into FlashROM",13,10
	db	" 2 - Create new configuration entry",13,10
	db	" 3 - Show FlashROM's block usage",13,10
	db	" 4 - Restart the computer",13,10
	db	" 7 - RAM/SRAM configuration menu",13,10
	db	" 8 - SD/CF card configuration menu",13,10
	db	" 9 - Service Menu",13,10
	db	" 0 - Exit to MSX-DOS [ESC]",13,10,"$"

UTIL_R:	db	13,10
	db	"RAM/SRAM configuration menu",13,10
	db	"---------------------------",13,10
	db	" 1 - Use on-board 2MB of RAM for mapper",13,10
	db	" 2 - Use on-board 2MB of RAM for Shadow RAM",13,10
	db	" 3 - Set defaults (1MB RAM mapper + 1MB Shadow RAM)",13,10
	db	" 4 - Disable FMPAC SRAM or MSX Audio SRAM",13,10
	db	" 0 - Return to main menu [ESC]",13,10,13,10
	db	" Selecting options 1-2 disables FMPAC or MSX Audio SRAM!",13,10
	db	" Selecting options 1-4 will result in immediate reset!",13,10,"$"

UTIL_C:	db	13,10
	db	"Card Configuration Menu",13,10
	db	"-----------------------",13,10
	db	" 1 - Enable SD card only",13,10
	db	" 2 - Enable CF card only",13,10
	db	" 3 - Enable SD & CF cards (w/o RAM)",13,10
	db	" 4 - Enable SD & CF cards (w/o MUSIC)",13,10
	db	" 0 - Return to main menu [ESC]",13,10,13,10
	db	" Selecting options 1-4 will result in immediate reset!",13,10,"$"

UTIL_S:	db	13,10
	db	"Service Menu",13,10
	db	"------------",13,10
	db	" 1 - Optimize directory entries",13,10
	db	" 2 - Init DefConfig directory entry",13,10
	db	" 3 - Init/Erase all directory entries",13,10
	db	" 4 - Write Boot Menu (bootcmfc.bin)",13,10
	db      " 5 - Write IDE ROM BIOS (bidecmfc.bin)",13,10
	db	" 6 - Write MUSIC ROM BIOS (selectable)",13,10
	db      " 7 - Write SD ROM BIOS (sdsccmfc.bin)",13,10
	db	" 8 - Fully erase FlashROM chip",13,10
	db	" 0 - Return to main menu [ESC]",13,10,"$"

UTIL_M:	db	13,10
	db	"Music Module Selection",13,10
	db	"------------",13,10
	db	" 1 - MSX Music (OPLL) aka FMPAC",13,10
	db	" 2 - SFG-05 FM (OPM)",13,10
	db	" 3 - MSX Audio (OPL1) only FM",13,10
	db	" 0 - Return to Service Menu [ESC]",13,10,"$"

DESCR:	db	"CMFCSDCF"

BTbp_S:	db	"   *--------",#0D,#0A
	db	"   ",124,"*-------",#0D,#0A
	db	"   ",124,124,"*------",#0D,#0A
	db	"   ",124,124,124,"*-----",#0D,#0A
	db	"   ",124,124,124,124,"*----",#0D,#0A
	db	"   ",124,124,124,124,124,"*---",#0D,#0A
	db	"   ",124,124,124,124,124,124,"*--$"	


ImRST:	db	10,13
	db	"Resetting computer to apply new settings...",13,10,"$"

F_NOT_F_S:
	db	"File not found!",13,10,"$"
F_NOT_FS:
	db	13,10,"File not found!","$"
FSizE_S:
	db	"File size error!",13,10,"$"
FR_ER_S:
	db	"File read error!",13,10,"$"
FR_ERS:
	db	13,10,"File read error!","$"
FR_ERW_S:
	db	13,10,"File write error!","$"
FR_ERC_S:
	db	13,10,"File create error!","$"
BadFile:
	db	10,13,"Damaged or incorrect file!",10,13,"$"	
F_LOD_OK:
        db      13,10,"Preset loaded successfully!$"
F_SAV_OK:
        db      13,10,"Preset saved successfully!$"
F_EXIST_S:
        db      13,10,"File already exists, overwrite? (y/n) $"

Analis_S:
	db 	"Detecting ROM's mapper: $"
SelMapT:
	db	"Selected ROM's mapper: $"
NoAnalyze:
	db	"The ROM's mapper is set to: $"

MROMD_S:
	db	"ROM's file size: $" 
CTC_S:	db	"Do you confirm this mapper (y/n)? $"
CoTC_S:	db	10,13,"Manual mapper selection:",13,10,13,10,"$"
Num_S:	db	10,13,"Your selection - $"

MD_Fail:
	db	"FAILED...",13,10,"$"

TestRDT:
	db	"ROM's descriptor table:",10,13,"$"

CRLF:	db	10,13,10,13,"$"

CURSOR:
	db	">>$"
SPACES:
	db	"  $"

PageN:	db	"Page: $"

TWO_NL_S:
	db	13,10
ONE_NL_S:
	db	13,10,"$"

CLS_S:	db	27,"E$"

CLStr_S:
	db	27,"K$"


;------------------------------------------------------------------------------

;
;Variables
;

protect:
	db	1
DOS2:	db	0
ShadowMDR
	db	#21
ERMSlt	db	1
TRMSlt	db	#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF
Binpsl	db	2,0,"1",0
slot:	db	1
cslt:	db	0
Det00:	db	0
Det02:	db	0
Det1C:	db	0
Det1E:	db	0
Det06:	db	0
;Det04:	ds	134
DMAP:	db	0
DMAPt:	db	1
BMAP:	ds	2
Dpoint:	db	0,0,0
StartBL:
	ds	2
C8k:	dw	0
PreBnk:	db	0
EBlock0:
	db	0
EBlock:	db	0
strp:	db	0
strI:	dw	#8000
ROMEXT:	db	".ROM",0
RAM_TEMPL:
	db	"RAM: ",0
BootFNam:
	db	0,"BOOTCMFCBIN"
IDEFNam:
	db	0,"BIDECMFCBIN"
SDFNam:
	db	0,"SDSCCMFCBIN"
FMPACNam:
	db	0,"FMPCCMFCBIN"
SFGNam:
	db	0,"SFGMCMFCBIN"
MSXANam:
	db	0,"MSXACMFCBIN"
MUSICNam:
	db	0,"MUSICNAMBIN"

Bi_FNAM db	14,0,"D:FileName.ROM",0

RCPData:
	ds	30

;--- File Control Blocks
FCB:	db	0
	db	"           "
	ds	28

FCBRCP:	db	0
	db	"           "
	ds	28

FCB2:	db	0
	db	"        RCP"
	ds	28

FCBROM:	db	0
	db	"????????ROM"
	ds	28

RCPExt:	db	"RCP"

FILENAME:
	db    "                                $"

Size:	db	0,0,0,0
Record:	ds	#40
SRSize:	db	0
multi	db	0
ROMABCD:
	db	0
ROMJT0:	db	0
ROMJT1:	db	0
ROMJT2:	db	0
ROMJI0:	db	0
ROMJI1:	db	0
ROMJI2:	db	0

DIRCNT:	db	0,0
DIRPAG:	db	0,0
CURPAG:	db	0,0

; /-flags parameter
F_H	db	0
F_SU	db	0
F_A	db	0
F_V	db	0
F_R	db	0
p1e	db	0

ZeroB:	db	0

Space:
	db	" $"
Bracket:
	db	" ",124," $"

RPCFN:	db	0
	db	"        RCP"

RPC_B:					; 30 byte
	ds	1			; type descriptor symbol
	ds	6			; 1 bank
	ds	6			; 2 bank
	ds	6			; 3 bank
	ds	6			; 4 bank
	ds	5			; rez,CardMDR,MROM,RES,REZ

	db	0,0,0

BAT:	; BAT table ( 8MB/64kB = 128 )
	ds	128	

BUFFER:
	ds	256
	db	0,0,0


;------------------------------------------------------------------------------

;
; Additional text strings
;

   if MODE=80
;------------------ MODE 80 ------------------
DirComr_S:
	db	10,13,"Directory entries will be optimized. Proceed? (y/n) $"
DirComr_E:
	db	13,10,"Directory optimization succeeded.",13,10,"$"
DIRINI_S:
	db	10,13,"WARNING! All directory entries will be erased! Proceed? (y/n) $"
DIRINC_S:
	db	13,10,"Erasing directory succeeded.",13,10,"$"
DIRINC_F:
	db	13,10,"Failed to erase directory!",13,10,"$"
DEFINI_S:
	db	10,13,"WARNING! DefConfig entry will be initialized! Proceed? (y/n) $"
DEFINC_S:
	db	13,10,"DefConfig entry was successfully initialized.",13,10,"$"
DEFINC_F:
	db	13,10,"Failed to initialize DefConfig entry!",13,10,"$"
Boot_I_S:
	db	10,13,"WARNING! Boot Menu will be overwritten! Proceed? (y/n) $"
IDE_I_S:
	db	10,13,"WARNING! IDE BIOS will be overwritten! Proceed? (y/n) $"
SD_I_S:
	db	10,13,"WARNING! SD BIOS will be overwritten! Proceed? (y/n) $"
MUSIC_I_S:
	db	10,13,"WARNING! MUSIC BIOS will be overwritten! Proceed? (y/n) $"
MUSIC_W:
	db	10,13
	db	"This operation is not recommended unless your MUSIC BIOS is damaged or is",10,13
	db	"incompatible with the current firmware. It is advised to use the C2FWUPD",10,13
	db	"utility to flash the compatible MUSIC BIOS together with the firmware.",10,13
	db	"Proceed at your own risk...",10,13,"$"
Flash_C_S:
	db	13,10,"Completed successfully!",13,10,"$"
BootWrit:
	db	"Writing Boot Menu into FlashROM...$"
ANIK_S:
	db	"Press any key to continue",13,10,"$"
EraseWRN1:
	db	10,13,"WARNING! This will erase all data on the chip. Proceed? (y/n) $"
EraseWRN2:
	db	10,13,"DANGER! THE ENTIRE CHIP WILL BE NOW ERASED! PROCEED? (y/n) $"
Erasing:
	db	10,13,"Erasing the FlashROM chip, please wait...$"
EraseOK:
	db	10,13,"FlashROM chip was successfully erased!",13,10,"$"
EraseFail:
	db	10,13,"There was a problem erasing FlashROM chip!",13,10,"$"
ADD_RI_S:
	db	13,10,"Input full ROM's file name or just press Enter to select files: $"
SelMode:
	db	10,13,"Selection mode: TAB - next file, ENTER - select, ESC - exit",10,13,"Found file(s):",9,"$"
NoMatch:
	db	10,13,"No ROM files found in the current directory!",10,13,"$"
OpFile_S:
	db	10,13,"Opening file: ","$"
RCPFound:
	db	"RCP file with the same name found!"
	db	10,13,"Use loaded RCP data for this ROM? (y/n) $"
UsingRCP:
	db	"Autodetection ignored, using data from RCP file...",10,13,"$"

FileOver_S:
	db	"File is too big or there's no free space on the FlashROM chip!",13,10,"$"
MRSQ_S:	db	10,13,"The ROM's size is between 32kb and 64kb. Create Mini ROM entry? (y/n)",13,10,"$"
Strm_S:	db	"MMROM-CSRM: $"
NFNR_S:	db	"No free Multi ROM entries found. A new 64kb block will be allocated",10,13,"$"
FNRE_S:	db	"Using Record-FBlock-NBank for Mini ROM",13,10
	db	"[Multi ROM entry] - $"
DirOver_S:
	db	"No more free directory entries!",13,10
DirCmpr:db	"Optimize directory entries now? (y/n)",13,10,"$"
FFFS_S:	db	"Found free space at: $"
FDE_S:	db	"Found free directory entry at: $"
NR_I_S:	db	"Name of directory entry: $"
FileSZH:
	db	"File size (hexadecimal): $"
NR_L_S: db	"Press ENTER to confirm or input a new name below:",13,10,"$"
FLEB_S:	db	"Erasing FlashROM chip's block(s): $"
FLEBE_S:db	"Error erasing FlashROM chip's block(s)!",13,10,"$"
LFRI_S:	db	"Writing ROM image, please wait...",13,10,"$"
Prg_Su_S:
	db	13,10,"ROM image was successfully written into FlashROM!",13,10,"$"
FL_er_S:
	db	13,10,"Writing into FlashROM failed!",13,10,"$"
FL_erd_S:
	db	13,10,"Writing directory entry failed!",13,10,"$"
RDELQ_S:
	db	"Delete this entry? (y/n) $"
NODEL:	db	"Entry can't be deleted! Press any key...$"
LOAD_S: db      "Ready to write the ROM image. Proceed? (y/n) $"
MapBL:	db	"Map of FlashROM chip's 64kb blocks (FF = reserved, 00 = empty):",13,10,"$"

ConfName:
	db	10,13,"Input new configuration entry name:",10,13,"$"
ExtSlot:
	db	10,13,"Enable extended slot? (y/n) $"
MapRAM:
	db	10,13,"Enable RAM and Mapper? (y/n) $"
FmOPLL:
	db	10,13,"Enable MUSIC module? (y/n) $"
IDEContr:
	db	10,13,"Enable DISK controller? (y/n) $"
MultiSCC:
	db	10,13,"Enable SCC and MultiMapper? (y/n) $"
EntryOK:
	db	10,13,"Configuration entry added successfully!",10,13,"$"
EntryFAIL:
	db	10,13,"Failed to create configuration entry!",10,13,"$"
NothingE:
	db	10,13,"Input ignored: at least one device must be enabled!",10,13,"$"
MapTop:	
	db	"     00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F",10,13
	db	"     -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --$"
;------------------ MODE 80 ------------------
   else
;------------------ MODE 40 ------------------
DirComr_S:
	db	10,13,"Optimize the directory? (y/n) $"
DirComr_E:
	db	13,10,"Optimizing directory succeeded.",13,10,"$"
DIRINI_S:
	db	10,13,"WARNING! Erase directory? (y/n) $"
DIRINC_S:
	db	13,10,"Erasing directory succeeded.",13,10,"$"
DIRINC_F:
	db	13,10,"Failed to erase directory!",13,10,"$"
DEFINI_S:
	db	10,13,"WARNING! Init DefConfig? (y/n) $"
DEFINC_S:
	db	13,10,"DefConfig initialized.",13,10,"$"
DEFINC_F:
	db	13,10,"Failed to initialize DefConfig!",13,10,"$"
Boot_I_S:
	db	10,13,"WARNING! Overwrite Boot Menu? (y/n) $"
NO_B_UPD:
	db	10,13,"BIOS shadowing failed, so no BIOS"
	db	10,13,"update is possible! To override, use"
	db	10,13,"the '/su' option at your own risk...",10,13,"$"
IDE_I_S:
	db	10,13,"WARNING! Overwrite IDE BIOS? (y/n) $"
SD_I_S:
	db	10,13,"WARNING! Overwrite SD BIOS? (y/n) $"
MUSIC_I_S:
	db	10,13,"WARNING! Overwrite MUSIC BIOS? (y/n) $"
MUSIC_W:
	db	10,13
	db	"This operation is not recommended unless",10,13
	db	"your MUSIC BIOS is damaged or is",10,13
	db	"incompatible with the current firmware.",10,13
	db	"It's advised to use the C2FWUPD utility",10,13
	db	"to flash the compatible MUSIC BIOS",10,13
	db	"together with the firmware.",10,13
	db	"Proceed at your own risk...",10,13,"$"
Flash_C_S:
	db	13,10,"Completed successfully!",13,10,"$"
BootWrit:
	db	"Writing Boot Menu into FlashROM...$"
ANIK_S:
	db	"Press any key to continue",13,10,"$"
EraseWRN1:
	db	10,13,"WARNING! Erase FlashROM chip? (y/n) $"
EraseWRN2:
	db	10,13,"DANGER! ERASE ALL CHIP'S DATA? (y/n) $"
Erasing:
	db	10,13,"Erasing FlashROM chip, please wait...$"
EraseOK:
	db	10,13,"FlashROM chip successfully erased!",13,10,"$"
EraseFail:
	db	10,13,"Erasing FlashROM chip failed!",13,10,"$"
ADD_RI_S:
	db	13,10,"Input full ROM's file name or just",10,13,"press Enter to select files:",10,13,"$"
SelMode:
	db	10,13,"Selection mode: TAB - next file,",10,13,"ENTER - select, ESC - exit",10,13,"Found file(s):",9,"$"
NoMatch:
	db	10,13,"No ROM files were found!",10,13,"$"
OpFile_S:
	db	10,13,"Opening file: ","$"
RCPFound:
	db      "RCP file with the same name found!"
	db	10,13,"Use RCP data for this ROM? (y/n) $"
UsingRCP:
	db	"Autodetection ignored.",10,13,"Using data from RCP file...",10,13,"$"

FileOver_S:
	db	"File is too big or there's no free space",10,13,"on the FlashROM chip!",13,10,"$"
MRSQ_S:	db	10,13,"ROM's size is between 32kb and 64kb.",10,13,"Create Mini ROM entry? (y/n)",13,10,"$"
Strm_S:	db	"MMROM-CSRM: $"
NFNR_S:	db	"No free Multi ROM entries found.",10,13,"A new 64kb block will be allocated",10,13,"$"
FNRE_S:	db	"Using Record-FBlock-NBank for Mini ROM",13,10
	db	"[Multi ROM entry] - $"
DirOver_S:
	db	"No more free directory entries!",13,10
DirCmpr:db	"Optimize directory entries? (y/n)",13,10,"$"
FFFS_S:	db	"Found free space at: $"
FDE_S:	db	"Found free directory entry at: $"
NR_I_S:	db	"Name of directory entry: $"
FileSZH:
	db	"File size (hexadecimal): $"
NR_L_S: db	"Use ENTER to confirm or type new name:",13,10,"$"
FLEB_S:	db	"Erasing FlashROM chip's block(s) - $"
FLEBE_S:db	"Error erasing FlashROM's block(s)!",13,10,"$"
LFRI_S:	db	"Writing ROM image, please wait...",13,10,"$"
Prg_Su_S:
	db	13,10,"ROM image was written successfully!",13,10,"$"
FL_er_S:
	db	13,10,"Writing into FlashROM failed!",13,10,"$"
FL_erd_S:
	db	13,10,"Writing directory entry failed!",13,10,"$"
RDELQ_S:
	db	" - Delete this entry? (y/n)$"
NODEL:	db	"Entry can't be deleted! Press any key...$"
LOAD_S: db      "Ready to write the ROM image.",10,13
	db	"Proceed (y/n)? $"
MapBL:	db	"Map of FlashROM chip's 64kb blocks",10,13
	db	"(FF = reserved, 00 = empty):",13,10,"$"

ConfName:
	db	10,13,"Input new configuration entry name:",10,13,"$"
ExtSlot:
	db	10,13,"Enable extended slot? (y/n) $"
MapRAM:
	db	10,13,"Enable RAM and Mapper? (y/n) $"
FmOPLL:
	db	10,13,"Enable MUSIC module? (y/n) $"
IDEContr:
	db	10,13,"Enable DISK controller? (y/n) $"
MultiSCC:
	db	10,13,"Enable SCC and MultiMapper? (y/n) $"

EntryOK:
	db	10,13,"Configuration entry added successfully!",10,13,"$"
EntryFAIL:
	db	10,13,"Failed to create configuration entry!",10,13,"$"
NothingE:
	db	10,13,"Ignored! Enable at least one device!",10,13,"$"
MapTop:	
	db	"      0 1 2 3 4 5 6 7 8 9 A B C D E F",10,13
	db	"     --------------------------------$"
;------------------ MODE 40 ------------------
   endif

;
; Common strings for both C2MAN and C2MAN40 utilities
;

ABCD:	db	"0123456789ABCDEF"
SSR_S:	db	"Select ROM's size:$"
ssrMAP:	db	"64kb or more (mapper is required)$"
ssr64:	db	"64kb$"
ssr48:	db	"48kb$"
ssr32:	db	"32kb$"
ssr16:	db	"16kb$"
ssr08:	db	"8kb or less$"

EXIT_S:	db	10,13,"Thanks for using RBSC's products!",13,10,"$"


;------------------------------------------------------------------------------

	org	#4000

BUFTOP:
	db	"16kb reserved area at #4000"

;------------------------------------------------------------------------------

;
; Extra area for single-use code and data
;

	org	#8000


; Command line messages
;
I_FLAG_S:
	db	"Incorrect flag!",13,10,13,10,"$"
I_PAR_S:
	db	"Incorrect parameter!",13,10,13,10,"$"
I_MPAR_S:
	db	"Too many parameters!",13,10,13,10,"$"

   if MODE=80
;------------------ MODE 80 ------------------
PRESENT_S:
	db	3
	db	"Carnivore2+ Manager v3.10",13,10
	db	"(C) 2025 RBSC. All rights reserved",13,10,13,10,"$"
NSFin_S:
	db	"Carnivore2+ cartridge was not found. Please specify its slot number - $"
Findcrt_S:
	db	"Found Carnivore2+ cartridge in slot(s): $"
M_Wnvc:
	db	10,13,"WARNING!",10,13
	db	"Uninitialized cartridge or wrong version of Carnivore cartridge found!",10,13
	db	"Using this utility with the wrong cartridge version may damage data on it!",10,13
	db	"Proceed only if you have an unitialized Carnivore2+ cartridge. Continue? (y/n)",10,13,"$"
FindcrI_S:
	db	13,10,"Press ENTER for the found slot or input new slot number - $"
;USEDOS2_S:
;	db	"*** DOS2 has been detected ***",10,13
SltN_S:	db	13,10,"Using slot - $"

M_Shad:	db	"Copying ROM BIOS to RAM (shadow copy): $"
Shad_S:	db	"OK",10,13,"$"
Shad_F:	db	"FAILED!",10,13,"$"

M29W640:
        db      "FlashROM chip detected: M29W640G$"
NOTD_S:	db	13,10,"FlashROM chip's type is not detected!",13,10
	db	"This cartridge is not open for writing or may be defective!",13,10
	db	"Try to reboot and hold down F5 key...",13,10 
	db	"$"
MfC_S:	db	"Manufacturer's code: $"
DVC_S:	db	"Device's code: $"
EMB_S:	db	"Extended Memory Block: $"
EMBF_S:	db	"EMB Factory Locked",13,10,"$"
EMBC_S:	db	"EMB Customer Lockable",13,10,"$"

H_PAR_S:
	db	"Usage:",13,10,13,10
	db	" c2man [filename.rom] [/h] [/v] [/a] [/r]",13,10,13,10
	db	"Command line options:",13,10
	db	" /h  - this help screen",13,10
	db	" /v  - verbose mode (detailed information)",13,10
	db	" /a  - autodetect and flash ROM image (no user interaction)",13,10
	db	" /r  - automatically restart MSX after flashing ROM image",10,13
	db	" /su - enable Super User mode",13,10
	db	"       (BIOS writing without shadow copy)",10,13,"$"

NO_B_UPD:
	db	10,13,"BIOS shadowing failed, so no BIOS update is possible!"
	db	10,13,"To override, use the '/su' option at your own risk...",10,13,"$"
;------------------ MODE 80 ------------------
   else
;------------------ MODE 40 ------------------
PRESENT_S:
	db	3
	db	"Carnivore2+ Manager v3.10",13,10
	db	"(C) 2025 RBSC. All rights reserved",13,10,13,10,"$"
NSFin_S:
	db	"Carnivore2+ cartridge was not found.",10,13
	db	"Please specify its slot number - $"
Findcrt_S:
	db	"Found Carnivore2+ cartridge in slot(s):",10,13,"$"
M_Wnvc:
	db	10,13,"WARNING!",10,13
	db	"Uninitialized cartridge or wrong version"
	db	"of Carnivore cartridge found!",10,13
	db	"Using this utility with the wrong",10,13
	db	"cartridge version may damage data on it!"
	db	"Proceed only if you have an unitialized",10,13
	db	"Carnivore2+ cartridge. Continue? (y/n)",10,13,"$"
FindcrI_S:
	db	13,10,"Press ENTER for the found slot",10,13,"or input new slot number - $"
;USEDOS2_S:
;	db	"*** DOS2 has been detected ***",10,13
SltN_S:	db	13,10,"Using slot - $"

M_Shad:	db	"Copying ROM BIOS to RAM (shadow copy):",10,13,"$"
Shad_S:	db	"OK",10,13,"$"
Shad_F:	db	"FAILED!",10,13,"$"

M29W640:
        db      "FlashROM chip detected: M29W640G$"
NOTD_S:	db	13,10,"FlashROM chip's type is not detected!",13,10
	db	"This cartridge may be defective!",13,10
	db	"Try to reboot and hold down F5 key...",13,10 
	db	"$"
MfC_S:	db	"Manufacturer's code: $"
DVC_S:	db	"Device's code: $"
EMB_S:	db	"Extended Memory Block: $"
EMBF_S:	db	"EMB Factory Locked",13,10,"$"
EMBC_S:	db	"EMB Customer Lockable",13,10,"$"

H_PAR_S:
	db	"Usage:",13,10,13,10
	db	"c2man40 [file.rom] [/h] [/v] [/a] [/r]",13,10,13,10
	db	"Command line options:",13,10
	db	" /h  - this help screen",13,10
	db	" /v  - verbose mode (detailed info)",13,10
	db	" /a  - autodetect and flash ROM image",13,10
	db	" /r  - restart MSX after flashing ROM image",10,13
	db	" /su - enable Super User mode",13,10
	db	"       (BIOS writing without shadow copy)",10,13,"$"
;------------------ MODE 40 ------------------
   endif

NOTE:	db	"NOTE:",10,13
	db	"This program is not optimized to run",10,13
	db	"in the 40 character mode. You should",10,13
	db	"use the C2MAN40.COM utility instead.",10,13
	db	"Exiting now...",10,13,"$"


;------------------------------------------------------------------------------

; One-time code


; Print note for MSX1 and MSX1 with VDP 9938
PrintNote:
	ld	a,(SCR0WID)
	cp	40
	jr	c,PrNote1
	jr	z,PrNote1

	ld	a,(VDPVER)
	or	a
	jp	nz,PRTITLE

PrNote1:
	ld	a,(#80)			; if no command line parameters found
	or	a
	jp	nz,PRTITLE

	print	NOTE
	call	SymbIn			; print note and ask for action if VDP < v9938
	or	%00100000
	call	SymbOut
	push	af
	print	CRLF			; skip 2 lines
	pop	af
	cp	"y"
	jp	z,PRTITLE

	ld	c,_TERM0
	jp	DOS


; Process command line options
CmdLine:
	ld	a,1
	call	F_Key			; C- no parameter; NZ- not flag; S(M)-ilegal flag
	jp	c,Stfp01
	jr	nz,Stfp07
	jp	p,Stfp02
Stfp03:
	print	I_FLAG_S
	jr	Stfp09
Stfp07:
	ld	a,1
	ld	(p1e),a			; File parameter exists!

Stfp02:
	ld	a,2
	call	F_Key
	jr	c,Stfp01
	jp	m,Stfp03
	jr	z,Stfp04
Stfp05:
	print	I_PAR_S
Stfp09:	
	print	H_PAR_S
	jp	Exit
Stfp04:
	ld	a,3
	call	F_Key
	jr	c,Stfp01
	jp	m,Stfp03
	jr	nz,Stfp05
	ld	a,4
	call	F_Key
	jr	c,Stfp01
	jp	m,Stfp03
	jr	nz,Stfp05
	ld	a,5
	call	F_Key
	jr	c,Stfp01
	jp	m,Stfp03
	jr	nz,Stfp05
	print	I_MPAR_S
	jr	Stfp09
Stfp01:
	ld	a,(p1e)
	jr	nz,Stfp06		; if not file parameter
	xor	a
	ld	(F_A),a			; Automatic flag not active
Stfp06:
	ld	a,(F_SU)
	or	a
	jr	z,Stfp08
	xor	a
	ld	(protect),a
Stfp08:
	ld	a,(F_H)
	or	a
	jr	nz,Stfp09
	ret

F_Key:
; Input A - Num parameter
; Output C,Z Flags, set key variable

	ld	de,BUFFER
	call	EXTPAR
	ret	c			; no parameter C- Flag
	ld	hl,BUFFER
	ld	a,(hl)
fkey01:	cp	"/"
	ret	nz			; no Flag NZ - Flag
	inc	hl
	ld	a,(hl)
	and	%11011111
	cp	"S"
	jr	nz,fkey02
	inc	hl
	ld	a,(hl)
	and	%11011111
	cp	"U"
	jr	nz,fkey02
	inc	hl
	ld	a,(hl)
	or	a
	jr	nz,fkey02
	ld	a,1
	ld	(F_SU),a
	ret
fkey02:	ld	hl,BUFFER+1
	ld	a,(hl)
	and	%11011111
	cp	"A"
	jr	nz,fkey03
	inc	hl
	ld	a,(hl)
	or	a
	jr	nz,fkey03
	ld	a,2
	ld	(F_A),a
	ret
fkey03:	ld	hl,BUFFER+1
	ld	a,(hl)
	and	%11011111
	cp	"V"
	jr	nz,fkey04
	inc	hl
	ld	a,(hl)
	or	a
	jr	nz,fkey04
	ld	a,3
	ld	(F_V),a			; verbose mode flag
	ret
fkey04:	ld	hl,BUFFER+1
	ld	a,(hl)
	and	%11011111
	cp	"H"
	jr	nz,fkey05
	inc	hl
	ld	a,(hl)
	or	a
	jr	nz,fkey05
	ld	a,4
	ld	(F_H),a			; show help
	ret
fkey05:
	ld	hl,BUFFER+1
	ld	a,(hl)
	and	%11011111
	cp	"R"
	jr	nz,fkey06
	inc	hl
	ld	a,(hl)
	or	a
	jr	nz,fkey06
	ld	a,5
	ld	(F_R),a			; reset flag
	ret
fkey06:
	xor	a
	dec	a			; S - Illegal flag
	ret


; Test if the VDP is a TMS9918A
; Out A: 0=9918, 1=9938, 2=9958
;
DetVDP:
	in	a,(#99)		; read s#0, make sure interrupt flag is reset
	di
DetVDPW:
	in	a,(#99)		; read s#0
	and	a		; wait until interrupt flag is set
	jp	p,DetVDPW
	ld	a,2		; select s#2 on V9938
	out	(#99),a
	ld	a,15+128
	out	(#99),a
	nop
	nop
	in	a,(#99)		; read s#2 / s#0
	ex	af,af'
	xor	a		; select s#0 as required by BIOS
	out	(#99),a
	ld	a,15+128
	ei
	out	(#99),a
	ex	af,af'
	and	%01000000	; check if bit 6 was 0 (s#0 5S) or 1 (s#2 VR)
	or	a
	ret	z

	ld	a,1		; select s#1
	di
	out	(#99),a
	ld	a,15+128
	out	(#99),a
	nop
	nop
	in	a,(#99)		; read s#1
	and	%00111110	; get VDP ID
	rrca
	ex	af,af'
	xor	a		; select s#0 as required by BIOS
	out	(#99),a
	ld	a,15+128
	ei
	out	(#99),a
	ex	af,af'
	jr	z,DetVDPE	; VDP = 9938?
	inc	a
DetVDPE:
	inc	a
	ld	(VDPVER),a
	ret


;------------------------------------------------------------------------------

; Footer

	db	0
	db	"RBSC:PTERO/WIERZBOWSKY/DJS3000/PYHESTY/GREYWOLF/SUPERMAX/VWARLOCK/TNT23/ALSPRU:2025"
	db	0,0,0
