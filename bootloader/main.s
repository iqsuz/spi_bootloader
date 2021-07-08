
/*
 * main.s
 *
 * Created: 7/7/2021 8:21:28 PM
 *  Author: mehme
 */ 

#include "inc/io.h"

.global main


;.section text
	main:
		ldi r30, 0x03
		ldi r31, 0x00
		ldi r16, (1<<BLBSET) | (1<<SELFPRGEN)
		out _SFR_IO_ADDR(SPMCSR), r16
		LPM


