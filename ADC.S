#include <xc.inc>

;------ Code for reading potentiometers -------;
; Modified from https://github.com/ImperialCollegeLondon/MicroprocessorsLab/tree/ADC_test_measurement_V5.4 
; Reads the four potentiometers and returns the value


global  ADC_Setup, ADC_Read, read_pots    
extrn	vol1, vol2, fine_tune1, fine_tune2
  
psect	udata_acs 
delay_counter_ADC:	ds 1	
    
psect	adc_code, class=CODE
;		 ###ADC CODE###
	 
ADC_Setup:				;Initialse appropriate ADC pins on PORTF
	movlw	0x09
	movwf	delay_counter_ADC, A
	movlw	00011101B   ;pins 1-4 of PORTF used by ADC
	movwf	TRISF, A
	movlw	11000000B 	;Keep ANSEL6,7 as analog (pins RF1, RF2)
	movwf	ANCON0, A
	movlw	00000011B 	;ANSEL8,9 as analog (RF3, RF4)
	movwf	ANCON1, A
	movlw   00011001B   ; Select AN6 for measurement initially
			    		; AN7 - 00011101B, AN8 - 00100001B, AN9 - 00100101B
	movwf   ADCON0, A   ; and turn ADC on
	movlw   0x30	    ; Select 4.096V positive reference
	movwf   ADCON1,	A   ; 0V for -ve reference and -ve input
	movlw   0xF6	    ; Right justified output
	movwf   ADCON2, A   ; Fosc/64 clock and acquisition times
	clrf	TRISG, A 	; Displays ADC value for debugging
	clrf	TRISB, A
	return
	
read_pots:
	movlw   00011001B	    ; select AN6 for measurement	
	movwf   ADCON0, A
	call	ADC_Read
	call	delay_ADC
	movff	ADRESH, fine_tune1
	rlncf	fine_tune1, A
	rlncf	fine_tune1, A
	call	delay_ADC
	
	movlw   00011101B	    ; select AN7 for measurement
	movwf   ADCON0, A
	call	ADC_Read
	call	delay_ADC
	movff	ADRESH, fine_tune2
	rlncf	fine_tune2, A
	rlncf	fine_tune2, A
	call	delay_ADC
;	
	movlw   00100001B	    ; select AN8 for measurement 
	movwf   ADCON0, A
	call	ADC_Read
	call	delay_ADC
	movff	ADRESH, vol1
	call	delay_ADC

	movlw   00100101B	    ; select AN9 for measurement 
	movwf   ADCON0, A
	call	ADC_Read
	call	delay_ADC
	movff	ADRESH, vol2
	return

ADC_Read:
	bsf	GO	    ; Start conversion by setting GO bit in ADCON0
adc_loop:
	btfsc   GO	    ; check to see if finished
	bra	adc_loop
	return
	
delay_ADC:	
	decfsz	delay_counter_ADC, F, A	; decrement until zero
	bra	delay_ADC
	movlw	0x09	
	movwf	delay_counter_ADC, A
	return

end