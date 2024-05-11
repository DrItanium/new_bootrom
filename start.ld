GROUP(-lgcc -lm -lc -liberty -lc -lmon960) /* libraries to link in */

MEMORY /* describe the partitioning of the memory space for the application */ 
{
	boot (!r) : ORIGIN = 0, l = 32,
	sram(!rw) : ORIGIN = 0xFE100000, l = 4K, /* This can be easily expanded but we will work with this for now */
	code(!r) : ORIGIN = 0xFE800000, l = 128K,
}

/* A tiny 256 byte stack for now */
STACK_SIZE = 256; 

/* Layout the different ELF sections into memory using the above described
 * memory spaces */ 
SECTIONS
{
	.boot_words : {
		*(.boot_words) /* place the actual boot words here */
	} >boot
	.text : {
		.*(stage1_code)
		.*(stage1_sat)
		.*(stage1_sys_proc)
		.*(stage1_fault_proc)
		.*(.text) 
		_etext = .; 
	} >code
	.bss : 
	{ 
		__bss_start__ = .;
		_bss_start = .;
		*(.bss) 
		__bss_end__ = .; 
	} >sram
	.data :
	{
		KEEP(*(.data)) 
		_edata = .; 
	} >sram
}

cs1 = -(ABSOLUTE(system_address_table) + ABSOLUTE(prcb_ptr) + ABSOLUTE(start_ip)) ;

