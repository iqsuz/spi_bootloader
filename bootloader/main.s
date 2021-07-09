
/*
 * main.s
 *
 * Created: 7/7/2021 8:21:28 PM
 *  Author: mehme
 */ 

#include "inc/io.h"

.global main

.equ hfuse, 0x0100

.equ bootsz0_bit_no, 1
.equ bootsz1_bit_no, 2
.equ bootsz_filter, (1 << bootsz0_bit_no) | (1 << bootsz1_bit_no)
.equ bootsz_256w, 6
.equ bootsz_512w, 4
.equ bootsz_1024w, 2
.equ bootsz_2048w, 0

.equ desired_boot_size, bootsz_2048w



;.section text
	main:
		/*Reading FUSE_HIGH
			Set Z = 0x0003,
			Set BLBSET and SELFPRGEN in SMPCSR
			Read Z register within 3 cycles with LPM. So disable interrupts first.
		*/
		cli	;Disable interrupts
		ldi r30, 0x03	;Set Z = 0x0003
		ldi r31, 0x00
		ldi r16, (1<<BLBSET) | (1<<SELFPRGEN)	;Set BLBSET = 1, SELFPRGEN = 1
		out _SFR_IO_ADDR(SPMCSR), r16	;Write BLBSET and SELFPRGEN to SPMCSR
		lpm r17, Z
		;sei	;Enable interrupts

		sts hfuse, r17	;Store FUSE_HIGH in SRAM
		
		/*Is bootsize large enough?*/
		andi r17, bootsz_filter
		cpi r17, desired_boot_size
		brne not_desired_bootsize	;Branch if it is not large enough.

		;Erase the page of 0x00
		ldi ZL, 0x00
		ldi ZH, 0x00
		call erase_page

		call wait_for_spm	;Wait SPM command to be executed.

		/*Load buffer with data*/
		ldi ZL, 0x00
		ldi ZH, 0x00
		ldi r18, 0x0C
		ldi r19, 0x94
		movw r18,r0
		ldi r16, 0x01
		out _SFR_IO_ADDR(SPMCSR), r16
		spm

		
		/*Clear the RWWSB bit
		ldi r16, 0x01
		out _SFR_IO_ADDR(SPMCSR), r16
		spm*/

		;Write page
		ldi ZL, 0x00
		ldi ZH, 0x00
		ldi r16, 0x05
		out _SFR_IO_ADDR(SPMCSR), r16
		spm

		nop
		nop
		nop

	;This subroutine waits until SPMEN bit in SPMCSR is cleared.
	;It uses r16, so it should be pushed to stack before run through.
	wait_for_spm:
		push r16
		.loop:
			in r16, _SFR_IO_ADDR(SPMCSR)
			sbrc r16, SPMEN
			rjmp .loop
		pop 16
		ret

	;This subroutine erase the entire page pointed on Z register PCPAGE segment.
	;Z register bits are segmented as follows.
	;PCWORD = Z6:Z1
	;PCPAGE = Z14:Z7
	;Z0, Z15 are "don't care" bits.
	;Before calling this subroutine Z register must be arranged.
	;This subroutine uses r16, so it should be pushed to stack before run through.
	erase_page:
		push r17
		ldi r17, (1 << PGERS) | (1 << SPMEN)
		out _SFR_IO_ADDR(SPMCSR), r16
		spm
		pop r17
		ret

	not_desired_bootsize:
		nop
		nop
