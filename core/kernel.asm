; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

; Memory layout and general support for TinyCore device drivers.

            .cpu    "w65c02"
            
;reserved   = $0000     ; $00 - $02
;basic      = $0002     ; $02 - $90
*           = $0090     ; $90 - $fb kernel
*           = $00a3     ; $90 - $fb kernel
            .dsection   dp
            .cerror * >= $00fb, "Out of dp space."

Stack       = $0100
Page2       = $0200     ; BASIC, some KERNAL
Page3       = $0300     ; BASIC

*           = $0400     ; KERNEL    ; TODO: 200, fill 59, ramtas
KMEM        .dsection   kmem 
            .cerror * > $04ff, "Out of kmem space."

*           = $0500     ; Device table (borrowed from the TinyCore kernel)
            .dsection   kbuf
            .align      256
            .dsection   kpages
            .fill       256     ; BASIC...
free_mem



; $e000 - $e500 contains a simple command line shell which may be
; used to load applications in the absence of either CBM BASIC or
; a more general ROM.  If CBM BASIC is bundled, it will overwrite
; this section of the kernel. 

*           = $e000
            .dsection   cli
            .cerror * > $e4ff, "Out of cli space."

; Start of the kernel proper, pushed back to accomodate the use of
; CBM BASIC.
*           = $e500
            .dsection   tables
            .dsection   kernel
            .cerror * > $feff, "Out of kernel space."

*           = $ff81
kernel      .namespace
            .dstruct    vectors            
            .endn

            .section    kpages
frame
Devices     .fill       256
DevState    .fill       256
Tokens      .fill       256
            
;            .fill       256     ; Something goes wonky otherwise...
            .send            

            .namespace  kernel

            .section    dp
tmp_x       .byte   ?
tmp2        .byte   ?
ticks       .word   ?
src         .word   ?   ; src ptr for copy operations.
            .send


            .section    dp
mem_start   .word       ?
mem_end     .word       ?
msg_switch  .byte       ?
iec_timeout .byte       ?
current_dev .byte       ?
input       .byte       ?
            .send

            .section    cli
            .byte   0
            .send          

            .section    kernel
            


thread      .namespace  ; For devices borrowed from the TinyCore kernel.
yield       wai
            rts
            .endn

init
      ; Initialize device driver services.
        jsr     token.init
        jsr     device.init
        jsr     keyboard.init
        rts

tick
        inc     kernel.ticks
        bne     _end
        inc     kernel.ticks+1
_end    rts

error
        lda     #<_msg
        sta     src
        lda     #>_msg
        sta     src+1
        ldy     #0
_loop   lda     (src),y
        beq     _done
        jsr     platform.console.putc
        iny
        bra     _loop
_done   jmp     wreset       
_msg    .null   "Error"


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CBM stuff below ... move to another file.

basic = $a000

start       
  stz   input
        
  lda #2
  sta $1
  
            jsr     ramtas
            jsr     restor
            jsr     SCINIT
            jsr     IOINIT
            jmp     (basic)


vectors     .struct
SCINIT      jmp     scinit
IOINIT      jmp     io.ioinit
RAMTAS      jmp     ramtas
RESTOR      jmp     restor
VECTOR      jmp     vector
SETMSG      jmp     setmsg
LSTNSA      jmp     lstnsa
TALKSA      jmp     talksa
MEMBOT      jmp     membot
MEMTOP      jmp     memtop
SCNKEY      jmp     scnkey
SETTMO      jmp     settmo
IECIN       jmp     iecin
IECOUT      jmp     iecout
UNTALK      jmp     untalk
UNLSTN      jmp     unlstn
LISTEN      jmp     listen
TALK        jmp     talk
READST      jmp     io.readst
SETLFS      jmp     io.setlfs
SETNAM      jmp     io.setnam
OPEN        jmp     io.open
CLOSE       jmp     io.close
CHKIN       jmp     io.chkin
CHKOUT      jmp     io.chkout
CLRCHN      jmp     io.clrchn
CHRIN       jmp     chrin
CHROUT      jmp     chrout
LOAD        jmp     io.load
SAVE        jmp     io.save
SETTIM      jmp     settim
RDTIM       jmp     rdtim
STOP        jmp     stop
GETIN       jmp     io.getin
CLALL       jmp     io.clall
UDTIM       jmp     udtim
SCREEN      jmp     screen
PLOT        jmp     plot
IOBASE      jmp     iobase
            .ends


            

ivec_start
            .word   irq
            .word   break
            .word   nmi
            .word   io.open     
            .word   io.close
            .word   io.chkin
            .word   io.chkout
            .word   io.clrchn
            .word   chrin
            .word   chrout
            .word   stop
            .word   io.getin
            .word   io.clall
            .word   user
            .word   io.load
            .word   io.save
ivec_end
ivec_size   =   ivec_end - ivec_start



chrin       jsr     io.chrin
chrout      jmp     io.chrout





            
            .send
            .endn
