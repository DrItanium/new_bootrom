/* initial boot setup */
.global system_address_table
.global prcb_ptr
.global start_ip
.section boot_words, "a" /* this will be at address zero encoded in to the 2560 itself */
    .word system_address_table # SAT pointer
    .word prcb_ptr # prcb pointer
    .word 0
    .word start_ip # pointer to first ip
	.word cs1 # calculated at link time (bind ?cs1 (- (+ ?SAT ?PRCB ?startIP)))
    .word 0
    .word 0
    .word -1
/* start in IO space */

.section stage1_code,"x"
start_ip:
	mov 0, g14 
	
	ldconst 0xff000010, g5
	ldconst .Ljump_to_interpreter_iac, g6
	synmovq g5, g6
	.align 4
.Ljump_to_interpreter_iac:
	.word 0x93000000 /* reinitialize iac message */
	.word system_address_table
	.word _prcb_ram
	.word interpreter_entry

.section stage1_sat, "a"
.align 6
system_address_table:
	.word 0

.section stage1_prcb, "a"
.align 6
prcb_ptr:
	.word 0

.section stage1_sys_proc, "a"
.align 6
sys_proc_table:
	.word 0

.section stage1_fault_proc, "a"
.align 6
fault_proc_table:
	.word 0

.text
.align 6
interpreter_entry:
	mov g0, g0

.bss _user_stack, 256, 6
.bss _intr_stack , 256, 6
.bss _sup_stack, 256, 6
.bss _intr_ram, 1028, 6
.bss _prcb_ram, 176, 6
