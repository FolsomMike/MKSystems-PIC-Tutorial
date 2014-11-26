;--------------------------------------------------------------------------------------------------
; Project:  MKSystems PIC Tutorial
; Date:     11/22/14
; Revision: See Revision History notes below.
;
;
; Overview:
;
; A program which demonstrates the basic functionality of the PIC controller.
;
;
; --- Running the Program in the Simulator ---
;
; Right click on the project in the Projects pane, choose "Set as Main Project".
; Click Window/PIC Memory View/SFRs to view the Special Function Registers.
; Click Window/PIC Memory View/File Registers to view the data memory.
; Search for "start:" and set a breakpoint on the next line.
; Click the "Debug Main Project" icon in the toolbar above.
; If a window appears with a message that the "previous tool is no longer available", click on
;   "Simulator" and then click "OK".
; Step through the program and watch the SFR and File Register windows to observe changes to data.
; Right click in the source file window to add a watch to any memory location. Gobals do not
;  seem to be supported for variables declared in a cblock, so the actual memory location must
;  be entered. Enter the memory address in the form: 0x20
; To find the actual memory location for a symbol (such as "flags" in this project), open the
;  Tutorial-1.lst file in the Projects pane. The addresses of all symbols will be shown to the
;  far left next to each symbol.
;
;--------------------------------------------------------------------------------------------------
; Notes on PCLATH -- not necessary to understand for beginners
;
; The program counter (PC) is 13 bits. The lower 8 bits can be read and written as register PCL.
; The upper bits cannot be directly read or written.
;
; When the PCL register is written, PCLATH<4:0> is copied at the same time to the upper 5 bits of
; PC.
;
; When a goto is executed, 11 bits embedded into the goto instruction are loaded into the PC<10:0>
; while bits PCLATH<4:3> are copied to bits PC<12:11>
;
; Changing PCLATH does NOT instantly change the PC register. The PCLATH will be used the next time
; a goto is executed (or similar opcode) or the PCL register is written to. Thus, to jump farther
; than the 11 bits (2047 bytes) in the goto opcode will allow, the PCLATH register is adjusted
; first and then the goto executed.
;
;--------------------------------------------------------------------------------------------------
;
; Revision History:
;
; 1.0   Code copied from "OPT EDM LED PIC" project.
;
;
;--------------------------------------------------------------------------------------------------
; Miscellaneous Notes
;
; incf vs decf rollover -- for advanced users
;
; When incrementing multi-byte values, incf can be used because it sets the Z flag - then the Z
; flag is set, the next byte up should then be incremented.
; When decrementing multi-byte values, decf CANNOT be used because it sets the Z flag but NOT the
; C flag.  The next byte up is not decremented when the lower byte reaches zero, but when it rolls
; under zero.  This can be caught by loading w with 1 and then using subwf and catching the C flag
; cleared. (C flag is set for a roll-over with addwf, cleared for roll-under for subwf.
; For a quickie but not perfect count down of a two byte variable, decf and the Z flag can be used
; but the upper byte will be decremented one count too early.
;
;--------------------------------------------------------------------------------------------------
; Operational Notes
;
;
;
;--------------------------------------------------------------------------------------------------
; Defines
;
; Example of how to create constants using binary, decimal, and hexadecimal values.

SOME_BINARY_VALUE                   EQU     b'10100100'

SOME_DECIMAL_VALUE                  EQU     .217

SOME_HEX_VALUE                      EQU     0x00

; end of Defines
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; Configurations, etc. for the Assembler Tools and the PIC
;
; It is not important to understand this section as a beginner.
;
; The only part which usually changes for most projects is the CONFIG1 and CONFIG2 settings.
;

	LIST p = PIC16F1459	;select the processor

    errorlevel  -306 ; Suppresses Message[306] Crossing page boundary -- ensure page bits are set.

    errorLevel  -302 ; Suppresses Message[302] Register in operand not in bank 0.

	errorLevel	-202 ; Suppresses Message[205] Argument out of range. Least significant bits used.
					 ;	(this is displayed when a RAM address above bank 1 is used -- it is
					 ;	 expected that the lower bits will be used as the lower address bits)

#INCLUDE <p16f1459.inc> 		; Microchip Device Header File


; Specify Device Configuration Bits

; CONFIG1
; __config 0xF9E4
 __CONFIG _CONFIG1, _FOSC_INTOSC & _WDTE_OFF & _PWRTE_OFF & _MCLRE_OFF & _CP_OFF & _BOREN_OFF & _CLKOUTEN_OFF & _IESO_OFF & _FCMEN_OFF
; CONFIG2
; __config 0xFFFF
 __CONFIG _CONFIG2, _WRT_ALL & _CPUDIV_NOCLKDIV & _USBLSCLK_48MHz & _PLLMULT_4x & _PLLEN_DISABLED & _STVREN_ON & _BORV_LO & _LPBOR_OFF & _LVP_OFF

; _FOSC_INTOSC -> internal oscillator, I/O function on CLKIN pin
; _WDTE_OFF -> watch dog timer disabled
; _PWRTE_OFF -> Power Up Timer disabled
; _MCLRE_OFF -> MCLR/VPP pin is digital input
; _CP_OFF -> Flash Program Memory Code Protection off
; _BOREN_OFF -> Power Brown-out Reset off
; _CLKOUTEN_OFF -> CLKOUT function off, I/O or oscillator function on CLKOUT pin
; _IESO_OFF -> Internal/External Oscillator Switchover off
;   (not used for this application since there is no external clock)
; _FCMEN_OFF -> Fail-Safe Clock Monitor off
;   (not used for this application since there is no external clock)
; _WRT_ALL -> Flash Memory Self-Write Protection on -- no writing to flash
;
; _CPUDIV_NOCLKDIV -> CPU clock not divided
; _USBLSCLK_48MHz -> only used for USB operation
; _PLLMULT_4x -> sets PLL (if enabled) multiplier -- 4x allows software override
; _PLLEN_DISABLED -> the clock frequency multiplier is not used
;
; _STVREN_ON -> Stack Overflow/Underflow Reset on
; _BORV_LO -> Brown-out Reset Voltage Selection -- low trip point
; _LPBOR_OFF -> Low-Power Brown-out Reset Off
; _LVP_OFF -> Low Voltage Programming off
;
; end of configurations
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; Hardware Definitions
;

; Writing to Ports A, B, C
;
; NOTE: For all write operations, it is usually best to write to the port's latch register (LATA,
; LATB, LATC)  in order to avoid read-modify-write issues sometimes caused by writing directly
; to the port's pins.
;
; For reading the input pins, PORTA/PORTB/PORTC is read or any individual bit such as RA0 --
; these are the actual values from the chips pins.
;

; Port A
;
; Change names to something meaningful for each project, such as BUTTON_INPUT, MOTOR_OUTPUT, etc.

BUTTON_OUTPUT           EQU     LATA        ; output to the latch
BUTTON_INPUT            EQU     PORTA       ; read from the port

; example of naming the port twice -- some bits could be button I/O, some motor outputs, so two
; names are given so when the button ports are accessed, the BUTTON_OUTPUT name is used but when
; the motor outputs are used, the MOTOR name is used for clarity

MOTOR_OUTPUT           EQU      LATA        ; output to the latch
MOTOR_INPUT            EQU      PORTA       ; read from the port

BUTTON1                EQU     RA0
BUTTON2                EQU     RA1
MOTOR_START            EQU     RA3
MOTOR_OK               EQU     RA4
;... possibly through PORT_A_5

; Port B

BUTTON2_OUTPUT          EQU     LATB        ; output to the latch
BUTTON2_INPUT           EQU     PORTB       ; read from the port

PORT_B_0                EQU     RB4
PORT_B_1                EQU     RB5
;... possibly through PORT_B_7


; Port C
;

BUTTON3_OUTPUT          EQU     LATC        ; output to the latch
BUTTON3_INPUT           EQU     PORTC       ; read from the port

PORT_C_0                EQU     RC0
PORT_C_1                EQU     RC1
;... possibly through PORT_C_7

; end of Hardware Definitions
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; Software Definitions
;
; ; Change names (such as NORMAL_MODE, IDLE_STATE) to meaningful names for each project.

; bits in flags variable

NORMAL_MODE         EQU     0x00     ; bit 0 of flags variable
ACTIVE_STATE        EQU     0x01     ; bit 1 of flags variable

; other useful constants

MAIN_DELAY_COUNT    EQU     .32

; end of Software Definitions
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; Variables in RAM
;
; Note that you cannot use a lot of the data definition directives for RAM space (such as DB)
; unless you are compiling object files and using a linker command file.  The cblock directive is
; commonly used to reserve RAM space or Code space when producing "absolute" code, as is done here.
;
; The P16F1459 has 32 banks of memory. Several of the banks contain data memory which can be
; defined here with easy-to-use names to refer to the memory locations.
;
; The memory block in each bank is actually starts at location 0x20 for that bank. So then the bank
; is selected, the first memory location is 0x20.
;
; However, when the banks are considered as one large bank, the locations for the memory blocks
; are 0x20 (bank 0), 0xa0 (bank 1), 0x120 (bank 2)...and so on.
;
; In the section below, the locations 0x20, 0xa0, 0x120, etc. are used to define the sections.
; This makes it clearer where the locations are when looking at the memory map in the PIC's data
; sheet.
;
; However, when the 0x20/0xa0/0x120 addresses are used in the code, the upper bits are ignored
; by the instructions so 0x20->0x20, 0xa0->0x20, 0x120->0x20. All the higher addresses actually
; get transformed to 0x20, which is the location in a bank when that bank is selected.
;

; Assign variables in RAM - Bank 0 - must set BSR to 0 to access
; Bank 0 has 80 bytes of free space

 cblock 0x20                ; starting address

    flags                   ; bit 0: 0 = normal mode; 1 = abormal mode
                            ; bit 1: 0 = active state; 1 = idle state
                            ; bit 2: 0 = 
                            ; bit 3: 0 = 
                            ; bit 4: 0 = 
                            ; bit 5: 0 = 
							; bit 6: 0 = 
							; bit 7: 0 = 


    scratch0                ; these can be used by any function
    scratch1
    scratch2
    scratch3
    scratch4
    scratch5
    scratch6
    scratch7
    scratch8
    scratch9
    scratch10

 endc

;-----------------

; Assign variables in RAM - Bank 1 - must set BSR to 1 to access
; Bank 1 has 80 bytes of free space

 cblock 0xa0                ; starting address (0x20 in bank 1)


 endc

;-----------------

; Assign variables in RAM - Bank 3 - must set BSR to 3 to access
; Bank 2 has 80 bytes of free space

 cblock 0x120                ; starting address (0x20 in bank 2)


 endc

;-----------------

;...

; add definitions in more banks here if required

;...

; end of Variables in RAM
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; Power On and Reset Vectors
;

	org 0x00                ; Start of Program Memory

	goto start              ; jump to main code section
	nop			            ; Pad out so interrupt
	nop			            ; service routine gets
	nop			            ; put at address 0x0004.

; interrupt vector at 0x0004

    goto 	handleInterrupt	; points to interrupt service routine

; end of Reset Vectors
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; start
;

start:

    call    setup               ; preset variables and configure hardware

    call    demoCode

    call    studentCode

mainLoop:




    goto    mainLoop
    
; end of start
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; setup
;
; Presets variables and configures hardware.
;
; WARNING: Banks 0 & 1 can be accessed using the FSR registers by loading the FSR*L bytes only
; as the top bit specifies bank 0 or 1 (if FSR*H is zeroed). To use indirect addressing on banks
; 2-31, the FSR*H register will also have to be set.
;

setup:

    clrf   FSR0H            ;high byte of indirect addressing pointers -> 0
    clrf   FSR1H            ;this allows Banks 0 & 1 to be indirectly accessed by setting the FSR*L
                            ;registers only, FSR*H will have to be set to indirectly access higher
                            ;banks

    clrf    INTCON          ; disable all interrupts

    banksel OPTION_REG
    movlw   0x57
    movwf   OPTION_REG      ; Option Register = 0x57   0101 0111 b
                            ; bit 7 = 0 : weak pull-ups are enabled by individual port latch values
                            ; bit 6 = 1 : interrupt on rising edge
                            ; bit 5 = 0 : TOCS ~ Timer 0 run by internal instruction cycle clock (CLKOUT ~ Fosc/4)
                            ; bit 4 = 1 : TOSE ~ Timer 0 increment on high-to-low transition on RA4/T0CKI/CMP2 pin (not applicable here)
							; bit 3 = 0 : PSA ~ Prescaler assigned to Timer0
                            ; bit 2 = 1 : Bits 2:0 control prescaler:
                            ; bit 1 = 1 :    111 = 1:256 scaling for Timer0 (if assigned to Timer0)
                            ; bit 0 = 1 :
    
;end of hardware configuration

    banksel flags           ; using the banksel command will load the BSR register with the proper
                            ; value to select the bank containing "flags"

    clrf    flags           ; zero the memory location "flags"
	
; enable the interrupts

; put the next three lines in when ready to use interrupts

;    bsf     INTCON,PEIE     ; enable peripheral interrupts (Timer0 is a peripheral)
;    bsf     INTCON,T0IE     ; enable TMR0 interrupts
;    bsf     INTCON,GIE      ; enable all interrupts

    return

; end of setup
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; demoCode
;
; Demonstration of different software operations.
;

demoCode:

    banksel flags

    movlw   scratch1            ; point to first byte to be copied
    movwf   FSR0L
    movlw   scratch4            ; point to first byte to be copied to
    movwf   FSR1L

    movlw   .3                  ; number of bytes to copy

    call    copyBlock

    return

; end of demoCode
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; zeroBlock
;
; Zeroes a block of memory
;
; On entry:
;
; WREG = # of bytes to clear
; FSR0L = first byte in block to be cleared
; Appropriate bank should already be selected
;

zeroBlock:

    movwf   scratch0

    movlw   0x00

zBLoop1:

    movwf   INDF0
    incf    FSR0L, f

    decfsz  scratch0, f
    goto    zBLoop1

    return

; end of zeroBlock
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; copyBlock
;
; Copies a block of memory from one location to another.
;
; On entry:
;
; WREG = Number of bytes to copy
; FSR0L = first byte address in source block
; FSR1L = first byte address in destination block
; Appropriate bank should already be selected
;

copyBlock:

    ; number of bytes to copy
    movwf   scratch0


    cBLoop1:

        ; pull byte from source
        movf   INDF0, w

        ; put byte into destination
        movwf   INDF1

        ; increment the source and
        ; destination byte positions
        incf    FSR0L, f
        incf    FSR1L, f

        decfsz  scratch0, f
        goto    cBLoop1

    return

; end of copyBlock
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; studentCode
;
; Test area for student's code.
;

studentCode:


    return

; end of studentCode
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; handleInterrupt
;
; All interrupts call this function.  The interrupt flags must be polled to determine which
; interrupts actually need servicing.
;
; Note that after each interrupt type is handled, the interrupt handler returns without checking
; for other types.  If another type has been set, then it will immediately force a new call
; to the interrupt handler so that it will be handled.
;
; NOTE NOTE NOTE
; It is important to use no (or very few) subroutine calls.  The stack is only 16 deep and
; it is very bad for the interrupt routine to use it.
;

handleInterrupt:

	btfsc 	INTCON,T0IF     		; Timer0 overflow interrupt?
	goto 	handleTimer0Interrupt	; YES, so process Timer0

INT_ERROR_LP1:		        		; NO, do error recovery
	;GOTO INT_ERROR_LP1      		; This is the trap if you enter the ISR
                               		; but there were no expected interrupts

	retfie                  ; return and enable interrupts

; end of handleInterrupt
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; handleTimer0Interrupt
;
; This function is called when the Timer 0 register overflows.
;
; The prescaler is set to 1:256.
; 16 Mhz Fosc = 4 Mhz instruction clock (CLKOUT)
; 4,000,000 Hz / 256 = 15,625 Hz;  15,625 Hz / 156 = 100 Hz
; Interrupt needed every 156 counts of TMR0 -- set to 255-156.
;
; Interrupt triggered when 8 bit TMR0 register overflows, so subtract desired number of increments
; between interrupts from 255 for value to store in register.
;
; NOTE NOTE NOTE
; It is important to use no (or very few) subroutine calls.  The stack is only 8 deep and
; it is very bad for the interrupt routine to use it.
;

handleTimer0Interrupt:

	bcf 	INTCON,TMR0IF     ; clear the Timer0 overflow interrupt flag

    ; reload the timer -- see notes in function header

    movlw   (.255 - .156)
    banksel TMR0
    movwf   TMR0

;debug mks -- output a pulse to verify the timer0 period
;    banksel DEBUG_IO_P
;    bsf     DEBUG_IO_P,DEBUG_IO
;    bcf     DEBUG_IO_P,DEBUG_IO
;debug mks end

	retfie                  ; return and enable interrupts

; end of handleTimer0Interrupt
;--------------------------------------------------------------------------------------------------

    END
