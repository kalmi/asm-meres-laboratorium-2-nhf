#ifndef _DELAY_INC_
#define _DELAY_INC_
; protection against multiple includes

;*********************************************
;* SW based delay routines:
;*  DELAY40US
;*  DELAY100US
;*  DELAY4MS
;*  DELAY100MS
;*  DELAY1S
;* If possible, use timer/counter HW instead
;*********************************************

.cseg

; (if SIMULATION was not set, assumes real mode)
#if SIMULATION

;****************************************************
; in SIMULATION mode delay loops return immediately

DELAY40US:      ret
DELAY100US:     ret
DELAY4MS:       ret
DELAY100MS:     ret
DELAY1S:        ret

;****************************************************

#else // !SIMULATION

; define stmp temporary registers only if not defined already (to avoid warnings)
; These registers can be freely used for other purposes in main program!
.ifndef stmp
.def stmp  = r23
.endif
.ifndef stmp2
.def stmp2 = r24
.endif
.ifndef stmp3
.def stmp3 = r25
.endif

;**************************
;* Delay 40 microsec
;**************************
DELAY40US:
    push    stmp
    ldi     stmp, 0x8e
DELAY_LOOP40US: 
    dec     stmp
    brne    DELAY_LOOP40US
    pop     stmp
    ret

;**************************
;* Delay 100 microsec
;**************************
DELAY100US:
    push    stmp
    ldi     stmp, 0xd8
DELAY100US_LOOP:    
    nop
    nop
    dec     stmp
    brne    DELAY100US_LOOP
    pop     stmp
    ret

;**************************
;* Delay 4 millisec
;**************************
DELAY4MS:
    push    stmp2
    push    stmp
    ldi     stmp2, 0x39
DELAY4MS_LOOP1: 
    ldi     stmp,0x00
DELAY4MS_LOOP2:
    dec     stmp
    brne    DELAY4MS_LOOP2
    dec     stmp2
    brne    DELAY4MS_LOOP1
    pop     stmp
    pop     stmp2
    ret

;**************************
;* Delay 100msec
;**************************
DELAY100MS:
    push    stmp3
    ldi     stmp3, 25
    rjmp    DELAY_LONGLOOP

;**************************
;* Delay 1 sec
;**************************
DELAY1S:
    push    stmp3
    ldi     stmp3,250
DELAY_LONGLOOP:             ; delay stmp3 * 4MS
    rcall   DELAY4MS
    dec     stmp3
    brne    DELAY_LONGLOOP
    pop     stmp3
    ret

#endif ; SIMULATION

#endif ; _DELAY_INC_
