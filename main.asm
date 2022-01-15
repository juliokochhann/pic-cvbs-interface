;===============================================================================
;____| PROJECT DESCRIPTION |____________________________________________________    
; Name: CVBS PAL-M (Brazil standard) Test Program
;
; Description: Draws a line that can be moved up and down with two buttons
;
; MCU: PIC16F628A     FOSC: 4 MHz (HS)     TOSC: 1 us
;
; Author: Julio Cesar Kochhann
;                                                                              
; Date: 14.01.2021
;                                                                              
;===============================================================================
;____| RELEASE DATE |__________| VERSION |__________| DEVICE ID |_______________
;       DD.MM.AAAA                 1.0                 H'FFFF'
;
;===============================================================================
;____| WISHLIST |_______________________________________________________________
; 1. New features go here
;
;===============================================================================
;____| KNOWN BUGS |_____________________________________________________________
; 1. Problems that need to be fixed go here
;
;===============================================================================


;===============================================================================
;____| Processor List |_________________________________________________________
    list    P=16F84A


;===============================================================================
;____| Definitions File |_______________________________________________________
    include <p16f84a.inc>


;===============================================================================
;____| Fuse Bits Configuration |________________________________________________
    __CONFIG _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _CP_OFF     ; __config 0xFFF2


;===============================================================================
;____| Memory Pagination |______________________________________________________
    #define bank0       bcf     STATUS,RP0      ; Switch to RAM Bank 0
    #define bank1       bsf     STATUS,RP0      ; Switch to RAM Bank 1


;===============================================================================
;____| Global Variables |_______________________________________________________
    cblock  H'20'               ; General Purpose Registers (GPR) start address

        W_TEMP                  ; Temporary registers for context saving
        STATUS_TEMP

        flags1
        num_iter
        line_counter
        btn_counter

    endc


;===============================================================================
;____| Flags |__________________________________________________________________
    #define FRAME_END       flags1, 0           ; Define FRAME_END at bit 0 of flags1
    #define FIELD_SELECT    flags1, 1
    #define INC_FLAG        flags1, 2
    #define DEC_FLAG        flags1, 3


;===============================================================================
;____| Constants |______________________________________________________________
Black       equ         1
Gray        equ         2
White       equ         3


;===============================================================================
;____| Hardware Mapping |_______________________________________________________
; Inputs
    #define BTN_INC     PORTA,2         ; Increment button at RA2
                                        ; 0 -> Button pressed
                                        ; 1 -> Button released

    #define BTN_DEC     PORTA,3         ; Decrement button at RA3
                                        ; 0 -> Button pressed
                                        ; 1 -> Button released

; Outputs
    #define VIDEO       PORTB           ; Composite video (CVBS) port


;===============================================================================
;____| Reset Vector |___________________________________________________________
    org     H'0000'                     ; Program start address
    goto    main                        ; Jumps to label 'main'


;===============================================================================
;____| Interrupt Vector |_______________________________________________________
; Context saving
    org     H'0004'                     ; Interrupt start address

    movwf   W_TEMP
    swapf   STATUS,W
    movwf   STATUS_TEMP

; Interrupt service routine body
    nop

; Restore context
exit_ISR:
    swapf   STATUS_TEMP,W
    movwf   STATUS
    swapf   W_TEMP,F
    swapf   W_TEMP,W
    
    retfie                              ; Return from interrupt


;===============================================================================
;____| Macros |_________________________________________________________________

black_color: macro
    movlw   black_color                 ; Black color level on video port
    movwf   video                       ; Move data to video port

    endm

gray_color: macro
    movlw   Gray                        ; Gray color level on video port
    movwf   VIDEO

    endm
    
white_color: macro
    movlw   White                       ; White color level on video port
    movwf   VIDEO

    endm
    
delay2: macro                           ; Delay (2 Tosc)
    goto    $+1

    endm
    
delay_cycles: macro                     ; Delay 3 Tosc * W
    movwf   num_iter
    
    decfsz  num_iter, f
    goto    $-1
    
    endm

horizontal_sync: macro                  ; Horizontal Sync: 4 us
    clrf    VIDEO                       ; H_Sync level on video port
    
    delay2                              ; 1-2
    
    black_color                         ; 3-4
    
    endm
    
short_sync: macro                       ; Vertical short sync: 2 us
    clrf    VIDEO
    
    black_color                         ; 1-2
    
    movlw   D'9'                        ; 3
    delay_cycles                        ; 4-30 (Delay 27 us)
    nop                                 ; 31
    
    endm
    
long_sync: macro                        ; Vertical long sync: 30 us
    clrf    VIDEO
    
    movlw   D'9'                        ; 1
    delay_cycles                        ; 2-28 (Delay 27 us)
    
    black_color                         ; 29-30
    
    nop                                 ; 31
    
    endm

empty_line: macro
    horizontal_sync                     ; 1-4

    movlw   D'19'                       ; 5
    delay_cycles                        ; 6-62 (Delay 57 us)
    nop                                 ; 63

    endm


;===============================================================================
;____| Program Entry Point |____________________________________________________

main:
    bank0                               ; Switch to RAM bank 0
    
    clrw                                ; Clears accumulator (W)
    movwf   PORTB                       ; Move W to PORTB file (register)
    
    bank1                               ; Switch to RAM bank 1
    
    movlw   B'11111111'                 ; Move H'FF' to Work (W)
    movwf   TRISA                       ; Define all PORTA IOs as inputs
    movlw   B'11111100'                 ;
    movwf   TRISB                       ; RB0 and RB1 as outputs

    movlw   B'11000000'                 ;
    movwf   OPTION_REG                  ; Define operation options

    movlw   B'00000000'                 ;
    movwf   INTCON                      ; Define interrupt options
    
    bank0                               ; Return to bank 0

; Global variables initialization
    clrf        flags1
    clrf        line_counter

    movlw       D'1'
    movwf       btn_counter


;===============================================================================
;____| Loop Routine |___________________________________________________________

; Field 1 (Odd lines)
field1:
    ;--- 6 Pre-equalizing pulses ---  
    short_sync
    short_sync
    short_sync
    short_sync
    short_sync
    short_sync
    
    ;--- 5 long sync pulses ---
    long_sync
    long_sync
    long_sync
    long_sync
    long_sync
    
    ;--- 5 Post-equalizing pulses ---
    short_sync
    short_sync
    short_sync
    short_sync
    
    clrf    VIDEO
                                        ; Cycle count
    black_color                         ; 1-2
    
    movlw   D'8'                        ; 3
    
    delay_cycles                        ; 4-27 (Delay 24 us)

    bcf     FRAME_END                   ; 28
    
    bsf     FIELD_SELECT                ; 29

    goto frame                          ; 30-31

; Field 2 (Even lines)
field2:
    bcf     FRAME_END
    
    ;--- 5 Pre-equalizing pulses ---
    short_sync
    short_sync
    short_sync
    short_sync
    short_sync
    
    ;--- 5 long sync pulses ---
    long_sync
    long_sync
    long_sync
    long_sync
    long_sync
    
    ;--- 4 Post-equalizing pulses ---
    short_sync
    short_sync
    short_sync
    
    clrf    VIDEO
                                        ; Cycle count
    black_color                         ; 1-2
    
    movlw   D'5'                        ; 3
    delay_cycles                        ; 4-18 (Delay 15 us)

    ;--- Read increment button ---
    btfsc   BTN_INC                     ; 19 | 19-20
    goto    inc_release                 ; 20-21

inc_press:
    bsf     INC_FLAG                    ; 21
    nop                                 ; 22
    goto    $+4                         ; 23-24

inc_release:
    btfsc   INC_FLAG                    ; 22 | 22-23
    incf    btn_counter, f              ; 23

    bcf     INC_FLAG                    ; 24

    ;--- Read decrement button ---
    btfsc   BTN_DEC                     ; 25 | 25-26
    goto    dec_release                 ; 26-27

dec_press:
    bsf     DEC_FLAG                    ; 27
    nop                                 ; 28
    goto    $+4                         ; 29-30

dec_release:
    btfsc   DEC_FLAG                    ; 28 | 28-29
    decf    btn_counter, f              ; 29

    bcf     DEC_FLAG                    ; 30
    
    bcf     FIELD_SELECT                ; 31

frame:
    horizontal_sync                     ; 1-4 Horizontal sync: 4 us
    
    ;--- Back porch: 8 us ---
    incf    line_counter, f             ; 5

    movfw   line_counter                ; 6
    sublw   H'FF'                       ; 7 Compares line_counter to 255
    
    btfsc   STATUS, Z                   ; 8 | 8-9
    bsf     FRAME_END                   ; 9

    nop                                 ; 10

    movfw   btn_counter                 ; 11
    subwf   line_counter, w             ; 12 (btn_counter - line_counter) -> W
    
    ;--- Visible area: 52 us ---
    btfss   STATUS, Z                   ; 13 | 13-14
    goto    blank                       ; 14-15

line:
    white_color                         ; 15-16

    movlw   D'11'                       ; 17
    delay_cycles                        ; 18-50 (Delay 33 us)

    nop                                 ; 51

    goto    stream_end                  ; 52-53

blank:
    movlw   D'12'                       ; 16
    delay_cycles                        ; 17-52 (Delay 36 us)

    nop                                 ; 53
    
stream_end:    
    btfsc   FRAME_END                   ; 54 | 54-55
    goto    switch_field                ; 55-56
    
continue_frame:
    nop                                 ; 56

    black_color                         ; 57-58

    nop                                 ; 59
    delay2                              ; 60-61

    goto    frame                       ; 62-63
    
switch_field:    
    black_color                         ; 57-58

    clrf    line_counter                ; 59
    
    btfsc   FIELD_SELECT                ; 60 | 60-61
    goto    field2                      ; 61-62 Field 2 Vertical Sync | Frame lines: 262
    goto    field1                      ; 62-63 Field 1 Vertical Sync | Frame lines: 263


;===============================================================================
;____| Routines |_______________________________________________________________


;===============================================================================
;____| Program Exit Point |_____________________________________________________

    end
