/* this is the information that get's the i960 booting, it will be located at
 * address zero to start!
 * 
 * The 2560 will be at the lowest part of memory
 */
.text
    .word system_address_table # SAT pointer
    .word prcb_ptr # prcb pointer
    .word 0
    .word stage0_entry # pointer to first ip
	.word cs1 # calculated at link time (bind ?cs1 (- (+ ?SAT ?PRCB ?startIP)))
    .word 0
    .word 0
    .word -1

.set stage1_base_address, 0xFE400000
.set stage1_code_base_address, 0xFE400000
.set stage1
.set stage1_prcb_ptr, 0xFE40
stage1_handoff_iac:
	

stage0_entry:
	mov g0, g0

.align 6
system_address_table: // have a simple sat pointer!

