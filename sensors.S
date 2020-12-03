#include <xc.inc>

;------ Code for reading inputs ------;
; Co-ordinates reading of all inputs (keypad, switches and potentiometers) and saves values into memory


global	keypressed, start_keypad, setup_keypad, wf1, oct1, oct2, oct3, wf1, wf2, wf3, read_switches
global	vol1, vol2, fine_tune1, fine_tune2, ft_hold1, ft_hold2
extrn	read_pots

psect	udata_acs   ; reserve data space in access ram

delay_count_kp:	    ds 1
row_value:	    ds 1
col_value:	    ds 1
tot_value:	    ds 1
output:		    ds 1
keypressed:	    ds 1
kp_L:		    ds 1
kp_H:		    ds 1

wf1:		    ds 1
oct1:		    ds 1
fine_tune1:	    ds 1
ft_hold1:	    ds 1 ; Decrementing fine tune values, need to be set here the first time
vol1:		    ds 1

wf2:		    ds 1
oct2:		    ds 1
fine_tune2:	    ds 1
ft_hold2:	    ds 1
vol2:		    ds 1

wf3:		    ds 1
oct3:		    ds 1

hold1:		    ds 1 ; To process before sending value to an oscillator to avoid interrupt interference



psect	code, abs
	
setup_keypad:	org 0x100	
	bcf	CFGS
	bsf	EEPGD
	movlw	00000001B	; Initialise all input variables to 1
	movwf	wf1, A
	movwf	oct1, A
	movwf	wf2, A
	movwf	oct2, A
	movwf	wf3, A		; Oscillator 3 is fixed as a sine wave in the lowest octave
	movwf	oct3, Ab
	movwf	ft_hold1, A
	movwf	ft_hold2, A

	movlw	0x03
	movwf	delay_count_kp, A

	movlw	15
	movwf	BSR, A
	bsf	PADCFG1, 6, 1 	; Configuring the keypad
	bsf	PADCFG1, 7, 1 	
	bsf	PADCFG1, 5, 1 	
	clrf	LATE, A			
	clrf	LATD, A
	return
	
	; ******* Main programme ****************************************
	
start_keypad:
	call	read_pots		;In ADC.s
	call	read_switches
	call	read
	call	decode
	call	delay_Keypad
	
	movff	kp_L, CCPR4L, A ; Set time until interrupt in the three CCP modules
	movff	kp_H, CCPR4H, A
	movff	kp_L, CCPR5L, A 
	movff	kp_H, CCPR5H, A 
	movff	kp_L, CCPR6L, A 
	movff	kp_H, CCPR6H, A 
	
	return
	
	
read_switches:
	movlw	0x0F	    ; Read octave 1 (4-way) switch on pins 0-3 of PORTD
	movwf	TRISD, A	
	call	delay_Keypad
	movlw	0x0F
	movwf	PORTD, A
	call	delay_Keypad
	movff	PORTD, hold1, A
	call	delay_Keypad
	movlw	0xF0
	addwf	hold1, F, A
	comf	hold1, F, A
	movff	hold1, oct1
	
	movlw	0xF0	    ; Read waveform 1 switch on pins 4-7 of PORTD
	movwf	TRISD, A	
	call	delay_Keypad
	movlw	0xF0
	movwf	PORTD, A
	call	delay_Keypad
	movff	PORTD, hold1, A
	call	delay_Keypad
	movlw	0x0F
	addwf	hold1, F, A
	comf	hold1, F, A
	swapf	hold1, F, A
	movff	hold1, wf1
	call	delay_Keypad

	movlw	0x0F	    ; Read octave 2 switch on pins 0-3 of PORTJ
	movwf	TRISJ, A	
	call	delay_Keypad
	movlw	0x0F
	movwf	PORTJ, A
	call	delay_Keypad
	movff	PORTJ, hold1, A
	call	delay_Keypad
	movlw	0xF0
	addwf	hold1, F, A
	comf	hold1, F, A
	movff	hold1, oct2
	
	movlw	0xF0	    ; Read waveform 2 switch on pins 4-7 of PORTJ
	movwf	TRISJ, A	
	call	delay_Keypad
	movlw	0xF0
	movwf	PORTJ, A
	call	delay_Keypad
	movff	PORTJ, hold1, A
	call	delay_Keypad
	movlw	0x0F
	addwf	hold1, F, A
	comf	hold1, F, A
	swapf	hold1, F, A
	movff	hold1, wf2
	call	delay_Keypad
	return


read:	
	movlw	0x0
	clrf	tot_value, A
	clrf	row_value, A
	clrf	col_value, A
    
	movlw	0x0F	    ; Set 4-7 as output and 0-3 as input
	movwf	TRISE, A	
	call	delay_Keypad
	movlw	0x0F
	movwf	PORTE, A
	call	delay_Keypad
	movff	PORTE, col_value, A
	call	delay_Keypad
	
	movlw	0xF0	    ; Set 4-7 as input and 0-3 as output
	movwf	TRISE, A	
	call	delay_Keypad
	movlw	0xF0
	movwf	PORTE, A
	call	delay_Keypad
	movff	PORTE, row_value
	call	delay_Keypad
	
	movlw	0x0
	movwf	tot_value, A
	addwf	row_value, W, A
	addwf	col_value, W, A
	movwf	tot_value, A
	comf	tot_value, F, A
	call	delay_Keypad
	
	return


decode:
	; First check that the value is within index range 17-136
	movlw	0x0
	movwf	output, A
	clrf	kp_L, A
	clrf	kp_H, A
	movlw	00010000B
	cpfsgt	tot_value, A
	return	
	movlw	10001001B
	cpfslt	tot_value, A
	return
	movff	tot_value, output
	call	read_table_keypad
	return


read_table_keypad:		; The comments here indicate the key label and musical note
	movlw	00011000B
	cpfseq	output, A   ; F, D 
	goto	$ + 12
	movlw	213
	movwf	kp_L, A
	clrf	kp_H, A
	return
	movlw	00010100B   ; 3, C#
	cpfseq	output, A
	goto	$ + 12
	movlw	225;225
	movwf	kp_L, A
	clrf	kp_H, A
	return
	movlw	00010010B   ; 2, C
	cpfseq	output, A
	goto	$ + 12
	movlw	239; 239
	movwf	kp_L, A
	clrf	kp_H, A
	return
	movlw	00010001B   ; 1, B
	cpfseq	output, A
	goto	$ + 12
	movlw	253
	movwf	kp_L, A
	clrf	kp_H, A
	return
	
	movlw	00101000B   ; E, A#
	cpfseq	output, A 
	goto	$ + 12
	movlw	0x0C;268
	movwf	kp_L, A
	bsf	kp_H,0, A
	return
	movlw	00100100B   ; 6, A
	cpfseq	output, A
	goto	$ + 12
	movlw	0x1C ;284
	movwf	kp_L, A
	bsf	kp_H,0, A
	return
	movlw	00100010B   ; 5, G#
	cpfseq	output, A
	goto	$ + 12
	movlw	0x2D ;301
	movwf	kp_L, A
	bsf	kp_H,0, A
	return
	movlw	00100001B   ; 4, G
	cpfseq	output, A
	goto	$ + 12
	movlw	0x3F ;319
	movwf	kp_L, A
	bsf	kp_H,0, A
	return
	
	movlw	01001000B   ; D, F#
	cpfseq	output, A
	goto	$ + 12
	movlw	0x52 ;338
	movwf	kp_L, A
	bsf	kp_H,0, A
	return
	movlw	01000100B   ; 9, F
	cpfseq	output, A
	goto	$ + 12
	movlw	0x66;358
	movwf	kp_L, A
	bsf	kp_H,0, A
	return
	movlw	01000010B   ; 8, E
	cpfseq	output, A
	goto	$ + 12
	movlw	0x7B;379
	movwf	kp_L, A
	bsf	kp_H,0, A
	return
	movlw	01000001B   ; 7, D#
	cpfseq	output, A
	goto	$ + 12
	movlw	0x92;402
	movwf	kp_L, A
	bsf	kp_H,0, A
	return
	
	movlw	10001000B   ; C, D
	cpfseq	output, A
	goto	$ + 12
	movlw	0xAA;426
	movwf	kp_L, A
	bsf	kp_H,0, A
	return
	movlw	10000100B   ; B, C#
	cpfseq	output, A
	goto	$ + 12
	movlw	0xC3;451
	movwf	kp_L, A
	bsf	kp_H,0, A
	return
	movlw	10000010B   ; 0, C
	cpfseq	output, A
	goto	$ + 12
	movlw	0xDE; 478
	movwf	kp_L, A
	bsf	kp_H,0, A
	return
	movlw	10000001B   ; A, B
	cpfseq	output, A
	goto	$ + 12
	movlw	0xFA;506
	movwf	kp_L, A
	bsf	kp_H,0, A
	return

	clrf	kp_L, A 	; If keypad is not equal to these values
	clrf	kp_H, A 	; return zero
	return


delay_Keypad:	
	decfsz	delay_count_kp, F, A	; decrement until zero
	bra	delay_Keypad
	movlw	0x09	
	movwf	delay_count_kp, A
	return
 
	