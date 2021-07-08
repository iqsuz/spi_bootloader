/*
 * SPI Bootloader for Atmega328p
 *
 * Created: 7/7/2021 8:21:28 PM
 * Author: M. Ali Ipsuz
 * Toolchain: AVR-GCC
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
		cli
		ldi r30, 0x03	;Set Z = 0x0003
		ldi r31, 0x00
		ldi r16, (1<<BLBSET) | (1<<SELFPRGEN)	;Set BLBSET = 1, SELFPRGEN = 1
		out _SFR_IO_ADDR(SPMCSR), r16	;Write BLBSET and SELFPRGEN to SPMCSR
		lpm r17, Z
		sei

		sts hfuse, r17
		andi r17, bootsz_filter
		cpi r17, desired_boot_size

	error:
		




