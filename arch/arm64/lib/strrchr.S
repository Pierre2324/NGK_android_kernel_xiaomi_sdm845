/*
 * strrchr - find last position of a character in a string.
 *
 * Copyright (c) 2014-2020, Arm Limited.
 * SPDX-License-Identifier: MIT
 */

/* Assumptions:
 *
 * ARMv8-a, AArch64
 * Neon Available.
 */

#include <linux/linkage.h>
#include <asm/assembler.h>

/* Arguments and results.  */
srcin		.req	x0
chrin		.req	w1

result		.req	x0

src			.req	x2
tmp1		.req	x3
wtmp2		.req	w4
tmp3		.req	x5
src_match	.req	x6
src_offset	.req	x7
const_m1	.req	x8
tmp4		.req	x9
nul_match	.req	x10
chr_match	.req	x11

vrepchr		.req	v0
vdata1		.req	v1
vdata2		.req	v2
vhas_nul1	.req	v3
vhas_nul2	.req	v4
vhas_chr1	.req	v5
vhas_chr2	.req	v6
vrepmask_0	.req	v7
vrepmask_c	.req	v16
vend1		.req	v17
vend2		.req	v18

/* Core algorithm.

   For each 32-byte hunk we calculate a 64-bit syndrome value, with
   two bits per byte (LSB is always in bits 0 and 1, for both big
   and little-endian systems).  For each tuple, bit 0 is set iff
   the relevant byte matched the requested character; bit 1 is set
   iff the relevant byte matched the NUL end of string (we trigger
   off bit0 for the special case of looking for NUL).  Since the bits
   in the syndrome reflect exactly the order in which things occur
   in the original string a count_trailing_zeros() operation will
   identify exactly which byte is causing the termination, and why.  */

ENTRY(strrchr)
	/* Magic constant 0x40100401 to allow us to identify which lane
	   matches the requested byte.  Magic constant 0x80200802 used
	   similarly for NUL termination.  */
	mov	wtmp2, #0x0401
	movk	wtmp2, #0x4010, lsl #16
	dup	vrepchr.16b, chrin
	bic	src, srcin, #31		/* Work with aligned 32-byte hunks.  */
	dup	vrepmask_c.4s, wtmp2
	mov	src_offset, #0
	ands	tmp1, srcin, #31
	add	vrepmask_0.4s, vrepmask_c.4s, vrepmask_c.4s /* equiv: lsl #1 */
	b.eq	.Laligned

	/* Input string is not 32-byte aligned.  Rather than forcing
	   the padding bytes to a safe value, we calculate the syndrome
	   for all the bytes, but then mask off those bits of the
	   syndrome that are related to the padding.  */
	ld1	{vdata1.16b, vdata2.16b}, [src], #32
	neg	tmp1, tmp1
	cmeq	vhas_nul1.16b, vdata1.16b, #0
	cmeq	vhas_chr1.16b, vdata1.16b, vrepchr.16b
	cmeq	vhas_nul2.16b, vdata2.16b, #0
	cmeq	vhas_chr2.16b, vdata2.16b, vrepchr.16b
	and	vhas_nul1.16b, vhas_nul1.16b, vrepmask_0.16b
	and	vhas_chr1.16b, vhas_chr1.16b, vrepmask_c.16b
	and	vhas_nul2.16b, vhas_nul2.16b, vrepmask_0.16b
	and	vhas_chr2.16b, vhas_chr2.16b, vrepmask_c.16b
	addp	vhas_nul1.16b, vhas_nul1.16b, vhas_nul2.16b	// 256->128
	addp	vhas_chr1.16b, vhas_chr1.16b, vhas_chr2.16b	// 256->128
	addp	vend1.16b, vhas_nul1.16b, vhas_chr1.16b		// 128->64
	mov	nul_match, vend1.d[0]
	lsl	tmp1, tmp1, #1
	mov	const_m1, #~0
	lsr	tmp3, const_m1, tmp1
	mov	chr_match, vend1.d[1]

	bic	nul_match, nul_match, tmp3	// Mask padding bits.
	bic	chr_match, chr_match, tmp3	// Mask padding bits.
	cbnz	nul_match, .Ltail

	.p2align 4
.Lloop:
	cmp	chr_match, #0
	csel	src_match, src, src_match, ne
	csel	src_offset, chr_match, src_offset, ne
.Laligned:
	ld1	{vdata1.16b, vdata2.16b}, [src], #32
	cmeq	vhas_chr1.16b, vdata1.16b, vrepchr.16b
	cmeq	vhas_chr2.16b, vdata2.16b, vrepchr.16b
	uminp	vend1.16b, vdata1.16b, vdata2.16b
	and	vhas_chr1.16b, vhas_chr1.16b, vrepmask_c.16b
	and	vhas_chr2.16b, vhas_chr2.16b, vrepmask_c.16b
	cmeq	vend1.16b, vend1.16b, 0
	addp	vhas_chr1.16b, vhas_chr1.16b, vhas_chr2.16b	// 256->128
	addp	vend1.16b, vend1.16b, vhas_chr1.16b		// 128->64
	mov	nul_match, vend1.d[0]
	mov	chr_match, vend1.d[1]
	cbz	nul_match, .Lloop

	cmeq	vhas_nul1.16b, vdata1.16b, #0
	cmeq	vhas_nul2.16b, vdata2.16b, #0
	and	vhas_nul1.16b, vhas_nul1.16b, vrepmask_0.16b
	and	vhas_nul2.16b, vhas_nul2.16b, vrepmask_0.16b
	addp	vhas_nul1.16b, vhas_nul1.16b, vhas_nul2.16b
	addp	vhas_nul1.16b, vhas_nul1.16b, vhas_nul1.16b
	mov	nul_match, vhas_nul1.d[0]

.Ltail:
	/* Work out exactly where the string ends.  */
	sub	tmp4, nul_match, #1
	eor	tmp4, tmp4, nul_match
	ands	chr_match, chr_match, tmp4
	/* And pick the values corresponding to the last match.  */
	csel	src_match, src, src_match, ne
	csel	src_offset, chr_match, src_offset, ne

	/* Count down from the top of the syndrome to find the last match.  */
	clz	tmp3, src_offset
	/* Src_match points beyond the word containing the match, so we can
	   simply subtract half the bit-offset into the syndrome.  Because
	   we are counting down, we need to go back one more character.  */
	add	tmp3, tmp3, #2
	sub	result, src_match, tmp3, lsr #1
	/* But if the syndrome shows no match was found, then return NULL.  */
	cmp	src_offset, #0
	csel	result, result, xzr, ne

	ret
ENDPROC(strrchr)
