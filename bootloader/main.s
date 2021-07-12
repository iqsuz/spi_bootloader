/*
 * main.s
 *
 * SPI Bootloader for Atmega328p
 *
 * Created: 7/7/2021 8:21:28 PM
 * Author: M. Ali Ipsuz
 * Toolchain: AVR-GCC
 */ 

#include "inc/io.h"

.global main

;.equ hfuse, 0x0100

.equ bootsz0_bit_no, 1
.equ bootsz1_bit_no, 2
.equ bootsz_filter, (1 << bootsz0_bit_no) | (1 << bootsz1_bit_no)
.equ bootsz_256w, 6
.equ bootsz_512w, 4
.equ bootsz_1024w, 2
.equ bootsz_2048w, 0

.set dd_mosi, 3
.set dd_sck, 5
.set ss_line, 2

.set handshake_pin, 7
.set handshake_port, PORTD


.equ desired_boot_size, bootsz_2048w

.section .data
	page_inf:
		.word 1

	hfuse:
		.byte 1

.section .text
	main:
		;Reading FUSE_HIGH
		;Set Z = 0x0003,
		;Set BLBSET and SELFPRGEN in SMPCSR
		;Read Z register within 3 cycles with LPM. So disable interrupts first.
		cli	;Disable interrupts
		ldi r30, 0x03	;Set Z = 0x0003
		ldi r31, 0x00
		ldi r16, (1<<BLBSET) | (1<<SELFPRGEN)	;Set BLBSET = 1, SELFPRGEN = 1
		out _SFR_IO_ADDR(SPMCSR), r16	;Write BLBSET and SELFPRGEN to SPMCSR
		lpm r17, Z
		;sei	;Enable interrupts

		sts hfuse, r17	;Store FUSE_HIGH in SRAM
		
		;Is bootsize large enough?
		andi r17, bootsz_filter
		cpi r17, desired_boot_size
		;brne not_desired_bootsize	;Branch if it is not large enough.

		call init_spi
		call init_handshake

		call ss_low

		ldi r16, 0x27
		call set_page


		;Erase the page of 0x00
		ldi ZL, 0x00
		ldi ZH, 0x00
		call erase_page
	
		call wait_for_spm	;Wait SPM command to be executed.

		;Load buffer with data
		ldi ZL, 0x00
		ldi ZH, 0x00
		ldi r18, 0x0C
		ldi r19, 0x94
		call load_page_buffer

		
		/*Clear the RWWSB bit
		ldi r16, 0x01
		out _SFR_IO_ADDR(SPMCSR), r16
		spm*/

		;Write page
		ldi ZL, 0x00
		ldi ZH, 0x00
		call write_page



	wait_for_spm:
		;This subroutine waits until SPMEN bit in SPMCSR is cleared.
		;It uses r16, so it should be pushed to stack before run through.
		push r16
		.loop:
			in r16, _SFR_IO_ADDR(SPMCSR)
			sbrc r16, SPMEN
			rjmp .loop
		pop 16
		ret


	erase_page:
		;This subroutine erase the entire page pointed on Z register PCPAGE segment.
		;Z register bits are segmented as follows.
		;PCWORD = Z6:Z1
		;PCPAGE = Z14:Z7
		;Z0, Z15 are "don't care" bits.
		;Before calling this subroutine Z register must be arranged.
		;This subroutine uses r16, so it should be pushed to stack before run through.
		push r17
		ldi r17, (1 << PGERS) | (1 << SPMEN)	;0x03
		out _SFR_IO_ADDR(SPMCSR), r17
		spm
		pop r17
		ret


	load_page_buffer:
		;This subroutine loads a word data to page buffer (special memory space for self programming).
		;It writes data based on Z register PCWORD segment. Whichever address is chosen in Z register, it will write there.
		;For instance: if Z register LSB is x000 011x, it will start writing word data to 0x60 in buffer.
		;Before calling this subroutine Z register must be arranged. 
		;Also the word data which will be write to buffer should be placed in r18 and r19
		;This subroutine uses r0, r1, r18, so these should be pushed to stack before run through.
		push r0
		push r1
		push r16

		movw r0, r18
		ldi r16, (1 << SPMEN)
		out _SFR_IO_ADDR(SPMCSR), r16
		spm

		pop r16
		pop r1
		pop r0
		ret


	write_page:
		;This subroutine writes buffered data (in special memory space) to program memory. 
		;***This subroutine writes entire buffered page to program memory.
		;It starts writing data to program address based on Z register PCPAGE segment.
		;PCPAGE = Z14:Z7
		push r16

		ldi r16, (1 << PGWRT) | (1 << SPMEN)
		out _SFR_IO_ADDR(SPMCSR), r16
		spm

		pop r16
		ret


	init_spi:
		;This subroutine initializes SPI module along with related pins.
		;MOSI --> PB3, SCK --> PB5, SS --> PB2
		;Master, MSB, FCLK/2
		push r16

		;This code block init the MOSI and SCK as output.
		ldi r16, (1 << dd_mosi) | (1 << dd_sck) | (1 << ss_line)
		out _SFR_IO_ADDR(DDRB), r16

		;This code block init the SPI unit as master, MSB and FCLK/2.
		ldi r16, (1 << SPE) | (1 << MSTR)
		out _SFR_IO_ADDR(SPCR), r16
		ldi r16, (1 << SPI2X)
		out _SFR_IO_ADDR(SPSR), r16

		pop r16
		ret
	
	init_handshake:
		;This subroutine initializes handshake pin as an input pin.
		;For more information please refer to Handshake protocol presentaion file.
		;Handshake Pin -- > Port D7 
		push r18

		ldi r18, (1 << handshake_pin)
		out _SFR_IO_ADDR(DDRD), r18

		pop r18
		ret
	
	ss_low:
		;Set SS Pin low.
		cbi _SFR_IO_ADDR(handshake_port), handshake_pin
		ret

	ss_high:
		;Set SS Pin high.
		sbi _SFR_IO_ADDR(handshake_port), handshake_pin
		ret

	set_page:
		push r17
		push r20
		push r21

		ldi r20, 0x00
		ldi r21, 0x06
		
		ldi r17, 0x00
		
		rjmp .L1

	.L2:
		lsl r16
		rol r17
		inc r20

	.L1:
		cp r20, r21
		brlo .L2

		sts page_inf, r16
		sts page_inf+1, r17

		pop r21
		pop r20
		pop r17
		ret


	not_desired_bootsize:
		nop
