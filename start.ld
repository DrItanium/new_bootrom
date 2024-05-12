GROUP(-lgcc -lm -lc -liberty -lc -lmon960) /* libraries to link in */

MEMORY /* describe the partitioning of the memory space for the application */ 
{
	boot (!r) : ORIGIN = 0, l = 32,
	sram(!rw) : ORIGIN = 0xFE100000, l = 4K, /* This can be easily expanded but we will work with this for now */
	code(!r) : ORIGIN = 0xFE800000, l = 128K

}

/* A tiny 256 byte stack for now */
STACK_SIZE = 256; 

/* Layout the different ELF sections into memory using the above described
 * memory spaces */ 
SECTIONS
{
	.boot_words : {
		*(boot_words) /* place the actual boot words here */
	} >boot
	.text : {
		*(.text) 
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

/* we need to compensate for the fact that the locations of the sat and prcb
 * are very far away from the bootwords. Thus computing the checksum via
 * addition causes drift to happen since we have multiple additions with carry. 
 * the i960 manual sucks on this point though... I am not sure if I should
 * trust it. 
 *
 * I have introduced drift compensation by adding "-2" for each corresponding
 * value above 0x8000'0000. Plus we are not using the checksum words
 * otherwise...
 *
 * */

cs1 = -(ABSOLUTE(system_address_table) + ABSOLUTE(prcb_ptr) + ABSOLUTE(start_ip)) ; 
cs2 = (ABSOLUTE(system_address_table) > 0x80000000) ? -2 : 0;
cs3 = (ABSOLUTE(prcb_ptr) > 0x80000000) ? -2 : 0;

