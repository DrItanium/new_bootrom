/* initial boot setup */
.section boot_words /* this will be at address zero encoded in to the 2560 itself */
    .word system_address_table # SAT pointer
    .word prcb_ptr # prcb pointer
    .word 0
    .word stage1_entry # pointer to first ip
	.word cs1 # calculated at link time (bind ?cs1 (- (+ ?SAT ?PRCB ?startIP)))
    .word 0
    .word 0
    .word -1
/* start in IO space */

.section stage1_code,"x"
stage1_entry:
	mov g0, g0
	
/* the structures here include

   - The code which pulls the processor out of interrupt context and then jumps off to stage 2
   - The system address table
   - The initial PRCB
   - A minimal fault handler
   - Initial system call table
   - The interrupt table
*/

.section stage1_sat
.align 6
system_address_table:

.section stage1_prcb
.align 6
prcb_ptr:

.section stage1_sys_proc
.align 6
sys_proc_table:

.section stage1_fault_proc
.align 6
fault_proc_table:

.text
.align 6
interpreter_entry:
