#include <xc.inc>
#include <pic18_chip_select.inc>

;------ Main code document ------;
; Calls all the setup subroutines and starts polling inputs (sensors) indefinitely

global	read_table, osc1_l, osc2_l, osc3_l, wf_compare, transfer
global  wav1_u, wav1_h, wav2_u, wav2_h, wav3_u, wav3_h, wav4_u, wav4_h

extrn DAC_Setup, DAC_Int_Hi, keypressed, start_keypad, setup_keypad
extrn SinTable, TriTable, SquareTable, SawTable, wf1, ADC_Setup

	
psect	udata_acs  		; Reserve data space in access ram
counter:	    ds 1    ; Reserve one byte for a counter variable

			    		; Upper and higher tblptr set for each wavform lookup table
			    		; Each oscillator has its own tblptrLOWER which goes 0-255
wav1_u:		    ds 1   
wav1_h:		    ds 1    ; Sine wave

    
wav2_u:		    ds 1
wav2_h:		    ds 1    ; Triangle wave

    
wav3_u:		    ds 1
wav3_h:		    ds 1    ; Square wave

wav4_u:		    ds 1
wav4_h:		    ds 1    ; Sawtooth wave


osc1_l:		    ds 1
osc2_l:		    ds 1
osc3_l:		    ds 1
    
wf_compare:	    ds 1    ; Waveform set during interrupt and used to decide which table to look at
    

    

psect	code, abs	
rst: 	org 0x00
 	goto	setup

int_hi:	org	0x0008		; high vector for interrupts
	goto	DAC_Int_Hi
	
	; ******* Main programme ****************************************

	
setup:	
	bcf	CFGS			; Point to Flash program memory  
	bsf	EEPGD 			; Access Flash program memory
	clrf	TRISH, A

	clrf	TRISC, A    ; This is for the DAC WR pin (00000001)
	clrf	TRISB, A
	movlw	00000001B
	movwf	PORTC, A

	call	DAC_Setup	
	call	ADC_Setup
	call	setup_keypad

						; Set the table pointer values for each lookup table
	movlw	low highword(SinTable)
	movwf	wav1_u, A
	movlw	high(SinTable)
	movwf	wav1_h, A
	movlw	low highword(TriTable)
	movwf	wav2_u, A
	movlw	high(TriTable)
	movwf	wav2_h, A
	movlw	low highword(SquareTable)
	movwf	wav3_u, A
	movlw	high(SquareTable)
	movwf	wav3_h, A
	movlw	low highword(SawTable)
	movwf	wav4_u, A
	movlw	high(SawTable)
	movwf	wav4_h, A

						; Initialise oscillator phases to zero
	clrf	osc1_l, A
	clrf	osc2_l, A
	clrf	osc3_l, A
	
	goto	start
	
start: 	
	call	start_keypad ; Starts polling the keypad (and other inputs)
	bra	start

read_table:
	movlw	00000001B
	cpfsgt	wf_compare, A
	bra	select_sin
	movlw	00000010B
	cpfsgt	wf_compare, A
	bra	select_tri
	movlw	00000100B
	cpfsgt	wf_compare, A
	bra	select_squ
	bra	select_saw	;no other options
	
select_sin:  
	movf	wav1_u, W,  A	; address of data in PM
	movwf	TBLPTRU, A		; load upper bits to TBLPTRU
	movf	wav1_h, W, A	; address of data in PM
	movwf	TBLPTRH, A		; load high byte to TBLPTRH
	bra	update_DAC
	
select_tri:  
	movf	wav2_u, W,  A	; address of data in PM
	movwf	TBLPTRU, A		; load upper bits to TBLPTRU
	movf	wav2_h, W, A	; address of data in PM
	movwf	TBLPTRH, A		; load high byte to TBLPTRH
	bra	update_DAC
	
select_squ:  
	movf	wav3_u, W,  A	; address of data in PM
	movwf	TBLPTRU, A		; load upper bits to TBLPTRU
	movf	wav3_h, W, A	; address of data in PM
	movwf	TBLPTRH, A		; load high byte to TBLPTRH
	bra	update_DAC
	
select_saw:  
	movf	wav4_u, W,  A	; address of data in PM
	movwf	TBLPTRU, A		; load upper bits to TBLPTRU
	movf	wav4_h, W, A	; address of data in PM
	movwf	TBLPTRH, A		; load high byte to TBLPTRH
	bra	update_DAC
	
update_DAC:	
	tblrd
	movff	TABLAT, transfer
	return
