/* Stage 1 Boot process, this is what is first run before going onto stage1 */

.org 0x00000000
    .word system_address_table # SAT pointer
    .word prcb_ptr # prcb pointer
    .word 0
    .word stage1_entry # pointer to first ip
    .word cs1 # calculated at link time (bind ?cs1 (- (+ ?SAT ?PRCB ?startIP)))
    .word 0
    .word 0
    .word -1
/* start in IO space */
.org 0xFE400000
.text
/* NOTHING CAN COME between this and the org directive! */
stage1_entry:
	
/* the structures here include

   - The code which pulls the processor out of interrupt context and then jumps off to stage 2
   - The system address table
   - The initial PRCB
   - A minimal fault handler
   - Initial system call table
   - The interrupt table
*/

.org 0xFE404000 /* all of the data tables start at 16k */
.align 6
system_address_table:

.org 0xFE405000 /* each table then has a 4k offset from the previous one */
.align 6
prcb_ptr:

.org 0xFE406000 
.align 6
sys_proc_table:

.org 0xFE407000
.align 6
fault_proc_table:



.org 0xFE40F000 /* constants */
interpreter_passoff_address:
	.word 0xFE800000

