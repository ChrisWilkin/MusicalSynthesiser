#include <xc.inc>

;------ Interrupt code ------;
; File which processes interrupts and sends to DAC
; DAC code adapted from https://github.com/ImperialCollegeLondon/MicroprocessorsLab/tree/Simple_Interrupt_V5.4


global	DAC_Setup, DAC_Int_Hi, transfer
extrn	read_table, keypressed, osc1_l, osc2_l, osc3_l, oct1, oct2, oct3, wf1, wf2, wf3, wf_compare, read_switches
extrn   vol1, vol2, fine_tune1, fine_tune2, ft_hold1, ft_hold2
extrn 	wav1_u, wav1_h, wav2_u, wav2_h, wav3_u, wav3_h, wav4_u, wav4_h


psect	udata_acs   	 
osc1_val:   ds 1    ;These values are updated every interrupt, and added to produce an output
osc2_val:   ds 1    
osc3_val:   ds 1
transfer:   ds 1
osc1_add:   ds 1
osc2_add:   ds 1
    
psect	dac_code, class=CODE
    
DAC_Setup:
	clrf	transfer, A
	clrf	osc1_val, A
	clrf	osc2_val, A
	clrf	osc3_val, A
	clrf	TRISH, A		; Set PORTH as all outputs
	clrf	LATH, A			; Clear PORTH outputs
	clrf	TRISD, A
	clrf	TRISE, A
	movlw	0001001B		; Set timers to 16-bit, Fosc/4/256
	movwf	T1CON, A		; = 62.5KHz clock rate, approx 1sec rollover
	movwf	T3CON, A	
	movwf	T5CON, A	
	movlw	00001011B		;Reset timer on CCP match (CCPxIF bit is set in PIR4)
	movwf	CCP4CON, A		;Setup
	movwf	CCP5CON, A		
	movwf	CCP6CON, A		
	movlw	00010001B   	; CCP4-tmr3, CCP5 - tmr1, CCP6 - tmr5
	movwf	CCPTMRS1, A	
	movlw	00001110B		; Stops false interrupts on CCP4/5/6
	movwf	PIE4, A
	movlw	11000000B
	movwf	INTCON, A
	bsf	GIE					; Enable all interrupts

	return   
 
	
DAC_Int_Hi:					; Determine which oscillator triggered

	btfss	CCP4IF			; check that this is timer1 interrupt
	bra		osc2update
	bcf		CCP4IF			; Reset timer
	movff	wf1, wf_compare	; This is done so the same 'read_table' command can be used for all 3 oscillators
	movlw	00111101B		; 00111100B is max pot value - if greater than this
	cpfslt	fine_tune1, A 	; then we want no detune, skip entirely
	bra		ft1skip
	decfsz	ft_hold1, A 	; Decrement detune counter
	bra		ft1skip
	incf	osc1_l, F, A 	; Increment oscillator by 1 extra detune counter reaches zero
	movff	fine_tune1, ft_hold1 ; If detune counter reaches zero, reset it
ft1skip:
	movwf	oct1, W, A	
	addwf	osc1_l, F, A 	; Increment oscillator pointer based on octave value			
	movff	osc1_l, TBLPTRL
	call	read_table		; Read the relevant table for this oscillator value (uses wf1 to determine)
	movff	transfer, osc1_val  ; 'transfer' is the output of read_table. This is done to ensure osc1_val 
	call	DAC_Update			; does not get corrupted by another interrupt
	
osc2update:
	btfss	CCP5IF
	bra		osc3update
	bcf		CCP5IF
	movff	wf2, wf_compare
	movlw	00111101B	
	cpfslt	fine_tune2, A
	bra		ft2skip
	decfsz	ft_hold2, A
	bra		ft2skip
	incf	osc2_l, F, A
	movff	fine_tune2, ft_hold2	
ft2skip:
	movwf	oct2, W, A	
	addwf	osc2_l, F, A			
	movff	osc2_l, TBLPTRL
	call	read_table
	movff	transfer, osc2_val
	call	DAC_Update
	
osc3update:					; The code for updating the third oscillator has no detune settings
	btfss	CCP6IF
	bra		osc_end			; If interrupt is none of three oscillators, perform no operation
	bcf		CCP6IF
	movff	wf3, wf_compare
	movf	oct3, W, A
	addwf	osc3_l, F, A			
	movff	osc3_l, TBLPTRL	
	call	read_table
	movff	transfer, osc3_val
	call	DAC_Update
osc_end:
	retfie	f


DAC_Update:	
	movff	osc1_val, osc1_add
	bcf		osc1_add, 0, A
	rrncf	osc1_add, A
	movf	vol1, W, A
	mulwf	osc1_add, A
	movff	PRODL, osc1_add
	bcf		osc1_add, 0, A
	rrncf	osc1_add, A
	
	movff	osc2_val, osc2_add
	bcf	osc2_add, 0, A
	rrncf	osc2_add, A
	movf	vol2, W, A
	mulwf	osc2_add, A
	movff	PRODL, osc2_add
	bcf		osc2_add, 0, A
	rrncf	osc2_add, A
    
	clrf	PORTC, A
	movf	osc3_val, W, A
	addwf	osc1_add, W, A
	addwf	osc2_add, W, A
	bnc		finish_update	; if the addition goes past 255, we set it to 255 to avoid looping to zero
	movlw	0xFF

finish_update:	
	movwf	PORTH, A 		; one byte from PM to TABLAT
	bsf	PORTC,0, A
	
	return
	
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
	bra	select_saw			; no need to check since it must be sawtooth
		
select_sin:  
	movf	wav1_u, W,  A	; address of data in PM
	movwf	TBLPTRU, A		; load upper bits to TBLPTRU
	movf	wav1_h, W, A	; address of data in PM
	movwf	TBLPTRH, A		; load high byte to TBLPTRH
	bra	update_DAC
	
select_tri:  
	movf	wav2_u, W,  A	
	movwf	TBLPTRU, A		
	movf	wav2_h, W, A	
	movwf	TBLPTRH, A		
	bra	update_DAC
	
select_squ:  
	movf	wav3_u, W,  A	
	movwf	TBLPTRU, A		
	movf	wav3_h, W, A	
	movwf	TBLPTRH, A		
	bra	update_DAC
	
select_saw:  
	movf	wav4_u, W,  A	
	movwf	TBLPTRU, A		
	movf	wav4_h, W, A	
	movwf	TBLPTRH, A		
	bra	update_DAC
	
update_DAC:	
	tblrd
	movff	TABLAT, transfer 	; A temporary variable for the output
	return

	end

