/* Stage 1 Boot process, this is what is first run before going onto stage1 */

/* start in IO space */
.section stage1_code,"x"
/* NOTHING CAN COME between this and the org directive! */
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

.align 6
system_address_table:

.align 6
prcb_ptr:

.align 6
sys_proc_table:

.align 6
fault_proc_table:

