;
; Carnivore2+ Cartridge's Firmware Updater
; Copyright (c) 2025 RBSC
; Version 3.01
;

; !COMPILATION OPTIONS!

SPC	equ	0			; 1 = for Arabic and Korean computers
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


	;--- System variables and routines

DOS:	equ	#0005		; DOS function calls entry point
ENASLT:	equ	#0024		; BIOS Enable Slot
WRTSLT:	equ	#0014		; BIOS Write to Slot
CALLSLT:equ	#001C		; Inter-slot call
SCR0WID	equ	#F3AE		; Screen0 width

TPASLOT1:	equ	#F342
TPASLOT2:	equ	#F343
CSRY	equ	#F3DC
CSRX	equ	#F3DD
CURSF	equ	#FCA9
VDPVER	equ	#F56A
ARG:	equ	#F847
EXTBIO:	equ	#FFCA
MNROM:   equ    #FCC1		; Main-ROM Slot number & Secondary slot flags table

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

sfl_CFG equ     #4F80+#37

;--- Important constants

L_STR:	equ	16	 		; number of entries on the screen


	;--- DOS function calls

_TERM0:	equ	#00	;Program terminate
_CONIN:	equ	#01	;Console input with echo
_CONOUT:	equ	#02	;Console output
_DIRIO:	equ	#06	;Direct console I/O
_INNOE:	equ	#08	;Console input without echo
_STROUT:	equ	#09	;String output
_BUFIN:	equ	#0A	;Buffered line input
_CONST:	equ	#0B	;Console status
_FOPEN: equ	#0F	;Open file
_FCLOSE	equ	#10	;Close file
_FCREATE: equ    #16	;Create file
_SDMA:	equ	#1A	;Set DMA address
_RBREAD:	equ	#27	;Random block read
_RBWRITE: 	equ	#26	;Random block write
_TERM:	equ	#62	;Terminate with error code
_DEFAB:	equ	#63	;Define abort exit routine
_DOSVER:	equ	#6F	;Get DOS version


;************************
;***                  ***
;***   MAIN PROGRAM   ***
;***                  ***
;************************

	org	#100			; Needed for programs executing under MSX-DOS

	;------------------------
	;---  Initialization  ---
	;------------------------

; Set screen
	call	DetVDP
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
	xor	a
	ld	(F_A),a
	ld	(F_V),a

	print	PRESENT_S

	call	FindSlot
	jp	c,Exit

	print	M_Shad
	call	Shadow			; shadow bios for C2
	ld	a,(ShadowMDR)
	cp	#21			; shadowing failed?
	jr	z,ShadF
	print	Shad_S
	jr	DetEEPR
ShadF:
	print	Shad_F			; failed shadowing
	jp	Exit

DetEEPR:
        ld      a,(ERMSlt)
        ld      h,#40			; Set 1 page
        call    ENASLT
	ld	a,#8D			; ROM off
	ld	(R1Mult),a

	call 	SFL_init    		; Wake UP and read ID eerpom

;-------------------------
;	push	af
;	push	af
;	print	CRLF_S
;	print	EPCS_ID
;	pop	af
;	call	HEXOUT			; For debugging only
;	print	CRLF_S
;	pop	af
;-------------------------

	ld	ix,T_EPCS1
	cp      #10			; 128kb
	jr	z,Det1
	ld	ix,T_EPCS4
	cp	#12			; 512kb
	jr	z,Det1
	ld	ix,T_EPCS16
	cp	#14			; 2mb
	jr	z,Det1
	ld	ix,T_EPCS64
	cp	#16			; 16mb
	jr	z,Det1
	ld	ix,UNK_EPCS
	cp	#FF			; Unknown, assuming EPCS4
	jr	z,Det1
NoGood:
	print	unc_EPCS		; unknown or incompatible EEPROM
	jp	Exit
Det1:
	ld	l,(ix)			; Get data from Tabl
	ld	h,(ix+1)
	ld	(FsflSz),hl		; Data size / 256
	ld	a,h
	cp	2			; small EEPROM?
	jr	z,NoGood

	push	ix
	print	T_EEPROM		; Print detection string
	pop 	de			; Get data from Tabl (Text)
	inc	de
	inc	de
	ld	c,_STROUT		; Print String from DE - EEPROM type
	call	DOS

        ld      a,(TPASLOT1)
        ld      h,#40			; Set 1 page
        call    ENASLT

; Test #1000 of ram for firmware
TestR:
	print	TstRam			; print test ram
	ld	d,0
	call	TestRAM			; test1 #00
	or	a
	jr	nz,TestRE
	ld	d,#FF
	call	TestRAM			; test2 #FF
	or	a
	jr	nz,TestRE
	ld	d,#55
	call	TestRAM			; test3 #55
	or	a
	jr	nz,TestRE
	ld	d,#AA
	call	TestRAM			; test4 #AA
	or	a
	jr	nz,TestRE
	print	FlCompl			; print complete
	jr	MainM
TestRE:
	print	TestRamE		; error in RAM test
	jp	Exit


; Main menu
MainM:
	xor	a
	ld	(CURSF),a
	ld	(Fsadp),a
	ld	(Fsadp+1),a
	ld	(Fsadp+2),a
	ld	(GithubMess),a

; #DEBUG	
;	ld	(VTEMP),sp
;	ld	a,(VTEMP+1)
;	call	HEXOUT
;	ld	a,(VTEMP)
;	call	HEXOUT
; #DEBUG

	print	MAIN_S			; print main menu
Ma01:
	ld	a,1
	ld	(CURSF),a
	call	SymbIn			; input 1 symbol
	push	af
	xor	a
	ld	(CURSF),a
	pop	af
	cp	"0"
	jp	z,Exit
	cp	27
	jp	z,Exit
	cp	"1"
	jp	z,FWBackup
	cp	"2"
	jp	z,UpdMenu
	jr	Ma01

UpdMenu:
	print	MAIN_U			; print main menu
Upd01:
	ld	a,1
	ld	(CURSF),a
	call	SymbIn			; input 1 symbol
	push	af
	xor	a
	ld	(CURSF),a
	pop	af
	cp	"0"
	jp	z,MainM
	cp	27
	jp	z,MainM
	cp	"1"
	jp	z,FWU_BACK
	cp	"2"
	jp	z,FWU_FMPAC
	cp	"3"
	jp	z,FWU_SFG
	cp	"4"
	jp	z,FWU_MSXAU
	jr	Upd01


; Backup
FWU_BACK:
	print	SelFW
	call	CleanFCB
	ld	hl,FW_BACK
	ld	de,FCBN+1
	ld	bc,8
	push	hl
	ldir
	pop	hl
	ld	de,FCBC+1
	ld	bc,8
	push	hl
	ldir	
	pop	hl
	ld	de,FCBR+1
	ld	bc,8
	ldir	
	print	Q_Prog1
	jp	m004

; FMPAC
FWU_FMPAC:
	print	SelFMPAC
	call	CleanFCB
	ld	hl,FW_FMPAC
FWU_M:
	ld	de,FCBN+1
	ld	bc,8
	push	hl
	ldir
	pop	hl
	ld	de,FCBC+1
	ld	bc,8
	push	hl
	ldir	
	pop	hl
	ld	de,FCBR+1
	ld	bc,8
	ldir	
	jp	FWUpdate

; SFG
FWU_SFG:
	print	SelSFG
	call	CleanFCB
	ld	hl,FW_SFG05
	jp	FWU_M

; MSX AUDIO
FWU_MSXAU:
	print	SelMSXA
	call	CleanFCB
	ld	hl,FW_MSXAU
	jp	FWU_M

;
; Backup firmware
;
FWBackup:
	call	CleanFCB1		; Clear FCB

	ld	c,_FOPEN		; Check existing file
	ld	de,FCB
	call	DOS
	or	a			; check for old file
	jr	nz,m0003
	ld	c,_FCLOSE
	ld	de,FCB
	call	DOS

	print	FlExists		; Overwrite file?
m0000:
	call	SymbIn
	or	%00100000
	cp	"y"
	jr	z,m0003
	cp	"n"
	jr	z,m0001
	jr	m0000
m0001:
	call	SymbOut
	print	ONE_NL_S
	jp	MainM

m0003:
	call	SymbOut
	ld	a,#78
	ld	(FWCRC),a
	ld	a,#56
	ld	(FWCRC+1),a
	ld	a,#34
	ld	(FWCRC+2),a
	ld	a,#12
	ld	(FWCRC+3),a		; original value with salt

	print	FlStSs			; Print "backuping EEPROM"
	ld	c,_FCREATE		; Create save file
	ld	de,FCB
	call	DOS
	or	a
	jr	z,m001
	print	FlCrErr			; File creation error
	print	ONE_NL_S
	jp	MainM
m001:
        ld	c,_SDMA			; Set DMA address
	ld	de,FBUFF		; 2-page slot RAM
	call	DOS
        ld      a,(ERMSlt)
        ld      h,#40			; Set 1 page ERM
        call    ENASLT

	ld	e,"."			; print "."
	ld	c,_CONOUT
	call	DOS

	ld	de,FBUFF		; read buffer
	ld	hl,(Fsadp+1)		; current eeprom address point Fsadp
	ld	a,(Fsadp)
	ld	bc,#1000		; max lenght eeprom i/o windows
	call    SFL_read

	ld	bc,#0010		; increment eeprom address point
	ld	hl,(Fsadp+1)
	xor	a
	adc	hl,bc
	ld	(Fsadp+1),hl		; Low byte (Fsadp) not change

        ld      a,(TPASLOT1)
        ld      h,#40			; Set 1 page DOS
        call    ENASLT

	ld	c,_RBWRITE		; Write block #1000
	ld	de,FCB
	ld	hl,#1000
	ld	(FCB+14),hl
	ld	hl,1
	call	DOS
	or	a
	jr	z,m002
	ld	c,_FCLOSE
	ld	de,FCB
	call	DOS
	print	FlWrErr 	        ; File writing error
	print	ONE_NL_S
	jp	MainM
m002:
	ld	bc,#1000
	call	Calc_CRC		; calculate segment's CRC
	xor	a 			; Check if complete
        ld	hl,(Fsadp+1)
	ld	bc,(FsflSz)
	sbc	hl,bc
	jp	c,m001			; Read next block

	ld	c,_FCLOSE
	ld	de,FCB
	call	DOS

SaveCRC:
	print	CreateCRC		; Print "Creating CRC"
	ld	c,_FCREATE		; Create save file
	ld	de,FCB1
	call	DOS
	or	a
	jr	z,m001a
	print	FlCrErr         	; File creation error
	print	ONE_NL_S
	jp	MainM
m001a:
	ld	a,(FWCRC)
	call	HEXOUTI
	ld	a,d
	ld	(CRCPL+6),a
	ld	a,e
	ld	(CRCPL+7),a
	ld	a,(FWCRC+1)
	call	HEXOUTI
	ld	a,d
	ld	(CRCPL+4),a
	ld	a,e
	ld	(CRCPL+5),a
	ld	a,(FWCRC+2)
	call	HEXOUTI
	ld	a,d
	ld	(CRCPL+2),a
	ld	a,e
	ld	(CRCPL+3),a
	ld	a,(FWCRC+3)
	call	HEXOUTI
	ld	a,d
	ld	(CRCPL),a
	ld	a,e
	ld	(CRCPL+1),a		; insert calculated CRC

        ld	c,_SDMA			; Set DMA address
	ld	de,CRCTEMPL		; Template for CRC file
	call	DOS
        ld      a,(TPASLOT1)
        ld      h,#40			; Set 1 page DOS
        call    ENASLT
	ld	c,_RBWRITE		; Write CRC
	ld	de,FCB1
	ld	hl,30			; size
	ld	(FCB1+14),hl
	ld	hl,1
	call	DOS
	or	a
	jr	z,m002a
	ld	c,_FCLOSE
	ld	de,FCB1
	call	DOS
	print	FlWrErr			; File writing error
	print	ONE_NL_S
	jp	MainM
m002a:
	ld	c,_FCLOSE
	ld	de,FCB1
	call	DOS

	print	CreateROM		; Print "Creating ROM"
	ld	de,FCB2
	ld	c,_FCREATE
	call	DOS			; create ROM
	or	a
	jr	z,rdt923
	print	FlCrErr			; File creation error
	print	ONE_NL_S
	jp	MainM

rdt923:
	ld      hl,#2000
	ld      (FCB2+14),hl		; Record size = 8192 bytes
        ld      a,(ERMSlt)
        ld      h,#40
        call    ENASLT

	ld	a,#20
	ld	(CardMDR),a		; immediate changes in place
	xor	a
	ld	(CardMDR+#0E),a		; set 2nd bank to start of FlashROM
	ld	a,3
	ld	(AddrFR),a		; third flash block

	ld	a,#08
	ld	(CardMDR+#15),a		; disable third bank
	ld	(CardMDR+#1B),a		; disable forth bank

	ld	hl,B2ON1
	ld	de,CardMDR+#0C		; set Bank2
	ld	bc,6
	ldir
 
	ld	a,(ERMSlt)		; enable page at #8000
	ld	h,#80
	call	ENASLT
	ld      c,_SDMA
	ld      de,#4000
	call    DOS			; set DMA

rdt989:
	ld      a,(TPASLOT1)
	ld      h,#40
	call    ENASLT			; enable RAM for #4000

	di
	ld	hl,#8000
	ld	de,#4000
	ld	bc,#2000
	ldir				; copy contents to RAM
	ei

	ld	hl,1
	ld	de,FCB2
	ld	c,_RBWRITE
	call	DOS			; write 8192 bytes of ROM contents
	or	a
	jr	z,rdt990

	ld	c,_FCLOSE
	ld	de,FCB2
	call	DOS
	print	FlWrErr			; File writing error
	print	ONE_NL_S
	jp	MainM

rdt990:
        ld      a,(ERMSlt)
        ld      h,#40
        call    ENASLT

	ld	a,(CardMDR+#0E)
	inc	a
	cp	8
	jr	z,rdt991
	ld	(CardMDR+#0E),a
	jp	rdt989
	
rdt991:
	ld	de,FCB2
	ld	c,_FCLOSE
	call	DOS

	print	FlWrSs 			; Files saved successfully

; Restore slot configuration!
        ld      a,(ERMSlt)
        ld      h,#40
        call    ENASLT
	ld	a,#28
	ld	(CardMDR),a		; immediate changes off
;	ld	hl,B1ON
;	ld	de,CardMDR+#06		; set Bank1
;	ld	bc,6
;	ldir
	xor	a
	ld	(AddrFR),a
	ld	(CardMDR+#0E),a
	ld	(EBlock),a
	ld	(PreBnk),a
	ld	a,#24      		; Disable SFL port
	ld	(sfl_CFG),a
	ld	a,#85			; ROM enabled
	ld	(R1Mult),a
        ld      a,(TPASLOT1)
        ld      h,#40
        call    ENASLT
        ld      a,(TPASLOT2)
        ld      h,#80
        call    ENASLT         		; Select Main-RAM at bank 8000h~BFFFh
	jp	MainM


;
; Clean FCBs
;
CleanFCB:
	ld	hl,FCBN+1+8+3		; Clear FCB for BIN
	ld	b,28
	xor	a
clnloop1:
	ld	(hl),a
	inc	hl
	djnz	clnloop1

	ld	hl,FCBC+1+8+3		; Clear FCB for CRC
	ld	b,28
	xor	a
clnloop2:
	ld	(hl),a
	inc	hl
	djnz	clnloop2

	ld	hl,FCBR+1+8+3		; Clear FCB for ROM
	ld	b,28
	xor	a
clnloop3:
	ld	(hl),a
	inc	hl
	djnz	clnloop3
	ret

CleanFCB1:
	ld	hl,FCB+1+8+3		; Clear FCB for FIRMWARE.BIN
	ld	b,28
	xor	a
clnloop4:
	ld	(hl),a
	inc	hl
	djnz	clnloop4

	ld	hl,FCB1+1+8+3		; Clear FCB for FIRMWARE.CRC
	ld	b,28
	xor	a
clnloop5:
	ld	(hl),a
	inc	hl
	djnz	clnloop5

	ld	hl,FCB2+1+8+3		; Clear FCB for FIRMWARE.ROM
	ld	b,28
	xor	a
clnloop6:
	ld	(hl),a
	inc	hl
	djnz	clnloop6
	ret


;
; Update firmware
;
FWUpdate:
	print   Q_BackFW		; Backup firmware?
m0035:	call	SymbIn
	or	%00100000
	cp	"y"
	jr	z,m0037
	cp	"n"
	jr	z,m0036
	jr	m0035
m0036:
	call	SymbOut
	print   M_BackFW		; Instruction
	jp	MainM

m0037:
	call	SymbOut
	print   Q_Prog			; Print warning and question to update firmware
m004:
	call	SymbIn
	or	%00100000
	cp	"p"			; proceed
	jr	z,m005
	cp	"e"			; exit
	jr	z,me004
	jr	m004
me004:
	call	SymbOut
	print	ONE_NL_S
	jp	MainM

m005:
	call	SymbOut
	print   Q_Progr1		; Really update firmware?
m0044:	call	SymbIn
	or	%00100000
	cp	"y"
	jr	z,m0045
	cp	"n"
	jr	z,me004
	jr	m0044
m0045:
	call	SymbOut
	print	ONE_NL_S
	print	CheckCRC
        ld      a,(TPASLOT1)
        ld      h,#40			; Set 1 page DOS
        call    ENASLT

	ld	de,FCBC
	push	de
	pop	ix
	ld	c,_FOPEN
	call	DOS			; Open CRC file
	or	a
	jr	z,m0047
m00461:
	print   FlOpErr			; File open error
	call	ShowFname		; Print affected file name
	print	ONE_NL_S
	jp	MainM
m0047:
	xor	a
	ld	(GithubMess),a		; reset flag
	ld	de,(FCBC+16)		; crc file size
	ld	a,d
	or	a
	jr	nz,m00471
	ld	a,e
	cp	27
	jr	z,m0047a
	cp	30
	jr	z,m0047b
	print	CheckCRCF_NOK		; CRC file damaged
	ld	de,FCBC
	ld	c,_FCLOSE		; Close file
	call	DOS		
;	print	ONE_NL_S
	jp	MainM

m0047a:
	ld	a,1
	ld	(GithubMess),a		; file is messed up by Github
m0047b:
	ld	a,#78
	ld	(FWCRC),a
	ld	a,#56
	ld	(FWCRC+1),a
	ld	a,#34
	ld	(FWCRC+2),a
	ld	a,#12
	ld	(FWCRC+3),a		; original value with salt

	ld      hl,1
	ld      (FCBC+14),hl		; Record size = 1 byte
					; verify file
					; File size FCBN(+19..+16)
	ld	c,_SDMA			; Set DMA address
	ld	de,FBUFFC		; Space for file
	call	DOS	
	ld	hl,(FCBC+16)
	ld	c,_RBREAD		; read whole file
	ld	de,FCBC
	call	DOS
	or	a
	jr	z,m0048
m00471:
	print	FlRdErr			; File reading error
	ld	de,FCBC
	ld	c,_FCLOSE		; Close file
	call	DOS		
;	print	ONE_NL_S
	jp	MainM
m0048:
	ld	de,FCBC
	ld	c,_FCLOSE		; Close file
	call	DOS		

	ld	de,FCBN
	push	de
	pop	ix
	ld	c,_FOPEN
	call	DOS			; Open file
	or	a
	jp	nz,m00461

	ld      hl,1
	ld      (FCBN+14),hl		; Record size = 1 byte
					; verify file
					; File size FCBN(+19..+16)
	ld	de,(FCBN+16)
	ld	hl,(FsflSz0)
	xor	a			;
	sbc	hl,de			;
	jr	c,m00482		;
	ld	h,0			; Size EEPROM < File size (4byte) ?
	ld	a,(FsflSz+1)		;
	ld	l,a			;
	ld	de,(FCBN+18)
	sbc	hl,de			;
	jr	nc,m00483		;
m00482:				
	print	Fllarge			; The file size is not correct
	jp	m0068
m00483:					; 
	ld	c,_SDMA			; Set DMA address
	ld	de,FBUFF		; 2-page slot RAM
	call	DOS	
					; calc size block read
	ld	hl,(FCBN+18)
	ld	(savesz+2),hl
	ld	hl,(FCBN+16)		; Save left size
	ld	(savesz),hl
;	ld	e,l
;	ld	d,h
;	ld	bc,#1000		; portion size
;	xor	a
;	sbc	hl,bc
;	ld	(savesz),hl
;	ld	hl,(savesz+2)
;	ld	bc,0
;	sbc	hl,bc			; SaveLeft - #1000
;	ld	(savesz+2),hl
;	jr	c,m00484		;de - last bytes
	ld	de,#1000	
m00484:	ex	hl,de
;	ld	a,h
;	or	e
;	jr	nz,m00485
;	print	Flzero			; File zero size
;	print	ONE_NL_S
;	jp	m0068			; Close file and exit	
m00485:
	ld	c,_RBREAD		; load block #1000 bytes
	ld	de,FCBN
	call	DOS
	or	a
	jr	z,m00486
	ld	a,h
	or	l
	jr	z,m0049			; 0 bytes read?
	print	FlRdErr			; File reading error
	jp	m0068
m00486:
	ld	a,h
	or	l
	jr	z,m0049			; 0 bytes read?
	push	hl
	pop	bc
	call	Calc_CRC		; calculate CRC of the segment

	ld	e,"."			; print "."
	ld	c,_CONOUT
	call	DOS

	ld	hl,(savesz)
	ld	e,l
	ld	d,h
	ld	bc,#1000		; portion size
	sbc	hl,bc
	ld	(savesz),hl
	jr	nc,m00486a
	ld	hl,(savesz+2)
	ld	bc,0
	sbc	hl,bc			; SaveLeft - #1000
	ld	(savesz+2),hl
	jr	c,m00487		;de - last bytes
m00486a:
	ld	de,#1000	
m00487:	ex	hl,de
	ld	a,h
	or	e
	jr	nz,m00485

m0049:
	ld	de,FCBN
	ld	c,_FCLOSE		; Close file
	call	DOS		

	print	ONE_NL_S
	ld	de,FW_Mark
	ld	hl,FBUFFC
	ld	b,15
	ld	a,(GithubMess)		; file is messed up by Github?
	or	a
	jr	z,m00491
	ld	de,FW_MarkAlt
	ld	hl,FBUFFC
	ld	b,14
m00491:
	ld	a,(de)
	cp	(hl)			; match contents of CRC file before actual hash
	jp	nz,m00494
	inc	hl
	inc	de
	djnz	m00491
	push 	hl
	push	hl

	print	CurrentCRC
	ld	a,(FWCRC+3)
	call	HEXOUT
	ld	a,(FWCRC+2)
	call	HEXOUT
	ld	a,(FWCRC+1)
	call	HEXOUT
	ld	a,(FWCRC)
	call	HEXOUT			; output calculated CRC

	print	ONE_NL_S
	print	ExpectedCRC
	pop	hl
	ld	b,8
m00491a:
	ld	a,(hl)
	call	SymbOut			; print expected CRC
	inc	hl
	djnz	m00491a
	print	ONE_NL_S

	pop	hl
	ld	b,4
	ld	de,FWCRC+3		; actual CRC
m00492:
	push	bc
	ld	a,(hl)			; read symbol of expected crc
	ld	b,a
	inc	hl
	ld	a,(hl)
	ld	c,a
	ld	a,(de)
	push	hl
	push	bc
	call	HEX			; ab-representation of hex digit
	ld	h,a
	ld	l,b
	pop	bc
	ld	a,h
	cp	b
	jr	nz,m00493
	ld	a,l
	cp	c
	jr	nz,m00493
	pop	hl
	inc	hl
	dec	de
	pop	bc
	djnz	m00492
	print	CheckCRC_OK
	jr	m00500
m00493:
	print	CheckCRC_NOK		; print "crc match failed"
	jp	MainM
m00494:
	print	CheckCRCFileFail	; print "bad crc file contents"
	jp	MainM

m00500:
	ld	hl,FCBN+1+8+3		; Clear FCB
	ld	b,28
	xor	a
m0050:	ld	(hl),a
	inc	hl
	djnz	m0050

;        ld      bc,24			; Prepare the FCB
;        ld      de,FCB+13
;        ld      hl,FCB+12
;        ld      (hl),b
;        ldir 

        ld      a,(TPASLOT1)
        ld      h,#40			; Set 1 page DOS
        call    ENASLT

	ld	de,FCBN
	push	de
	pop	ix
	ld	c,_FOPEN
	call	DOS			; Open file
	or	a
	jr	z,m0051
	print   FlOpErr			; File open error
	call	ShowFname		; Print affected file name
	print	ONE_NL_S
	jp	MainM
m0051:
	ld      hl,1
	ld      (FCBN+14),hl		; Record size = 1 byte
					; verify file
					; File size FCBN(+19..+16)
	ld	de,(FCBN+16)
	ld	hl,(FsflSz0)
	xor	a			;
	sbc	hl,de			;
	jr	c,m0052			;
	ld	h,0			; Size EEPROM < File size (4byte) ?
	ld	a,(FsflSz+1)		;
	ld	l,a			;
	ld	de,(FCBN+18)
	sbc	hl,de			;
	jr	nc,m0053		;
m0052:				
	print	Fllarge			; The file size is too large
m0068:	ld	de,FCBN
	ld	c,_FCLOSE		; Close file
	call	DOS		
;	print	ONE_NL_S
	jp	MainM

m0053:					; 
	ld	c,_SDMA			; Set DMA address
	ld	de,FBUFF		; 2-page slot RAM
	call	DOS	
					; calc size block read
	ld	hl,(FCBN+18)
	ld	(savesz+2),hl
	ld	hl,(FCBN+16)		; Save left size
	ld	(savesz),hl
	ld	e,l
	ld	d,h
	ld	bc,#1000		; portion size
	xor	a
	sbc	hl,bc
	ld	(savesz),hl
	ld	hl,(savesz+2)
	ld	bc,0
	sbc	hl,bc			; SaveLeft - #1000
	ld	(savesz+2),hl
	jr	c,m0055			;de - last bytes
	ld	de,#1000	
m0055:	ex	hl,de
	ld	a,h
	or	e
	jr	nz,m0066
	print	Flzero			; File zero size
;	print	ONE_NL_S
	jp	m0068			; Close file and exit	

m0066:	ld	c,_RBREAD		; load block #1000 bytes
	ld	de,FCBN
	call	DOS
	or	a
	jr	z,m0067
	print	FlRdErr			; File reading error
	jp	m0068			; Close file and exit	

;=============================================================
; This is the point of no-return :)
;=============================================================
m0067:	
; Erase
        ld      a,(ERMSlt)
        ld      h,#40			; Set 1 page ERM
        call    ENASLT

	xor	a
	ld	(Fsadp),a
	ld	(Fsadp+1),a
	ld	(Fsadp+2),a
	ld	c,#00			; disable Block Protection
	call	SFL_WRStat
m006:	call	SFL_RDStat		; Get read satus
	and	#01			; 1-bit Write in progress
	jr	nz,m006
	print	FlErase			; Print erasing EEPROM
	call	SFL_Erase
m007:	call	SFL_RDStat		; Get read satus
	and	#01			; 1-bit Write in progress
	jr	nz,m007
	print	FlCompl			; Erasing complete

	print	FlErasev		; Blank checking
m0073:	ld	hl,(Fsadp+1)
	ld	bc,#1000
	ld	a,(Fsadp)
	call	SFL_clv	
	jr	z,m0071
	print	p_ERSEr			; Erasing error! (a/r/i)
m0072:	call	SymbIn
	or	%00100000
	cp	"a"
	jr	z,m007e
	cp	"i"
	jr	z,m0071
	cp	"r"
	jr	nz,m0072
	call	SFL_init		; Retry EEPROM Wake up and retry erasing
	jr	m0067
m007e:
	print   pNS			; Firmware update failed
	jp	m0068			; Close file and exit

m0071:					; next block clear verify	
	ld	hl,(FsflSz)		; #02 #08 #20 #80
	ex	hl,de
	ld	hl,(Fsadp+1)
	xor	a
	ld	bc,#10			;
	adc	hl,bc			; size + #1000
	ld	(Fsadp+1),hl	
	sbc	hl,de			;
	jr	c,m0073			; next block ?
	print	FlCompl			; Blank checking complete


; Program EPROM
; Buffer load FBUFF - FBUFF + #FFF
; 256b X 16
m008:
	call	SFL_RDStat		; checking the completion of the previous programming cycle
	and	#01
	jr	nz,m008

	print	FlProgs			; Uploading firmware

	xor	a
	ld	(Fsadp),a		; set pointer to start address
	ld	(Fsadp+1),a
	ld	(Fsadp+2),a
	ld	de,FBUFF

; segment write
m009:
; #DEBUG
;	push	de
;	ld	a,(Fsadp+2)
;	call	HEXOUT
;	ld	a,(Fsadp+1)
;	call	HEXOUT
;	pop	de
; #DEBUG

	ld	hl,(Fsadp+1)
	ld	bc,#100			; programm block size - 256 byte only
	ld	a,(Fsadp)

;	push	hl
;	push	af

	call	SFL_write		; write procedure
m0093:	call	SFL_RDStat		; read satus
	and	#01			; 1-bit Write in progress
	jr	nz,m0093

	ld	hl,(Fsadp+1)
	inc	hl
	ld	(Fsadp+1),hl
	ld	a,l
	and	#0F			; #xxxxx000 - need loading new block #1000 bytes 
	jr	nz,m009

	ld      a,(TPASLOT1)
        ld      h,#40			; Set 1 page to DOS
        call    ENASLT

	ld	e,"W"			; print "W"
	ld	c,_CONOUT
	call	DOS

        ld      a,(ERMSlt)
        ld      h,#40			; Set 1 page ERM (CV2p)
        call    ENASLT	

;	pop	af			; reset block address
;	pop	hl			; 

; segment verify
	ld	hl,(Fsadp+1)
	ld	bc,#10
	xor	a
	sbc	hl,bc
	ld	bc,#100			; programm block size - 256 byte only
	ld	a,(Fsadp)
	ld	bc,#1000		; #1000 bytes 
	ld	de,FBUFF
	call	SFL_vrf
	jp	nz,m009e		; error!

	ld      a,(TPASLOT1)
        ld      h,#40			; Set 1 page to DOS
        call    ENASLT

	ld	e,"V"			; print "V"
	ld	c,_CONOUT
	call	DOS
					; loading next #1000 bytes from file ?	

	ld	c,_SDMA			; Set DMA address
	ld	de,FBUFF		; 2-page slot RAM
	call	DOS
					; calc remains, new Fsadp >= Filesize ?
	ld	a,(FCBN+16)
	ld	b,a
	ld	a,(Fsadp)
	sub	b
	ld	hl,(FCBN+17)
	ex	hl,de
	ld	hl,(Fsadp+1)
	sbc	hl,de			;f C - norm, nc- oversize
	jr	nc,BIOSupd		; go BIOS update
					; next #1000
	ld	hl,#1000
	ld	c,_RBREAD
	ld	de,FCBN
	call	DOS			; read next part
	or	a
	jr	z,m0092
	print	FlRdErr			; File reading error
	print   pNS			; Firmware update failed
	jp	m0068
m0092:		
        ld      a,(ERMSlt)
        ld      h,#40			; Set 1 page ERM (CV2p)
        call    ENASLT	
	ld	de,FBUFF	
	jp	m009			; next programm block

m009e:					; Write EEPROM (verify) Error
	print	p_ErWr			; retry/abort ?
m009e1:	call	SymbIn
	or	%00100000
	cp	"a"
	jp	z,m007e			; print "Sorry.." and exit
	cp	"r"
	jr	nz,m009e1
					; retry programm cycle
	ld	de,FCBN
	ld	c,_FCLOSE		; Close file
	call	DOS

	call	SFL_init		; Retry EEPROM Wake up
	jp	m0045			; Do it again!
 	
BIOSupd:
	ld	de,FCBN
	ld	c,_FCLOSE		; Close file
	call	DOS		

	print	ROProgs			; Print "Updating BIOS"

	ld	de,FCBR
	push	de
	pop	ix
	ld	c,_FOPEN
	call	DOS			; Open file
	ld      hl,#2000
	ld      (FCBR+14),hl		; Record size = #2000 bytes
	or	a
	jr	z,Fpo
	print   FlOpErr			; File open error
	call	ShowFname		; Print affected file name
	print	ONE_NL_S
	jp	MainM
Fpo:
; get file size
	ld	hl,FCBR+#10
	ld	bc,4
	ld	de,Size
	ldir
	ld	hl,(Size)		; we need #10000 = 65536 bytes
	ld	a,l
	or	h
	jr	nz,Fpo1
	ld	hl,(Size+2)		; we need #10000 = 65536 bytes
	ld	a,l
	or	h
	cp	1
	jr	z,DEF9
Fpo1:
	print	ROMlarge		; The file size is too large
	ld	de,FCBR
	ld	c,_FCLOSE		; Close file
	call	DOS		
;	print	ONE_NL_S
	jp	MainM

DEF9:
; !!!! file attribute fix by Alexey !!!!
	ld	a,(FCBR+#11)
	cp	#20
	jr	nz,DEF10
	ld	a,(FCBR+#0D)
	cp	#21
	jr	nz,DEF10
	dec	a
	ld	(FCBR+#0D),a
; !!!! file attribute fix by Alexey !!!!

DEF10:
        ld      a,(ERMSlt)
        ld      h,#40
        call    ENASLT
	ld	a,#95			; ROM writing on, bank enabled
	ld	(R1Mult),a

	ld	hl,B2ON1
	ld	de,CardMDR+#0C		; set Bank2
	ld	bc,6
	ldir
	ld	a,(ERMSlt)		; set 2 page
	ld	h,#80
	call	ENASLT
	ld      c,_SDMA
	ld      de,FBUFF
	call    DOS			; set DMA

	xor	a
	ld	(AddrFR),a
	ld	(PreBnk),a
	ld	(EBlock0),a
	ld	a,3
	ld	(EBlock),a		; 3rd block
	call	FBerase			; erase block
	jr	c,Fpr03b
Fpr02a:
	ld	c,_RBREAD
	ld	de,FCBR
	ld	hl,1
	call	DOS			; read #2000 bytes
	ld	a,h
	or	l
	jr	nz,Fpr03
Fpr02b:
	print	FlRdErr			; File reading error
	ld	de,FCBR
	ld	c,_FCLOSE		; Close file
	call	DOS		
	jp	MainM
Fpr03:
	ld	hl,FBUFF		; source
	ld	de,#8000		; destination
	ld	bc,#2000		; size
	call	FBProg2			; save loaded data into FlashROM
	jr	nc,Fpr04
Fpr03b:
	ld	de,FCBR
	ld	c,_FCLOSE
	call	DOS
	print	FailNote		; print failnote
	jp	MainM
Fpr04:
	ld	a,(PreBnk)
	inc	a
	cp	8			; all 8kb pages written?
	jr	z,Fpr05
	ld	(PreBnk),a
;	ld	a,(EBlock0)
;	add	#20
;	ld	(EBlock0),a		; increment block for erasing
	jp	Fpr02a
Fpr05:
	ld	de,FCBR
	ld	c,_FCLOSE
	call	DOS

; Restore slot configuration!
        ld      a,(ERMSlt)
        ld      h,#40
        call    ENASLT
;	ld	hl,B1ON
;	ld	de,CardMDR+#06		; set Bank1
;	ld	bc,6
;	ldir
	xor	a
	ld	(AddrFR),a
	ld	(CardMDR+#0E),a
	ld	(EBlock),a
	ld	(PreBnk),a
	ld	a,#24      		; Disable SFL port
	ld	(sfl_CFG),a
	ld	a,#85			; ROM enabled
	ld	(R1Mult),a

        ld      a,(TPASLOT1)
        ld      h,#40
        call    ENASLT
        ld      a,(TPASLOT2)
        ld      h,#80
        call    ENASLT         		; Select Main-RAM at bank 8000h~BFFFh

	print   pEndS			; Successful upload!
;	print	ONE_NL_S
	jp	MainM



;============================================================================
; Subroutines
;============================================================================

;-----------------------------------------------------------------------------
; Move BIOS (CF card IDE and FMPAC) to shadow RAM
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
	ld	(ShadowMDR),a
	push	af

Sha02:  pop	af
	xor	a
	ld	(AddrFR),a	
	ld	a,#08
	ld	(CardMDR+#15),a		; off Bank3 R3Mult
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
        call    ENASLT			; Select Main-RAM at bank 8000h~BFFFh
	pop	af
	exx
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
        call    ENASLT			; Select Main-RAM at bank 4000h~7FFFh
	pop	af
	ret

;**********************
CHECK:
    	push	bc
    	ld	c,a
CHK_L1: ld	a,(de)
    	xor	c
    	jp	p,CHK_R1		; Jump if read bit 7 = written bit 7
    	xor	c
    	and	#20
    	jr	z,CHK_L1		; Jump if read bit 5 = 1
    	ld	a,(de)
    	xor	c
    	jp	p,CHK_R1		; Jump if read bit 7 = written bit 7
    	scf
	ld	a,#F0
	ld	(de),a			; Return FlashROM to command mode
CHK_R1:	pop	bc
	ret	


Calc_CRC:
	di
	push	ix
	ld	de,(FWCRC)
	ld	hl,(FWCRC+2)
	ld	ix,FBUFF
C_CRC1:
	ld	a,(ix+00)

	add	a,e			; code by Delhin_Soft
	ld	e,a
	ld	a,0
	adc	a,d
	ld	d,a
	ld	a,0
	adc	a,l
	ld	l,a
	ld	a,0
	adc	a,h
	ld	h,a			; code by Delhin_Soft

;	add	a,l
;	jr	nc,C_CRC2
;	inc	h
;	ld	a,h
;	or	a
;	jr	nz,C_CRC2
;	inc	e
;	ld	a,e
;	or	a
;	jr	nz,C_CRC2
;	inc	d
C_CRC2:
	inc	ix
	ld	(FWCRC),de
	ld	(FWCRC+2),hl
	dec	bc
	ld	a,b
	or	c
	jr	nz,C_CRC1
	pop	ix
	ei
	ret	

;
; Test dedicated RAM area
;
TestRAM:
	ld	hl,FBUFF
	ld	bc,#2002
TRLoop:
	ld	a,d
	ld	(hl),a
	nop
	nop
	nop
	ld	a,(hl)
	cp	d
	jr	nz,TestRB
	dec	bc
	inc	hl
	xor	a
	or	b
	jr	nz,TRLoop
	or	c
	jr	nz,TRLoop	
	xor	a			; good RAM!
	ret
TestRB:
	ld	a,1			; bad RAM!
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


; Test if the VDP is a TMS9918A
; Out A: 0=9918, 1=9938, 2=9958
;
DetVDP:
	in	a,(#99)			; read s#0, make sure interrupt flag is reset
	di
DetVDPW:
	in	a,(#99)			; read s#0
	and	a			; wait until interrupt flag is set
	jp	p,DetVDPW
	ld	a,2			; select s#2 on V9938
	out	(#99),a
	ld	a,15+128
	out	(#99),a
	nop
	nop
	in	a,(#99)			; read s#2 / s#0
	ex	af,af'
	xor	a			; select s#0 as required by BIOS
	out	(#99),a
	ld	a,15+128
	ei
	out	(#99),a
	ex	af,af'
	and	%01000000		; check if bit 6 was 0 (s#0 5S) or 1 (s#2 VR)
	or	a
	ret	z

	ld	a,1			; select s#1
	di
	out	(#99),a
	ld	a,15+128
	out	(#99),a
	nop
	nop
	in	a,(#99)			; read s#1
	and	%00111110		; get VDP ID
	rrca
	ex	af,af'
	xor	a			; select s#0 as required by BIOS
	out	(#99),a
	ld	a,15+128
	ei
	out	(#99),a
	ex	af,af'
	jr	z,DetVDPE		; VDP = 9938?
	inc	a
DetVDPE:
	inc	a
	ld	(VDPVER),a
	ret


;============================================================================
;
; Wake up  Altera confiruration flash
; and read Read silicon ID
; input: none
; output: A - ID code 
; use: HL,b
;
SFL_init:
	di
	ld	a,#80			; 7b=1 SFL port activations
					; 5b=0 JTAG disable
					; 2b=0 Enable signal eeprom control
					; 3b=0 nCSo avtive
	ld	(sfl_CFG),a		; 4F80h+37h=4FB7 SFL config port
	ld	a,#AB			; WakeUP+readID code
	ld	hl,#7000		; direct data flash area
	ld	(hl),a			; command #AB
	nop
 	ld	a,(hl)			; start read 8bit from flash
	nop
	ld	a,(hl)			; read dummy byte
	nop
	ld	a,(hl)			; read dummy byte
	nop
	ld	a,(hl)			; read dummy byte
	nop
	ld	b,(hl)			; read ID byte
	ld	a,#08			; nCSo <= 1
	ld	(sfl_CFG),a  		;
	ld	a,b
	ei
	ret


;
; Read Altera flash EEPROM
; input:  DE    - destination buffer
;         HL, A - start address in flash EEPROM
;	  BC    - length (1 - #1000) windows size
; output: none
;
SFL_read:
	push	de
	push	af
	ex	hl,de
	ld	hl,#7000		; direct(MSB 1st) byte i/o eeprom port
	di
	ld	a,#80			; nCSo activate
	ld	(sfl_CFG),a
	ld	a,#03			; command #03 Read
	ld	(hl),a
	nop
	ld	(hl),d			; high address
	nop
	ld	(hl),e			; midle	address
	pop	af
	ld	(hl),a			; low addres
	nop
	ld	a,(hl)			; start read 
	pop	de
	ld	hl,#6000   		; reverse(LSB 1st) byte i/o eeprom port
	ldir
	ld 	a,#08			; nCSo <= 1  deacivate
	ld	(sfl_CFG),a
	ei
	ret


;
; Verify Altera flash EEPROM
; input:  DE    - destination buffer
;         HL, A - start address in flash EEPROM
;	  BC    - length (1 - #1000) windows size
; output: fnZ   - error 
;
SFL_vrf:
	push	de
	push	af
	ex	hl,de
	ld	hl,#7000		; direct(MSB 1st) byte i/o eeprom port
	di
	ld	a,#80			; nCSo activate
	ld	(sfl_CFG),a
	ld	a,#03			; command #03 Read
	ld	(hl),a
	nop
	ld	(hl),d			; high address
	nop
	ld	(hl),e			; midle	address
	pop	af
	ld	(hl),a			; low addres
	nop
	ld	a,(hl)			; start read 
	pop	de
	ld	hl,#6000		; reverse(LSB 1st) byte i/o eeprom port
SFL_vrf_1:
	ld	a,(de)
	cp	(hl)
	jr	nz,SFL_vrf_e
;	inc	hl
	inc	de
	dec	bc
	ld	a,b
	or	c
	jr	nz,SFL_vrf_1
SFL_vrf_e:	
	ld 	a,#08			; nCSo <= 1  deacivate
	ld	(sfl_CFG),a
	ei
	ret


;
; Clear Verify Altera flash EEPROM
; input:  HL, A - start address in flash EEPROM
;	  BC    - length (1 - #1000) windows size
; output: fnZ   - error 
;
SFL_clv:
	push	af
	ex	hl,de
	ld	hl,#7000		; direct(MSB 1st) byte i/o eeprom port
	di
	ld	a,#80			; nCSo activate
	ld	(sfl_CFG),a
	ld	a,#03			; command #03 Read
	ld	(hl),a
	nop
	ld	(hl),d			; high address
	nop
	ld	(hl),e			; midle	address
	pop	af
	ld	(hl),a			; low addres
	nop
	ld	a,(hl)			; start rd	
	ld	hl,#6000		; reverse(LSB 1st) byte i/o eeprom port
SFL_clv_1:
	ld	a,(hl)
	inc	a
	jr	nz,SFL_clv_e
	dec	bc
	ld	a,b
	or	c
	jr	nz,SFL_clv_1
SFL_clv_e:	
	ld 	a,#08			; nCSo <= 1  deacivate
	ld	(sfl_CFG),a
	ei
	ret


;
; Read Status Flash EEPROM
; input:  none
; output: A
;
SFL_RDStat:
	di
	ld	a,#80			; nCSo activate
	ld	(sfl_CFG),a
	ld	a,#05			; Read status command
	ld	(#7000),a
	ld	a,(#7000)		; start read
	ld	a,(#7000)		; read data (status)
	ld	c,a
	ld	a,#08			; nCSo deactivate
	ld	(sfl_CFG),a
	ld	a,c
	ei
	ret


; 
; Write Status Flash EEPROM
; input:  C - new status
; output: none
;
SFL_WRStat:
	di
	ld	a,#80			; nCSo activate
	ld	(sfl_CFG),a
	ld	a,#06			; Write enable command
	ld	(#7000),a		; 
	ld	a,#8c			; nCSo deactivate
	ld	(sfl_CFG),a
	ld	a,#84			; nCSo activate
	ld	(sfl_CFG),a
	ld	a,#01			; Write status command
	ld	(#7000),a		; 
	ld	a,c
	ld	(#7000),a		; Write data (status)
	ld	a,#08			; nCSo deactivate
	ld	(sfl_CFG),a
	ei
	ret


; 
; Write Enable Flash EEPROM
; input:  none
; output: none
;
SFL_WREna:
	di
	ld	a,#80			; nCSo activate
	ld	(sfl_CFG),a
	ld	a,#06			; Write enable command
	ld	(#7000),a		; 
	ld	a,#08			; nCSo deactivate
	ld	(sfl_CFG),a
	ei
	ret


;
; 
; Write Disable Flash EEPROM
; input:  none
; output: none
;
;
SFL_WRDis:
	di
	ld	a,#80			; nCSo activate
	ld	(sfl_CFG),a
	ld	a,#04			; Write enable command
	ld	(#7000),a		; 
	ld	a,#08			; nCSo deactivate
	ld	(sfl_CFG),a
	ei
	ret


; 
; Write Data Flash EEPROM
; input:  DE    - source buffer
;         HL, A - start address in flash EEPROM
;	  BC    - length (1 - #100) windows size write
; output: none
;
SFL_write:
	di
	push	af
	ld	a,#80			; nCSo activate
	ld	(sfl_CFG),a
	ld	a,#06			; Write enable command
	ld	(#7000),a		; 
	ld	a,#88			; nCSo deactivate
	ld	(sfl_CFG),a
	ld	a,#80			; nCSo activate
	ld	(sfl_CFG),a
	ld	a,#02			; start write data command
	ld	(#7000),a		; 
	ld	a,h
	ld	(#7000),a		; high address 
	ld	a,l
	ld	(#7000),a		; medium address
	pop	af
	ld	(#7000),a		; low address
	ex	hl,de
	ld	de,#6000		; reverse data port windows
	ldir
	ld	a,#08			; nCSo deactivate
	ld	(sfl_CFG),a
	ei
	ex	hl,de
 	ret



; 
; Erase EEPROM! This can not be undone!
; input:  none
; output: none
;
SFL_Erase:
	di
	ld	a,#80			; nCSo activate
	ld	(sfl_CFG),a
	ld	a,#06			; Write enable command
	ld	(#7000),a		; 
	ld	a,#88			; nCSo deactivate
	ld	(sfl_CFG),a
	ld	a,#80			; nCSo activate
	ld	(sfl_CFG),a
	ld	a,#C7			; erase bulk command
	ld	(#7000),a		; 
	ld	a,#08			; nCSo deactivate
	ld	(sfl_CFG),a
	ei
 	ret


;
; Find Carnivore2+
;
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
	ld	c,_CONOUT
	ld	e,a
	call	DOS			; print primary slot number
	ld	a,(ix)
	bit	7,a
	jr	z,BCLT2			; not extended
	rrc	a
	rrc	a
	and	3
	add	a,"0"
	ld	e,a
	ld	c,_CONOUT
	call	DOS			; print extended slot number
BCLT2:	ld	e," "
	ld	c,_CONOUT
	call	DOS	
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
	ld	c,_BUFIN
	call	DOS
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
	jr	z,Trp02a

	print	MfC_S
	ld	a,(Det00)
	call	HEXOUT
	print	ONE_NL_S

	print	DVC_S
	ld	a,(Det02)
	call	HEXOUT
	ld	e," "
	ld	c,_CONOUT
	call	DOS	
	ld	a,(Det1C)
	call	HEXOUT
	ld	e," "
	ld	c,_CONOUT
	call	DOS
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
	print	M29W640
	ld	e,"x"
	ld	a,(Det1C)
	cp	#0C
	jr	z,Trp05
	cp	#10
	jr	z,Trp08
	jr	Trp04
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
Trp06:	ld	e,"H"
	jr	Trp04
Trp07:	ld	e,"L"
	jr	Trp04
Trp09:	ld	e,"T"
	jr	Trp04
Trp10:	ld	e,"B"
Trp04:	ld	c,_CONOUT
	call	DOS
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


;---- Out to conlose HEX byte
; A - byte
HEXOUT:
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
	ret


HEXOUTI:
;--- HEX
; input  a - Byte
; output d - H hex symbol
;        e - L hex symbol
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
	ld	d,(hl)
	pop	af
	and	#0F
	ld	b,0
	ld	c,a
	ld	hl,ABCD
	add	hl,bc
	ld	e,(hl)
	ret

HEX:
;--- HEX
; input  a - Byte
; output b - H hex symbol
;        c - L hex symbol
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


; Clear screen and set mode 40/80 depending on VDP version
CLRSCR:
	ld	a,(VDPVER)
	or	a			; v991x?
	jr	z,Set40
	cp	2			; v995x?
	jr	nc,Set80
	ld	a,(SCR0WID)
	cp	41
	jr	nc,Set80

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


; Show file name after an error
ShowFname:
	print	FlErrName
	ld	b,8
	push	ix
	pop	hl
	inc	hl
SFNloop1:
	ld	a,(hl)
	or	a
	jr	z,SFNend
	push	bc
	call	SymbOut			; Print name
	pop	bc
	inc	hl
	djnz	SFNloop1
	ld	a,'.'
	call	SymbOut			; Print dot
	ld	b,3
SFNloop2:
	ld	a,(hl)
	or	a
	jr	z,SFNend
	push	bc
	call	SymbOut			; Print extension
	pop	bc
	inc	hl
	djnz	SFNloop2
SFNend:
	print	CRLF_S
	ret


;
; Exit to DOS
;
Exit:
        ld      a,(ERMSlt)
        ld      h,#40
        call    ENASLT
	ld	a,#24			; Disable SFL port
	ld	(sfl_CFG),a
	ld	a,#85			; ROM enabled
	ld	(R1Mult),a

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


termdos:
	call	PrintMsg
	ld	c,_TERM0
	jp	DOS

;------------------------------------------------------------------------------

;
; Strings
;

TWO_NL_S:
	db	13,10
ONE_NL_S:
	db	13,10,"$"

CLS_S:	db	27,"E$"

CLStr_S:
	db	27,"K$"

MAIN_S:	db	13,10
	db	"Main Menu",13,10
	db	"---------",13,10
	db	" 1 - Backup firmware and music BIOS to disk",13,10
	db	" 2 - Update firmware and music BIOS from disk",13,10
	db	" 0 - Exit to MSX-DOS [ESC]",13,10,"$"

MAIN_U:	db	13,10
	db	"Updating Menu",13,10
	db	"-------------",13,10
	db	" 1 - Previously backed up firmware and music BIOS",13,10
	db	" 2 - MSX Music (FMPAC) firmware and music BIOS",13,10
	db	" 3 - SFG-05 FM firmware and music BIOS",13,10
	db	" 4 - MSX Audio firmware and music BIOS",13,10
	db	" 0 - Exit to Main Menu [ESC]",13,10,"$"

DESCR:	db	"CMFCSDCF"		; "CMFCCFRC"

PRESENT_S:
	db	3
	db	"Carnivore2+ Firmware Updater v3.01",13,10
	db	"(C) 2025 RBSC. All rights reserved",13,10,13,10,"$"
NSFin_S:
	db	"Carnivore2+ cartridge was not found. Please specify its slot number - $"
Findcrt_S:
	db	"Found Carnivore2+ cartridge in slot(s): $"
FindcrI_S:
	db	13,10,"Press ENTER for the found slot or input new slot number - $"
;USEDOS2_S:
;	db	"*** DOS2 has been detected ***",13,10
CRLF_S:	db	13,10,"$"
SltN_S:	db	13,10,"Using slot - $"
M_Shad:	db	"Copying ROM BIOSes to RAM (shadow copy): $"
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

ABCD:	db	"0123456789ABCDEF"

EXIT_S:	db	13,10,"Thanks for using the RBSC's products!",13,10,"$"

EPCS_ID:	db	"EPCS chip ID: #$"
T_EEPROM:	db	"EEPROM chip detected: $"
T_EPCS1: 	db	#00,#02,"EPCS1 (128Kb)",13,10,"$"
T_EPCS4:	db	#00,#08,"EPCS4 (512Kb)",13,10,"$"
T_EPCS16:       db	#00,#20,"EPCS16 (2Mb)",13,10,"$"
T_EPCS64:       db	#00,#80,"EPCS64 (16Mb)",13,10,"$"
UNK_EPCS:	db	#00,#08,"Unknown! Assuming EPCS4 (512Kb)",13,10,"$"

SelFW:		db	10,13,"Previously backed up firmware selected.",10,13,"$"
SelFMPAC:	db	10,13,"MSX Music firmware selected.",10,13,"$"
SelSFG:		db	10,13,"SFG-05 FM firmware selected.",10,13,"$"
SelMSXA:	db	10,13,"MSX Audio firmware selected.",10,13,"$"

FlCrErr:        db	13,10,"Failed to create file!",13,10,"$"
FlOpErr:	db	13,10,"Failed to open file!",13,10,"$"
FlWrErr:        db	13,10,"Failed to write file!",13,10,"$"
FlClErr:        db	13,10,"Failed to close file!",13,10,"$"
FlRdErr:        db	13,10,"Failed to read file!",13,10,"$"
FlErrName:	db	"Not found: $"
ROMlarge:	db	13,10,"The ROM file is damaged or incorrect!",13,10,"$"
Fllarge:	db	13,10,"Firmware's file is damaged or incorrect!",13,10,"$"
Flzero:		db	13,10,"Firmware's file is empty!",13,10,"$"
Q_Prog:		db	13,10
Q_Prog1:	db	13,10,"WARNING! The firmware and music module's BIOS will be updated!",13,10
		db	"This is a risky operation that can potentially brick your cartridge.",13,10
		db	"If updating fails, you can try again or update from another disk device.",13,10
		db	"If nothing else works, the firmware can be uploaded with USB Blaster.",13,10
		db	"You are updating the firmware and BIOS on your own risk!",13,10,13,10
Q_Progr:	db	"Proceed with updating the firmware and BIOS or Exit? (p/e) $"
Q_Progr1:	db	13,10,"Are you still sure you want to update the firmware and BIOS? (y/n) $"
Q_BackFW:	db	13,10,"Did you already backup the existing firmware and BIOS? (y/n) $"
M_BackFW:	db	13,10,"Please backup the existing firmware and BIOS from the main menu!",13,10,"$"
FlExists:	db	13,10,"Previous backup files exist. Overwrite? (y/n) $"
pNS:		db	13,10, "ERROR: Firmware update failed!",13,10
		db	"The firmware in your cartridge may be damaged/incomplete.",13,10,"$"
		db	"This means that your cartridge may no longer work.",13,10,"$"
		db	"Do not power off yet! Try uploading the firmware again.",13,10,"$"
		db	"If uploading of the firmware still fails, do not panic!",13,10,"$"
		db	"You can always restore the firmware with USB Blaster...",13,10,13,10,"$"
FlStSs:		db	13,10,"Saving cartridge's firmware to disk...",13,10,"$"
CreateCRC:	db	13,10,"Creating CRC file for the saved firmware...",13,10,"$"
CreateROM:	db	"Saving ROM file matching the firmware...",13,10,"$"
FlWrSs:		db	13,10,"Backup completed successfully!",13,10,"$"
FlErase:	db	"Erasing EEPROM chip...$"
FlErasev:	db	"Blank checking EEPROM...$"
TstRam:		db	"Testing dedicated RAM area...$"
FlCompl:	db	" OK",13,10,"$"
ROProgs:	db	13,10,13,10,"Uploading music module's BIOS to the cartridge...",13,10,"$"
FlProgs:	db	13,10,"Uploading firmware to the cartridge..."
		db	13,10,"DO NOT RESET OR POWER OFF YOUR COMPUTER!",13,10,"$"
CheckCRC:	db	13,10,"Verifying CRC of the firmware file, please wait...",13,10,"$"
CheckCRC_OK:	db	"CRC matches. Proceeding with firmware update...",13,10,13,10,"$"
CheckCRC_NOK:	db	13,10,"ERROR matching CRC! Firmware will not be updated...",13,10,"$"
CheckCRCFileFail:
		db	13,10,"ERROR verifying CRC file's headers! CRC file is damaged...",13,10,"$"
CheckCRCF_NOK:	db	13,10,"ERROR reading CRC file! CRC file is damaged...",13,10,"$"
FWCRC:		dd	0x12345678
FW_Mark:	db	"FirmwareCRC",13,10,"0x",0
FW_MarkAlt:	db	"FirmwareCRC",10,"0x",0
CurrentCRC:	db	"Actual CRC of firmware:   0x$"
ExpectedCRC:	db	"Expected CRC of firmware: 0x$"

unc_EPCS:	db	13,10,"ERROR: Unknown or too small EEPROM chip!",13,10
		db	"The utility requires EPCS4 or larger EEPROM chip to proceed...",13,10,"$"
TestRamE:	db	13,10,"ERROR: Dedicated RAM test failed!",13,10
		db	"It is unsafe to use bad RAM for firmware upgrading.",13,10,"$"
p_ERSEr:	db	13,10,"ERROR: Failed to erase EEPROM!",13,10
		db	"The existing firmware may be still intact, but it's not guaranteed.",13,10
		db	"Aborting the operation at this point may be a good idea.",13,10
		db	"Retrying may still be an option. Ignoring is not recommended.",13,10
		db	"Do you want to Abort, Retry or Ignore? (a/r/i) $"
p_ErWr:		db	13,10,"ERROR: Data verification error! Retry or Abort? (r/a) $"
pEndS:		db	13,10
		db	"The firmware and music module's BIOS have been successfully updated.",13,10
		db	"Please POWER OFF your computer now to start using Carnivore2+ with updated",13,10
		db	"firmware and music module's BIOS.",13,10,"$"
FailNote:	db	13,10
		db	"IMPORTANT!",13,10
		db	"It appears that the music module's BIOS was not successfully updated...",13,10
		db	"Each music module requires its own BIOS, so you need to upload the correct",13,10
		db	"BIOS into the cartridge with C2MAN utility now. With SFG-05 firmware you must",13,10
		db	"use the SFG BIOS, with MSX Music firmware - MSX Music BIOS. Please refer to",13,10
		db	"the cartridge's documentation on how to upload the music module's BIOS.",13,10,"$"
FsflSz0:	db	0
FsflSz:		dw	0
Fsadp:		db	0,0,0
savesz:		dw	0,0	

FW_FMPAC:
	db	"FW_FMPAC"
FW_SFG05:
	db	"FW_SFG05"
FW_MSXAU:
	db	"FW_MSXAU"
FW_BACK:
	db	"FIRMWARE"


;--- File Control Block for Backup BIN
FCB:	db	0
	db	"FIRMWAREBIN"
	ds	28
;--- File Control Block for Backup CRC
FCB1:	db	0
	db	"FIRMWARECRC"
	ds	28
;--- File Control Block for Backup ROM
FCB2:	db	0
	db	"FIRMWAREROM"
	ds	28

;--- File Control Block for Firmware
FCBN:	db	0
	db	"FW_XXXXXBIN"
	ds	28
;--- File Control Block for CRC
FCBC:	db	0
	db	"FW_XXXXXCRC"
	ds	28
;--- File Control Block for BIOS
FCBR:	db	0
	db	"FW_XXXXXROM"
	ds	28
VTEMP:	dw	0

CRCTEMPL:
	db	"FirmwareCRC",13,10
	db	"0x"
CRCPL:	db	"00000000",13,10
	db	"EOF",13,10
CRCTEMPLE:
	dw	0

;------------------------------------------------------------------------------

;
; Variables
;
RSTCFG:
	db	#F8,#50,#00,#85,#03,#40
	db	0,0,0,0,0,0
	db	0,0,0,0,0,0
	db	0,0,0,0,0,0
	db	#FF,#30

B1ON:	db	#F8,#50,#00,#85,#03,#40
B2ON:	db	#F0,#70,#01,#15,#7F,#80
B2ON1:	db	#F0,#70,#00,#14,#7F,#80
B23ON:	db	#F0,#80,#00,#04,#7F,#80	; for shadow source bank
	db	#F0,#A0,#00,#34,#7F,#A0	; for shadow destination bank

F_V	db	0
F_A	db	0

ShadowMDR:
	db	#21
Size:	db	0,0,0,0
protect:
	db	1
DOS2:	db	0
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
StartBL:	ds	2
C8k:	dw	0
PreBnk:	db	0
EBlock0:
	db	0
EBlock:	db	0
strp:	db	0
strI:	dw	#8000
GithubMess:
	db	0

;------------------------------------------------------------------------------

; Footer

	db	0
	db	"RBSC:PTERO/WIERZBOWSKY/DJS3000/PYHESTY/GREYWOLF/SUPERMAX/VWARLOCK/TNT23/ALSPRU:2025"
	db	0,0,0

;------------------------------------------------------------------------------

; File buffer
FBUFFC:
	ds	50
FBUFF:
