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

.set dd_mosi, 3
.set dd_sck, 5
.set ss_line, 2

.set handshake_pin, 7
.set handshake_port, PORTD
.set handshake_port_dir, DDRD
.set handshake_port_pin, PIND


.section .data
	hs_pin_state:
		.byte 1

	page_inf:
		.word 1

	hfuse:
		.byte 1

.section .text
	main:
		ldi r16, 0x0 
		sts hs_pin_state, r16

		call enable_pud
		call init_handshake
		call init_spi
		call read_handshake






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
		;This subroutine uses r17, so it should be pushed to stack before run through.
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
		cbi _SFR_IO_ADDR(handshake_port_dir), 7
		sbi _SFR_IO_ADDR(handshake_port), 7
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
		;This subroutine set page address with given r16 register.
		;Subroutine uses r17, r20, r21 so these should be pushed to stack.
		push r17
		push r20
		push r21

		ldi r20, 0x00	;loop initial value.
		ldi r21, 0x07	;loop final value.
		
		ldi r17, 0x00	;given value will be shifted to r17.
		
		rjmp .L1

	.L2:
		lsl r16	;shift to left.
		rol r17	;shift r17 with carry bit.
		inc r20	;increment loop index.

	.L1:
		cp r20, r21	;compare loop index with final
		brlo .L2	;branch .L2 if final index hasn't been reached yet.

		sts page_inf, r16
		sts page_inf+1, r17	

		pop r21
		pop r20
		pop r17
		ret

	set_word:
		push r17

		lds r17, page_inf
		andi r17, 0x80
		lsl r16
		andi r16, 0x7E
		or r16, r17

		sts page_inf, r16

		pop r17
		ret

	enable_pud:
		;This subroutine enables pull up resistor for all ports when they are set as input.
		push r16

		in r16, _SFR_IO_ADDR(MCUCR)
		andi r16, 0xEF
		out _SFR_IO_ADDR(MCUCR), r16

		pop r16
		ret

	read_handshake:
		;This subroutine read handshake input pin state.
		;If state is low, it writes hs_pin_state variable with 0x00, if state is high, it writes hs_pin_state variable with 0x01
		push r17
		
		in r17, _SFR_IO_ADDR(handshake_port_pin)
		andi r17, 0x80
		cpi r17, 0x80
		breq .state_high
		ldi r17, 0x00
		sts hs_pin_state, r17
		rjmp .state_low	

		.state_high:
			ldi r17, 0x01
			sts hs_pin_state, r17
		.state_low:
		
		pop r17
		ret
