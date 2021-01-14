/* memcmp - compare memory
 *
 * Copyright (c) 2013, Arm Limited.
 * SPDX-License-Identifier: MIT
 */

/* Assumptions:
 *
 * ARMv8-a, AArch64, unaligned accesses.
 */

#include <linux/linkage.h>
#include <asm/assembler.h>

/* Parameters and result.  */
src1		.req	x0
src2		.req	x1
limit		.req	x2
result		.req	w0

/* Internal variables.  */
data1		.req	x3
data1w		.req	w3
data1h		.req	x4
data2		.req	x5
data2w		.req	w5
data2h		.req	x6
tmp1		.req	x7
tmp2		.req	x8

ENTRY(memcmp)
	subs	limit, limit, 8
	b.lo	Lless8

	ldr	data1, [src1], 8
	ldr	data2, [src2], 8
	cmp	data1, data2
	b.ne	Lreturn

	subs	limit, limit, 8
	b.gt	Lmore16

	ldr	data1, [src1, limit]
	ldr	data2, [src2, limit]
	b	Lreturn

Lmore16:
	ldr	data1, [src1], 8
	ldr	data2, [src2], 8
	cmp	data1, data2
	bne	Lreturn

	/* Jump directly to comparing the last 16 bytes for 32 byte (or less)
	   strings.  */
	subs	limit, limit, 16
	b.ls	Llast_bytes

	/* We overlap loads between 0-32 bytes at either side of SRC1 when we
	   try to align, so limit it only to strings larger than 128 bytes.  */
	cmp	limit, 96
	b.ls	Lloop16

	/* Align src1 and adjust src2 with bytes not yet done.  */
	and	tmp1, src1, 15
	add	limit, limit, tmp1
	sub	src1, src1, tmp1
	sub	src2, src2, tmp1

	/* Loop performing 16 bytes per iteration using aligned src1.
	   Limit is pre-decremented by 16 and must be larger than zero.
	   Exit if <= 16 bytes left to do or if the data is not equal.  */
	.p2align 4
Lloop16:
	ldp	data1, data1h, [src1], 16
	ldp	data2, data2h, [src2], 16
	subs	limit, limit, 16
	ccmp	data1, data2, 0, hi
	ccmp	data1h, data2h, 0, eq
	b.eq	Lloop16

	cmp	data1, data2
	bne	Lreturn
	mov	data1, data1h
	mov	data2, data2h
	cmp	data1, data2
	bne	Lreturn

	/* Compare last 1-16 bytes using unaligned access.  */
Llast_bytes:
	add	src1, src1, limit
	add	src2, src2, limit
	ldp	data1, data1h, [src1]
	ldp	data2, data2h, [src2]
	cmp     data1, data2
	bne	Lreturn
	mov	data1, data1h
	mov	data2, data2h
	cmp	data1, data2

	/* Compare data bytes and set return value to 0, -1 or 1.  */
Lreturn:
CPU_LE( rev	data1, data1 )
CPU_LE( rev	data2, data2 )
	cmp     data1, data2
Lret_eq:
	cset	result, ne
	cneg	result, result, lo
	ret

	.p2align 4
	/* Compare up to 8 bytes.  Limit is [-8..-1].  */
Lless8:
	adds	limit, limit, 4
	b.lo	Lless4
	ldr	data1w, [src1], 4
	ldr	data2w, [src2], 4
	cmp	data1w, data2w
	b.ne	Lreturn
	sub	limit, limit, 4
Lless4:
	adds	limit, limit, 4
	beq	Lret_eq
Lbyte_loop:
	ldrb	data1w, [src1], 1
	ldrb	data2w, [src2], 1
	subs	limit, limit, 1
	ccmp	data1w, data2w, 0, ne	/* NZCV = 0b0000.  */
	b.eq	Lbyte_loop
	sub	result, data1w, data2w
	ret

ENDPIPROC(memcmp)
