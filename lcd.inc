#ifndef _LCD_INC_
#define _LCD_INC_

;************************************************************************************
;* LCD AVR assembly API
;* Original code by  Puzsar, 2004
;*   Rewritten by     Szell, 2011
;* Bug reports to szell at mit
;************************************************************************************
;* It works on 20x4 LCD based on the Hitachi HD44780 lcd controler
;* and can be easily modified to work with other LCDs
;* Busy flag read not supported, delays used instead
;************************************************************************************
;* Connections
;* LCD CONTROLS
;* PortA.0   Lcd RS
;* PortA.1   Lcd EN
;*       Lcd R/W directly low, only write
;*           Busy flag read sot supported -> delay is used instead
;*       Lcd D0..D3 not connected
;* PortA.4   Lcd D4
;* PortA.5   Lcd D5
;* PortA.6   Lcd D6
;* PortA.7   Lcd D7
;* PortB.5   Backlight (1=ON)
;***********************************************************************************
;* Public routines:
;* basic output
;*  LCD_INIT, LCD_OUT, LCD_PUTCHAR, LCD_GOTOXY (and LCD_COMMAND)
;* commands:
;*  LCD_ON, LCD_OFF
;*  LCD_CLS, LCD_HOME, LCD_BACKSPACE, LCD_CR, LCD_LF
;*  LCD_CURSOR_R/L/U/D, LCD_CURSOR_OFF/NORMAL/BLINK
;*  LCD_SHIFT_R/L
;* advanced/fancy output:
;*  LCD_FLASH_STR, LCD_DELAY_FLASH_STR, LCD_EEPROM_STR
;***********************************************************************************

#if SIMULATION
#warning "LCD routines won't work on real hardware in simulation!"
#endif

;************************************************************************************
;* register variables
; parameters for LCD routines - they are restored to their call value at return
.def param  = r21
.def param2 = r22

; internal registers - don't use them in main code!
.def lcd_x     = r3
.def lcd_y     = r4

; define stmp temporary register only if not defined already (to avoid warnings)
; These registers can be freely used for other purposes in main program!
.ifndef stmp
.def stmp  = r23
.endif

;************************************************************************************
; constants
.equ    LcdRs = 0   ;LCD RS pin connected to PortA0
.equ    LcdEn = 1   ;LCD E pin connected to PortA1
.equ    DB4   = 4
.equ    DB5   = 5
.equ    DB6   = 6
.equ    DB7   = 7

.equ    LineLength=20
.equ    NoOfLines=4

.equ    FirstLine_Add =0b10000000 ;Base address of first line for 2x16 lcd
.equ    SecondLine_Add=0b11000000 ;+40 Base address of second line
.equ    ThirdLine_Add =0b10010100 ;+14 Base address of 3.line 
.equ    FourthLine_Add=0b11010100 ;+54 Base address of 4.line

; these command characters may be embedded in flash/EEPROM strings
.equ    LCMD_CLS            = 0x01
.equ    LCMD_HOME           = 0x02
.equ    LCMD_ON             = 0x03
.equ    LCMD_OFF            = 0x04
.equ    LCMD_CURSOR_OFF     = 0x05      ; hide cursor
.equ    LCMD_CURSOR_NORMAL  = 0x06      ; horizontal line cursor
.equ    LCMD_CURSOR_BLINK   = 0x07      ; blinking block cursor
.equ    LCMD_BS             = 0x08      ; backspace - delete previous char 
.equ    LCMD_CURSOR_U       = 0x09      ; cursor up
.equ    LCMD_LF             = 0x0A      ; cursor down <=> LF: line feed
.equ    LCMD_CURSOR_L       = 0x0B      ; cursor left
.equ    LCMD_CURSOR_R       = 0x0C      ; cursor right
.equ    LCMD_CR             = 0x0D      ; CR: carriage return - cursor to first col
.equ    LCMD_SHIFT_L        = 0x10      ; shift display left (~scroll)
.equ    LCMD_SHIFT_R        = 0x11      ; shift display right
.equ    LCMD_DELAY4MS       = 0x12      ; software wait loops
.equ    LCMD_DELAY100MS     = 0x13
.equ    LCMD_DELAY1S        = 0x14

;************************************************************************************

.cseg

;********************
;* Lcd Init
;********************
LCD_INIT:
    push    param
    push    stmp
    rcall   DELAY4MS        ; Wait for LCD power up
    ;rcall   DELAY1S 

    ldi     stmp, 0x00      ; PORTA Low
    out     PORTA, stmp
    ldi     stmp, 0xFF      ; Make port A pin all outputs
    out     DDRA, stmp

    cbi     PORTA, LcdRs    ; Clear RS

; first 3*8bit mode and then 1*4bit mode, then real programming
; (necessary if reset is not proper due to power up conditions, e.g. USB plugged in)

    ldi     stmp, 0x30      ; 8 bit mode
    out     PORTA, stmp
    rcall   LCD_EPULSE
    rcall   DELAY4MS        ; Wait 4 ms

    ldi     stmp, 0x30      ; 8bit mode
    out     PORTA, stmp
    rcall   LCD_EPULSE
    rcall   DELAY100MS      ; Wait 100 ms

    ldi     stmp, 0x30      ; 8 bit mode
    out     PORTA, stmp
    rcall   LCD_EPULSE
    rcall   DELAY4MS        ; Wait 4 ms

    ldi     stmp, 0x20      ; 4 bit mode
    out     PORTA, stmp
    rcall   LCD_EPULSE
    rcall   DELAY4MS        ; Wait 4ms

    ldi     param, 0x28     ; 4 bit mode real
    rcall   LCD_COMMAND
    rcall   DELAY4MS        ; Wait 4ms
    
    ldi     param, 0x4      ; entry mode set
    rcall   LCD_COMMAND
    
    ldi     param, 0xe      ; display on: 1DCB = 1110 -> display on, cursor on, blink off
    rcall   LCD_COMMAND

    ldi     param, 0x1      ; Clear Display
    rcall   LCD_COMMAND
    rcall   DELAY4MS        ; Wait 4ms

    clr     lcd_x           ; Init cursor position
    clr     lcd_y

    pop     stmp
    pop     param
    ret

;*************************************************************************
;* Write char or command at current LCD cursor position, move cursor
;* If only characters are to be written, use LCD_PUTCHAR.
;* Input: 
;*      param  = character to be written
;*************************************************************************
LCD_OUT:
    push param
    push ZL                 ; store Z reg as that will be used for indirect jump
    push ZH
    cpi  param,0x20
    brlo LCD_CTRL_CHR       ; char is control char
    call LCD_PUTCHAR        ; char is ASCII
    rjmp LCD_CTRL_RET
 LCD_CTRL_CHR:
    ; calculate jump table position: LCD_CTRL_JUMPS + ctrl id
    ldi  ZH, HIGH(LCD_CTRL_JUMPS)
    ldi  ZL, LOW(LCD_CTRL_JUMPS)
    add  ZL, param
    brcc LCD_CTRL_CALL
    inc  ZH
 LCD_CTRL_CALL:
    ; fake CALL - we want to restore context at the end, but don't want to 
    ; return into the jump table -> RET will find LCD_CTRL_RET on the stack
    ldi  param, LOW(LCD_CTRL_RET)
    push param
    ldi  param, HIGH(LCD_CTRL_RET)
    push param
    IJMP                    ; perform jump to the Z address
    
 LCD_CTRL_JUMPS:
 ; LCD command jump table - empty slots can be extended with other subroutines
 ; These jumps are CALLs in fact: return address is on stack (see LCD_CTRL_CALL)
 ; command bytes may be embedded in string (used by e.g. LCD_FLASH_STR): 
 ; "Hello", 13, 10, "World!" (13, 10 as carriage return, line feed) would mean 
 ; Hello
 ; World!
    nop  ; 0x00 -- end of string
    rjmp LCD_CLS            ; 0x01
    rjmp LCD_HOME           ; 0x02
    rjmp LCD_ON             ; 0x03
    rjmp LCD_OFF            ; 0x04
    rjmp LCD_CURSOR_OFF     ; 0x05      ; hide cursor
    rjmp LCD_CURSOR_NORMAL  ; 0x06      ; horizontal line cursor
    rjmp LCD_CURSOR_BLINK   ; 0x07      ; blinking block cursor
    rjmp LCD_BACKSPACE      ; 0x08
    rjmp LCD_CURSOR_U       ; 0x09      ; cursor up
    rjmp LCD_LF             ; 0x0A      ; cursor down <=> LF: line feed
    rjmp LCD_CURSOR_L       ; 0x0B      ; cursor left
    rjmp LCD_CURSOR_R       ; 0x0C      ; cursor right
    rjmp LCD_CR             ; 0x0D      ; CR: carriage return - cursor to first col
    ret                     ; 0x0E      ; ret jumps to LCD_CTRL_RET
    ret                     ; 0x0F      
    rjmp LCD_SHIFT_L        ; 0x10
    rjmp LCD_SHIFT_R        ; 0x11
    rjmp DELAY4MS           ; 0x12
    rjmp DELAY100MS         ; 0x13
    rjmp DELAY1S            ; 0x14
    ret                     ; 0x15
    ret                     ; 0x16
    ret                     ; 0x17
    ret                     ; 0x18
    ret                     ; 0x19
    ret                     ; 0x1A
    ret                     ; 0x1B
    ret                     ; 0x1C
    ret                     ; 0x1D
    ret                     ; 0x1E
    ret                     ; 0x1F

 LCD_CTRL_RET:
    pop ZH
    pop ZL
    pop param
    ret

;*******************************************************************************
;* Write ASCII char at current LCD cursor position, modify position at line end
;* Input: 
;*      param  = character to be written
;*******************************************************************************
LCD_PUTCHAR:
    push    stmp

    ; write character in LCD RAM
    mov     stmp, param
    andi    stmp, 0xF0
    out     PORTA, stmp     ; output HI nibble
    sbi     PORTA, LcdRs    ; data 
    rcall   LCD_EPULSE      
    mov     stmp, param
    swap    stmp            ; LO nibble
    andi    stmp, 0xF0
    out     PORTA, stmp
    sbi     PORTA, LcdRs    ; data
    rcall   LCD_EPULSE
    rcall   DELAY40US

    ; move cursor 
    inc     lcd_x
    ldi     stmp, LineLength    ; check if EOL reached
    cpse    lcd_x, stmp         
    rjmp    LCD_PUTCHAR_EXIT    ; do not wrap if not necessary

    call    LCD_WRAPCURSOR
    rcall   LCD_GOTOXY_INT

 LCD_PUTCHAR_EXIT:
    pop     stmp
    ret 

; check whether cursor is within param[X] = 0..39 / param2[Y] = 0..3
; if not, wrap around
LCD_WRAPCURSOR:
    push    stmp
    ; check X position
    ldi     stmp, LineLength
    cp      lcd_x, stmp         ; Check if we are at the last Xpos
    breq    LCD_WRAPX_END

    ldi     stmp, 255           ; Check if we are before the first Xpos    
    cp      lcd_x, stmp
    breq    LCD_WRAPX_START

    rjmp    LCD_WRAPY           ; LCD_X is within bounds

 LCD_WRAPX_END:
    clr     lcd_x               ; Point X at the first row
    inc     lcd_y               ; step Y to next line
    rjmp    LCD_WRAPY

 LCD_WRAPX_START:
    ldi     stmp, LineLength-1  ; X is at end of prev row
    mov     lcd_x, stmp
    dec     lcd_y               ; Y is in prev line

 LCD_WRAPY:
    ldi     stmp, 255
    cp      lcd_y, stmp         ; if Y is before first line
    brne    LCD_WRAPY_END
    ldi     stmp, NoOfLines-1   ; then move it to last line
    mov     lcd_y, stmp
    rjmp    LCD_WRAPCURSOR_END

 LCD_WRAPY_END:
    ldi     stmp, NoOfLines
    cp      lcd_y, stmp         ; check if we are after the last line of the lcd
    brlo    LCD_WRAPCURSOR_END  ; if not, nothing changes

    clr     lcd_y               ; if yes, Y should point to line 0

 LCD_WRAPCURSOR_END:
    pop     stmp
    ret

;**************************************************
;* LCD_GOTOXY set cursor position LCD_X, LCD_Y
;* Input: 
;*      param  = X position: 0..19
;*      param2 = Y position: 0..3
;**************************************************
LCD_GOTOXY:
    mov     lcd_x, param
    mov     lcd_y, param2

 LCD_GOTOXY_INT:     ; internal part of GOTOXY: uses directly lcd_x and lcd_y
    push stmp
    push param

    mov     stmp, lcd_y
    ldi     param, FirstLine_Add
    cpi     stmp, 0            ; check whether Y==0
    breq    LCD_GOTOXY_MOVE
    ldi     param, SecondLine_Add
    cpi     stmp, 1            ; check whether Y==1
    breq    LCD_GOTOXY_MOVE
    ldi     param, ThirdLine_Add
    cpi     stmp, 2            ; check whether Y==2
    breq    LCD_GOTOXY_MOVE
    ldi     param, FourthLine_Add ; assume Y==3
    
 LCD_GOTOXY_MOVE:
    add     param, lcd_x         ; add X value to address
    rcall   LCD_COMMAND             ; Set DDRam Add
    pop     param
    pop     stmp
    ret

;************************************************************
;* LCD_CLS  clears screen and returns cursor to 0,0
;* LCD_HOME moves cursor to 0, 0
;* LCD_ON   enable LCD display
;* LCD_OFF  disable LCD display
;* LCD_CURSOR_R/L/U/D move cursor in 4 directions 1 step
;* LCD_CURSOR_OFF/NORMAL/BLINK  set cursor format
;* LCD_BACKSPACE  clear prev char and step cursor back
;* LCD_SHIFT_R/L  shift display 
;* (warning: GOTOXY/prints do not know about coord shifts!)
;************************************************************
.macro LcdCmd
    push  param
    ldi   param, @0
    rcall LCD_COMMAND
    pop   param
.endmacro


LCD_ON:
    LcdCmd 0b00001100           ; macro
    ret

LCD_OFF:
    LcdCmd 0b00001000
    ret

LCD_CLS:
    LcdCmd 0b00000001   ; CLS command
    rcall DELAY4MS
    clr   lcd_x         ; reset cursor position
    clr   lcd_y
    ret

LCD_HOME:
    LcdCmd 0b00000010   ; HOME command
    rcall DELAY4MS
    clr   lcd_x         ; reset cursor position
    clr   lcd_y
    ret

LCD_CURSOR_R:
;   LcdCmd 0b00010100   ; default cursor movement wraps from line 0 to line 2
    inc   lcd_x
; wrap from line 0 last pos to line 1 first pos; ...
; from line 3 last pos to line 0 first pos
    rcall LCD_WRAPCURSOR
    rcall LCD_GOTOXY_INT
    ret

LCD_CURSOR_L:
;   LcdCmd 0b00010000
    dec   lcd_x
; wrap from line 0 first pos to line 3 last pos
    rcall LCD_WRAPCURSOR
    rcall LCD_GOTOXY_INT
    ret

LCD_CURSOR_U:
    dec   lcd_y
    rcall LCD_WRAPCURSOR
    rcall LCD_GOTOXY_INT
    ret

LCD_LF:
LCD_CURSOR_D:
    inc   lcd_y
    rcall LCD_WRAPCURSOR
    rcall LCD_GOTOXY_INT
    ret

LCD_CR:
    clr   lcd_x
    rcall LCD_GOTOXY_INT
    ret

LCD_BACKSPACE:
    ; clears prev char but does not try to do more (e.g. pull following chars)
    push  param
    dec   lcd_x
    rcall LCD_WRAPCURSOR
    rcall LCD_GOTOXY_INT
    ldi   param, ' '   ; clear char
    rcall LCD_PUTCHAR
    dec   lcd_x           ; and go back to cleared pos
    rcall LCD_WRAPCURSOR
    rcall LCD_GOTOXY_INT
    pop   param
    ret

LCD_CURSOR_OFF:
    LcdCmd 0b00001100
    ret

LCD_CURSOR_NORMAL:
    LcdCmd 0b00001110
    ret

LCD_CURSOR_BLINK:   ; blinking block cursor
    LcdCmd 0b00001111
    ret

LCD_SHIFT_L:
    LcdCmd 0b00011000
    ret

LCD_SHIFT_R:
    LcdCmd 0b00011100
    ret



;******************************************************************************
;* Write string to LCD from Flash (pointed by Z register) until $0
;* Warning! LPM addresses the FLASH bytewise, while labels are word-based.
;* Command characters (e.g. cursor movements, delay) are allowed, see LCD_OUT.
;*
;* Input:
;*        ZH:ZL = byte-address of flash memory pointing to 0-terminated string
;*
;* E.g. ZL = LOW(str_addr<<1), ZH = HIGH(str_addr<<1) where
;* str_addr:
;*     .db "Example", 0        ; [in .cseg]
;******************************************************************************
LCD_FLASH_STR:
    push  param
    push  ZL
    push  ZH

 LCD_FLASH_LOOP:
    lpm   param, Z+     ; Load constant from program
    cpi   param, 0      ; Check if we have reached the End of string
    breq  LCD_FLASH_STR_END
    rcall LCD_OUT
    rjmp  LCD_FLASH_LOOP

;******************************************************************************
;* Write string to LCD from Flash (pointed by Z register) until $0
;* Warning! LPM addresses the FLASH bytewise, while labels are word-based.
;* Command characters (e.g. cursor movements, delay) are not allowed.
;*
;* Input:
;*        ZH:ZL  = byte-address of flash memory pointing to 0-terminated string
;*		  param2 = terminator character
;*
;* E.g. ZL = LOW(str_addr<<1), ZH = HIGH(str_addr<<1) where
;* str_addr:
;*     .db "Example", 0        ; [in .cseg]
;******************************************************************************
LCD_FLASH_STR_NOCOMMAND:
    push  param
    push  ZL
    push  ZH

 LCD_FLASH_LOOP_NOCOMMAND:
    lpm   param, Z+    		 ; Load constant from program
    cp    param, param2      ; Check if we have reached the End of string
    breq  LCD_FLASH_STR_END
    rcall LCD_PUTCHAR
    rjmp  LCD_FLASH_LOOP_NOCOMMAND

;*********************************************************************
;* Delayed write string to LCD from Flash (Z register pointer)
;*********************************************************************

LCD_DELAY_FLASH_STR:
    push  param
    push  ZL
    push  ZH

 LCD_DELAY_FLASH_LOOP:
    lpm   param, Z+     ; Load constant from program
    cpi   param, 0      ; Check if we have reached the End of string
    breq  LCD_FLASH_STR_END
    rcall LCD_OUT
    rcall DELAY100MS
    rjmp  LCD_DELAY_FLASH_LOOP

 LCD_FLASH_STR_END:
    pop ZH
    pop ZL
    pop stmp
    ret

;******************************************************************************
;* Write string to LCD from EEPROM (pointed by EEAR register) until $0
;* Command characters (e.g. cursor movements, delay) are allowed, see LCD_OUT.
;*
;* Input:
;*        EEARH:EEARL = EEPROM memory address of a 0-terminated string
;*
;* - IMPORTANT: EEPROM should be separately programmed from .eep file by Tools/Program AVR
;* - use .eseg for EEPROM segment
;******************************************************************************
LCD_EEPROM_STR:
    push  param
    in    param, EEARL   ; store EEARL and EEARH
    push  param
    in    param, EEARH
    push  param
 LCD_EEPROM_LOOP:
    rcall EEPROM_READ_SEQ
    cpi   param, 0        ; 0 code: end of string
    breq  LCD_EEPROM_STR_END
    cpi   param, 0xFF     ; if uninitialized EEPROM content, jump to error handling
    breq  LCD_EEPROM_UNINIT
    rcall LCD_OUT
    rjmp  LCD_EEPROM_LOOP
 LCD_EEPROM_UNINIT:       ; uninitialized EEPROM content->
    rcall LCD_CLS     
    ldi   param, 'E'      ; display "Err" and wait 100ms
    rcall LCD_PUTCHAR
    ldi   param, 'r'
    rcall LCD_PUTCHAR
    rcall LCD_PUTCHAR
    rcall DELAY100MS
 LCD_EEPROM_STR_END:
    pop   param
    out   EEARH, param    ; restore EEARH and EEARL
    pop   param
    out   EEARL, param
    pop   param
    ret

;**********************************************
;* Read byte from EEPROM
;* Input:
;*        EEARH:EEARL = EEPROM memory address
;* Output:
;*        param  = byte read
;**********************************************
EEPROM_READ:
    sbic EECR, EEWE     ; Wait for completion of previous write
    rjmp EEPROM_READ
    sbi  EECR, EERE     ; Start eeprom read by writing EERE
    in   param, EEDR    ; Read data from data register
    ret

;**********************************************
;* Read byte from EEPROM and increment address
;* Input:
;*        EEARH:EEARL = EEPROM memory address
;* Output:
;*        param = byte read from address
;**********************************************
EEPROM_READ_SEQ:
    push stmp
    call EEPROM_READ

    in   stmp, EEARL         ; Increment EEPROM pointer
    inc  stmp
    out  EEARL, stmp
    brne EEPROM_READ_SEQ_END ; EEARH should be incremented only if EEARL became 0
    in   stmp, EEARH
    inc  stmp
    out  EEARH, stmp
EEPROM_READ_SEQ_END:
    pop  stmp
    ret



;**********************************************
;* Write param to LCD control register
;* Input: 
;*      param  = command byte to be written
;**********************************************
LCD_COMMAND:
    push    stmp
    cbi     PORTA, LcdRs
    mov     stmp, param
    andi    stmp, 0xF0
    out     PORTA, stmp         ; out high nibble
    rcall   LCD_EPULSE
    mov     stmp, param
    swap    stmp
    andi    stmp, 0xF0
    out     PORTA, stmp         ; out low nibble
    rcall   LCD_EPULSE
    rcall   DELAY40US
    pop     stmp
    ret

;***************************
;* Lcd enable pin pulse
;* (internal)
;***************************
LCD_EPULSE:
    sbi     PORTA, LcdEn    ;E high
    nop
    nop
    nop
    nop
    cbi     PORTA, LcdEn    ;E Low
    ret

;********************************************
;* Lcd custom character registering mode
;********************************************
LCD_CUSTOM_MODE:
    push    stmp

    ; write character in LCD RAM
	ldi		stmp, 0b0100_0000
    out     PORTA, stmp     	; output HI nibble
    rcall   LCD_EPULSE      
	ldi		stmp, 0b0000_0000
    out     PORTA, stmp			; output LO nibble
    rcall   LCD_EPULSE
    rcall   DELAY40US
	
	pop     stmp
    ret
	
;********************************************
;* Lcd character output mode
;********************************************
LCD_OUTPUT_MODE:
	push    stmp

    ; write character in LCD RAM
	ldi		stmp, 0b1000_0000
    out     PORTA, stmp     	; output HI nibble
    rcall   LCD_EPULSE      
	ldi		stmp, 0b0000_0000
    out     PORTA, stmp			; output LO nibble
    rcall   LCD_EPULSE
    rcall   DELAY40US
	
	pop     stmp
    ret
	
.include "delay.inc"

#endif ; _LCD_INC_
