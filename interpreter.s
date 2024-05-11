/* this is the forth interpreter itself*/

/* start in IO space */
.org 0xFE800000
/* NOTHING CAN COME between this and the org directive! */
interpter_start:
	
