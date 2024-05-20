# new_bootrom
# Copyright (c) 2024, Joshua Scoggins
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR 
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

/* initial boot setup */
.macro incr reg
	addi \reg, 1, \reg
.endm
.macro DefTableEntry name
   .word (\name + 0x2)
.endm
.macro clear_g14
        ldconst 0, g14 # c compiler expects g14 to be 0
.endm
.macro save_globals
/* -- We allocate a spot for a "register holder" on the stack
 *    and store data to that spot. We will take advantage of
 *    the fact that this will be allocated at the first spot on the stack
 */
        ldconst 64, r4
        addo    sp, r4, sp
        stq     g0, -64(sp)
        stq     g4, -48(sp)
        stq     g8, -32(sp)
        stt     g12, -16(sp)
 .endm
 .macro restore_globals
        ldq     -64(sp), g0
        ldq     -48(sp), g4
        ldq     -32(sp), g8
        ldt     -16(sp), g12
 .endm

.macro c_call function
    clear_g14
    call \function
.endm

.macro c_callx function
    clear_g14
    callx \function
.endm

.macro def_system_call index,name
.text
.align 4
.global _\()\name
_\()\name:
lda \index, g13
calls g13
ret
.endm

.macro DeclareSegment a, b, c, d
.word \a
.word \b
.word \c
.word \d
.endm
.macro NullSegment
.space 16
.endm

.macro SegmentSelector base
.word ((\base)<<6) | 0x3f
.endm

.macro SimpleRegion address
DeclareSegment 0, 0, \address, 0x00fc00a3
.endm

.macro PagedRegion address, size
.space 8
.word \address
.word ((\size) << 18) | 0x5
.endm

.macro BipagedRegion address, size
.space 8
.word \address
.word ((\size) << 18) | 0x7
.endm

.macro PageEntry addr
.word ((\addr) | 0xc7)
.endm

.macro SmallSegmentTable addr
.space 8
.word \addr
.word (0x3f << 18) | 0xfb
.endm

.macro PortSegment addr
DeclareSegment 0, 0, \addr, 0x204000fb
.endm

.macro DefInterruptHandler name,toCall
.global \name
\name:
    save_globals
    c_call _vect_\toCall
    restore_globals
    ret
.endm

# CODE START
.global system_address_table
.global prcb_ptr
.global start_ip
.section boot_words, "a" /* this will be at address zero encoded in to the 2560 itself */
    .word system_address_table # SAT pointer
    .word prcb_ptr # prcb pointer
    .word 0
    .word start_ip # pointer to first ip
	.word cs1 # calculated at link time (bind ?cs1 (- (+ ?SAT ?PRCB ?startIP)))
    .word cs2 # drift compensation for system_address_table
    .word cs3 # drift compensation for prcb_ptr
    .word -1  # always need this
/* start in IO space */

.text

.align 6
system_address_table:
    NullSegment # 0
    NullSegment # 1
    NullSegment # 2
    NullSegment # 3
    NullSegment # 4
    NullSegment # 5
    NullSegment # 6
    DeclareSegment 0, 0, sys_proc_table, 0x304000fb # 7
    SmallSegmentTable system_address_table # 8
    DeclareSegment 0, 0, sys_proc_table, 0x304000fb # 9
    DeclareSegment 0, 0, fault_proc_table, 0x304000fb # 10

.align 6
prcb_ptr:
	# taken from hitagimon
    .word 0x0 # 0 - reserved
    .word 0xc # 4 - processor state = executing (no virtual address translation)
    .word 0x0 # 8 - reserved
    .word 0x0 # 12 - current process
    .word 0x0 # 16 - dispatch port
    .word intr_table # 20 - interrupt table physical address
    .word _intr_stack # 24 - interrupt stack pointer
    .word 0x0 # 28 - reserved
    SegmentSelector 7 # 32 - pointer to offset zero (region 3 segment selector)
    SegmentSelector 9 # 36 - system procedure table pointer
    .word fault_table # 40 - fault table
    .word 0x0 # 44 - reserved
    .space 12 # 48 -reserved
    .word 0   # 60 -reserved
    .space 8  # 64 - idle time
    .word 0   # 72 - system error fault
    .word 0   # 76 - reserved
    .space 48 # 80 - resumption record
    .space 44 # 128 - system  error fault record

.align 6
.global sys_proc_table
sys_proc_table:
    .word 0 # Reserved
    .word 0 # Reserved
    .word 0 # Reserved
    .word (_sup_stack + 0x1) # Supervisor stack pointer
    .word 0 # Preserved
    .word 0 # Preserved
    .word 0 # Preserved
    .word 0 # Preserved
    .word 0 # Preserved
    .word 0 # Preserved
    .word 0 # Preserved
    .word 0 # Preserved
# up to 260 entries!
    # example entry
	.word 0, 0, 0, 0 # 0-3
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 8-11
	.word 0, 0, 0, 0 # 12-15
	.word 0, 0, 0, 0 # 16-19
	.word 0, 0, 0, 0 # 20-23
	.word 0, 0, 0, 0 # 24-27
	.word 0, 0, 0, 0 # 28-31
	.word 0, 0, 0, 0 # 32-35
	.word 0, 0, 0, 0 # 36-39
	.word 0, 0, 0, 0 # 40-43
	.word 0, 0, 0, 0 # 44-47
	.word 0, 0, 0, 0 # 48-51
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0 # 4-7
	.word 0, 0, 0, 0
	.word 0, 0, 0, 0
	.word 0, 0, 0, 0 # 236-239
	.word 0, 0, 0, 0 # 240-243
	.word 0, 0, 0, 0 # 244-247
	.word 0, 0, 0, 0 # 248-251
	.word 0, 0, 0, 0 # 252-255
	.word 0, 0, 0, 0

.align 6
fault_proc_table:
.macro FaultTableEntry name
DefTableEntry _user_\()\name\()_core
.endm
    .word 0 # Reserved
    .word 0 # Reserved
    .word 0 # Reserved
    .word _sup_stack # Supervisor stack pointer
    .word 0 # Preserved
    .word 0 # Preserved
    .word 0 # Preserved
    .word 0 # Preserved
    .word 0 # Preserved
    .word 0 # Preserved
    .word 0 # Preserved
    .word 0 # Preserved
    FaultTableEntry override # entry 0
    FaultTableEntry trace
    FaultTableEntry operation
    FaultTableEntry arithmetic
    FaultTableEntry floating_point
    FaultTableEntry constraint
    FaultTableEntry virtual_memory
    FaultTableEntry protection
    FaultTableEntry machine
    FaultTableEntry structural
    FaultTableEntry type
    FaultTableEntry process # process
    FaultTableEntry descriptor
    FaultTableEntry event
    FaultTableEntry reserved

.macro FaultEntry index, code=0x2, table=0x2bf
.word (\index << 2) | \code
.word \table
.endm
.macro ReservedFaultEntry
FaultEntry 0x10
.endm
    .globl  fault_table
    .align  8
fault_table:
    FaultEntry 0  # override
    FaultEntry 1  # trace
    FaultEntry 2  # Operation
    FaultEntry 3  # arithmetic
    FaultEntry 4  # floating point
    FaultEntry 5  # constraint
    FaultEntry 6  # virtual memory
    FaultEntry 7  # protection
    FaultEntry 8  # Machine
    FaultEntry 9  # structural
    FaultEntry 0xa # type
    ReservedFaultEntry
    FaultEntry 0xb # process
    FaultEntry 0xc # descriptor
    FaultEntry 0xd # event
    ReservedFaultEntry
    ReservedFaultEntry
    ReservedFaultEntry
    ReservedFaultEntry
    ReservedFaultEntry
    ReservedFaultEntry
    ReservedFaultEntry
    ReservedFaultEntry
    ReservedFaultEntry
    ReservedFaultEntry
    ReservedFaultEntry
    ReservedFaultEntry
    ReservedFaultEntry
    ReservedFaultEntry
    ReservedFaultEntry
    ReservedFaultEntry
    ReservedFaultEntry
        .global     intr_table
        .align      6
intr_table:
        .word       0               # Pending Priorities    0
        .fill       8, 4, 0         # Pending Interrupts    4 + (0->7)*4
        .word _do_nothing_isr;           # interrupt table entry 8
        .word _do_nothing_isr;           # interrupt table entry 9
        .word _do_nothing_isr;           # interrupt table entry 10
        .word _do_nothing_isr;           # interrupt table entry 11
        .word _do_nothing_isr;           # interrupt table entry 12
        .word _do_nothing_isr;           # interrupt table entry 13
        .word _do_nothing_isr;           # interrupt table entry 14
        .word _do_nothing_isr;           # interrupt table entry 15
        .word _do_nothing_isr;           # interrupt table entry 16
        .word _do_nothing_isr;           # interrupt table entry 17
        .word _do_nothing_isr;           # interrupt table entry 18
        .word _do_nothing_isr;           # interrupt table entry 19
        .word _do_nothing_isr;           # interrupt table entry 20
        .word _do_nothing_isr;           # interrupt table entry 21
        .word _do_nothing_isr;           # interrupt table entry 22
        .word _do_nothing_isr;           # interrupt table entry 23
        .word _do_nothing_isr;           # interrupt table entry 24
        .word _do_nothing_isr;           # interrupt table entry 25
        .word _do_nothing_isr;           # interrupt table entry 26
        .word _do_nothing_isr;           # interrupt table entry 27
        .word _do_nothing_isr;           # interrupt table entry 28
        .word _do_nothing_isr;           # interrupt table entry 29
        .word _do_nothing_isr;           # interrupt table entry 30
        .word _do_nothing_isr;           # interrupt table entry 31
        .word _do_nothing_isr;           # interrupt table entry 32
        .word _do_nothing_isr;           # interrupt table entry 33
        .word _do_nothing_isr;           # interrupt table entry 34
        .word _do_nothing_isr;           # interrupt table entry 35
        .word _do_nothing_isr;           # interrupt table entry 36
        .word _do_nothing_isr;           # interrupt table entry 37
        .word _do_nothing_isr;           # interrupt table entry 38
        .word _do_nothing_isr;           # interrupt table entry 39
        .word _do_nothing_isr;           # interrupt table entry 40
        .word _do_nothing_isr;           # interrupt table entry 41
        .word _do_nothing_isr;           # interrupt table entry 42
        .word _do_nothing_isr;           # interrupt table entry 43
        .word _do_nothing_isr;           # interrupt table entry 44
        .word _do_nothing_isr;           # interrupt table entry 45
        .word _do_nothing_isr;           # interrupt table entry 46
        .word _do_nothing_isr;           # interrupt table entry 47
        .word _do_nothing_isr;           # interrupt table entry 48
        .word _do_nothing_isr;           # interrupt table entry 49
        .word _do_nothing_isr;           # interrupt table entry 50
        .word _do_nothing_isr;           # interrupt table entry 51
        .word _do_nothing_isr;           # interrupt table entry 52
        .word _do_nothing_isr;           # interrupt table entry 53
        .word _do_nothing_isr;           # interrupt table entry 54
        .word _do_nothing_isr;           # interrupt table entry 55
        .word _do_nothing_isr;           # interrupt table entry 56
        .word _do_nothing_isr;           # interrupt table entry 57
        .word _do_nothing_isr;           # interrupt table entry 58
        .word _do_nothing_isr;           # interrupt table entry 59
        .word _do_nothing_isr;           # interrupt table entry 60
        .word _do_nothing_isr;           # interrupt table entry 61
        .word _do_nothing_isr;           # interrupt table entry 62
        .word _do_nothing_isr;           # interrupt table entry 63
        .word _do_nothing_isr;           # interrupt table entry 64
        .word _do_nothing_isr;           # interrupt table entry 65
        .word _do_nothing_isr;           # interrupt table entry 66
        .word _do_nothing_isr;           # interrupt table entry 67
        .word _do_nothing_isr;           # interrupt table entry 68
        .word _do_nothing_isr;           # interrupt table entry 69
        .word _do_nothing_isr;           # interrupt table entry 70
        .word _do_nothing_isr;           # interrupt table entry 71
        .word _do_nothing_isr;           # interrupt table entry 72
        .word _do_nothing_isr;           # interrupt table entry 73
        .word _do_nothing_isr;           # interrupt table entry 74
        .word _do_nothing_isr;           # interrupt table entry 75
        .word _do_nothing_isr;           # interrupt table entry 76
        .word _do_nothing_isr;           # interrupt table entry 77
        .word _do_nothing_isr;           # interrupt table entry 78
        .word _do_nothing_isr;           # interrupt table entry 79
        .word _do_nothing_isr;           # interrupt table entry 80
        .word _do_nothing_isr;           # interrupt table entry 81
        .word _do_nothing_isr;           # interrupt table entry 82
        .word _do_nothing_isr;           # interrupt table entry 83
        .word _do_nothing_isr;           # interrupt table entry 84
        .word _do_nothing_isr;           # interrupt table entry 85
        .word _do_nothing_isr;           # interrupt table entry 86
        .word _do_nothing_isr;           # interrupt table entry 87
        .word _do_nothing_isr;           # interrupt table entry 88
        .word _do_nothing_isr;           # interrupt table entry 89
        .word _do_nothing_isr;           # interrupt table entry 90
        .word _do_nothing_isr;           # interrupt table entry 91
        .word _do_nothing_isr;           # interrupt table entry 92
        .word _do_nothing_isr;           # interrupt table entry 93
        .word _do_nothing_isr;           # interrupt table entry 94
        .word _do_nothing_isr;           # interrupt table entry 95
        .word _do_nothing_isr;           # interrupt table entry 96
        .word _do_nothing_isr;           # interrupt table entry 97
        .word _do_nothing_isr;           # interrupt table entry 98
        .word _do_nothing_isr;           # interrupt table entry 99
        .word _do_nothing_isr;           # interrupt table entry 100
        .word _do_nothing_isr;           # interrupt table entry 101
        .word _do_nothing_isr;           # interrupt table entry 102
        .word _do_nothing_isr;           # interrupt table entry 103
        .word _do_nothing_isr;           # interrupt table entry 104
        .word _do_nothing_isr;           # interrupt table entry 105
        .word _do_nothing_isr;           # interrupt table entry 106
        .word _do_nothing_isr;           # interrupt table entry 107
        .word _do_nothing_isr;           # interrupt table entry 108
        .word _do_nothing_isr;           # interrupt table entry 109
        .word _do_nothing_isr;           # interrupt table entry 110
        .word _do_nothing_isr;           # interrupt table entry 111
        .word _do_nothing_isr;           # interrupt table entry 112
        .word _do_nothing_isr;           # interrupt table entry 113
        .word _do_nothing_isr;           # interrupt table entry 114
        .word _do_nothing_isr;           # interrupt table entry 115
        .word _do_nothing_isr;           # interrupt table entry 116
        .word _do_nothing_isr;           # interrupt table entry 117
        .word _do_nothing_isr;           # interrupt table entry 118
        .word _do_nothing_isr;           # interrupt table entry 119
        .word _do_nothing_isr;           # interrupt table entry 120
        .word _do_nothing_isr;           # interrupt table entry 121
        .word _do_nothing_isr;           # interrupt table entry 122
        .word _do_nothing_isr;           # interrupt table entry 123
        .word _do_nothing_isr;           # interrupt table entry 124
        .word _do_nothing_isr;           # interrupt table entry 125
        .word _do_nothing_isr;           # interrupt table entry 126
        .word _do_nothing_isr;           # interrupt table entry 127
        .word _do_nothing_isr;           # interrupt table entry 128
        .word _do_nothing_isr;           # interrupt table entry 129
        .word _do_nothing_isr;           # interrupt table entry 130
        .word _do_nothing_isr;           # interrupt table entry 131
        .word _do_nothing_isr;           # interrupt table entry 132
        .word _do_nothing_isr;           # interrupt table entry 133
        .word _do_nothing_isr;           # interrupt table entry 134
        .word _do_nothing_isr;           # interrupt table entry 135
        .word _do_nothing_isr;           # interrupt table entry 136
        .word _do_nothing_isr;           # interrupt table entry 137
        .word _do_nothing_isr;           # interrupt table entry 138
        .word _do_nothing_isr;           # interrupt table entry 139
        .word _do_nothing_isr;           # interrupt table entry 140
        .word _do_nothing_isr;           # interrupt table entry 141
        .word _do_nothing_isr;           # interrupt table entry 142
        .word _do_nothing_isr;           # interrupt table entry 143
        .word _do_nothing_isr;           # interrupt table entry 144
        .word _do_nothing_isr;           # interrupt table entry 145
        .word _do_nothing_isr;           # interrupt table entry 146
        .word _do_nothing_isr;           # interrupt table entry 147
        .word _do_nothing_isr;           # interrupt table entry 148
        .word _do_nothing_isr;           # interrupt table entry 149
        .word _do_nothing_isr;           # interrupt table entry 150
        .word _do_nothing_isr;           # interrupt table entry 151
        .word _do_nothing_isr;           # interrupt table entry 152
        .word _do_nothing_isr;           # interrupt table entry 153
        .word _do_nothing_isr;           # interrupt table entry 154
        .word _do_nothing_isr;           # interrupt table entry 155
        .word _do_nothing_isr;           # interrupt table entry 156
        .word _do_nothing_isr;           # interrupt table entry 157
        .word _do_nothing_isr;           # interrupt table entry 158
        .word _do_nothing_isr;           # interrupt table entry 159
        .word _do_nothing_isr;           # interrupt table entry 160
        .word _do_nothing_isr;           # interrupt table entry 161
        .word _do_nothing_isr;           # interrupt table entry 162
        .word _do_nothing_isr;           # interrupt table entry 163
        .word _do_nothing_isr;           # interrupt table entry 164
        .word _do_nothing_isr;           # interrupt table entry 165
        .word _do_nothing_isr;           # interrupt table entry 166
        .word _do_nothing_isr;           # interrupt table entry 167
        .word _do_nothing_isr;           # interrupt table entry 168
        .word _do_nothing_isr;           # interrupt table entry 169
        .word _do_nothing_isr;           # interrupt table entry 170
        .word _do_nothing_isr;           # interrupt table entry 171
        .word _do_nothing_isr;           # interrupt table entry 172
        .word _do_nothing_isr;           # interrupt table entry 173
        .word _do_nothing_isr;           # interrupt table entry 174
        .word _do_nothing_isr;           # interrupt table entry 175
        .word _do_nothing_isr;           # interrupt table entry 176
        .word _do_nothing_isr;           # interrupt table entry 177
        .word _do_nothing_isr;           # interrupt table entry 178
        .word _do_nothing_isr;           # interrupt table entry 179
        .word _do_nothing_isr;           # interrupt table entry 180
        .word _do_nothing_isr;           # interrupt table entry 181
        .word _do_nothing_isr;           # interrupt table entry 182
        .word _do_nothing_isr;           # interrupt table entry 183
        .word _do_nothing_isr;           # interrupt table entry 184
        .word _do_nothing_isr;           # interrupt table entry 185
        .word _do_nothing_isr;           # interrupt table entry 186
        .word _do_nothing_isr;           # interrupt table entry 187
        .word _do_nothing_isr;           # interrupt table entry 188
        .word _do_nothing_isr;           # interrupt table entry 189
        .word _do_nothing_isr;           # interrupt table entry 190
        .word _do_nothing_isr;           # interrupt table entry 191
        .word _do_nothing_isr;           # interrupt table entry 192
        .word _do_nothing_isr;           # interrupt table entry 193
        .word _do_nothing_isr;           # interrupt table entry 194
        .word _do_nothing_isr;           # interrupt table entry 195
        .word _do_nothing_isr;           # interrupt table entry 196
        .word _do_nothing_isr;           # interrupt table entry 197
        .word _do_nothing_isr;           # interrupt table entry 198
        .word _do_nothing_isr;           # interrupt table entry 199
        .word _do_nothing_isr;           # interrupt table entry 200
        .word _do_nothing_isr;           # interrupt table entry 201
        .word _do_nothing_isr;           # interrupt table entry 202
        .word _do_nothing_isr;           # interrupt table entry 203
        .word _do_nothing_isr;           # interrupt table entry 204
        .word _do_nothing_isr;           # interrupt table entry 205
        .word _do_nothing_isr;           # interrupt table entry 206
        .word _do_nothing_isr;           # interrupt table entry 207
        .word _do_nothing_isr;           # interrupt table entry 208
        .word _do_nothing_isr;           # interrupt table entry 209
        .word _do_nothing_isr;           # interrupt table entry 210
        .word _do_nothing_isr;           # interrupt table entry 211
        .word _do_nothing_isr;           # interrupt table entry 212
        .word _do_nothing_isr;           # interrupt table entry 213
        .word _do_nothing_isr;           # interrupt table entry 214
        .word _do_nothing_isr;           # interrupt table entry 215
        .word _do_nothing_isr;           # interrupt table entry 216
        .word _do_nothing_isr;           # interrupt table entry 217
        .word _do_nothing_isr;           # interrupt table entry 218
        .word _do_nothing_isr;           # interrupt table entry 219
        .word _do_nothing_isr;           # interrupt table entry 220
        .word _do_nothing_isr;           # interrupt table entry 221
        .word _do_nothing_isr;           # interrupt table entry 222
        .word _do_nothing_isr;           # interrupt table entry 223

        .word _do_nothing_isr;           # interrupt table entry 224
        .word _do_nothing_isr;           # interrupt table entry 225
        .word _do_nothing_isr;           # interrupt table entry 226
        .word _do_nothing_isr;           # interrupt table entry 227
        .word _do_nothing_isr;           # interrupt table entry 228
        .word _do_nothing_isr;           # interrupt table entry 229
        .word _do_nothing_isr;           # interrupt table entry 230
        .word _do_nothing_isr;           # interrupt table entry 231
        .word _do_nothing_isr;           # interrupt table entry 232
        .word _do_nothing_isr;           # interrupt table entry 233
        .word _do_nothing_isr;           # interrupt table entry 234
        .word _do_nothing_isr;           # interrupt table entry 235
        .word _do_nothing_isr;           # interrupt table entry 236
        .word _do_nothing_isr;           # interrupt table entry 237
        .word _do_nothing_isr;           # interrupt table entry 238
        .word _do_nothing_isr;           # interrupt table entry 239

        .word _do_nothing_isr;           # interrupt table entry 240
        .word _do_nothing_isr;           # interrupt table entry 241
        .word _do_nothing_isr;           # interrupt table entry 242
        .word _do_nothing_isr;           # interrupt table entry 243
        .word _do_nothing_isr;           # Reserved
        .word _do_nothing_isr;           # Reserved
        .word _do_nothing_isr;           # Reserved
        .word _do_nothing_isr;           # Reserved

        .word _do_nothing_isr;            # NMI Interrupt
        .word _do_nothing_isr;           # Reserved
        .word _do_nothing_isr;           # Reserved
        .word _do_nothing_isr;           # Reserved
        .word _isr3          ;           # interrupt table entry 252
        .word _isr2          ;           # interrupt table entry 253
        .word _isr1          ;           # interrupt table entry 254
        .word _isr0          ;           # interrupt table entry 255

.align 6
# extra structures and handlers for initialization and booting
.global _do_nothing_isr
DefInterruptHandler _isr0, INT0
DefInterruptHandler _isr1, INT1
DefInterruptHandler _isr2, INT2
DefInterruptHandler _isr3, INT3
_do_nothing_isr:
	ret
.macro DefFaultDispatcher name
.text
_user_\()\name\()_core:
	lda	-48(fp), g0	/* pass fault data */
	callx _user_\()\name
	flushreg
	ret
.endm
# We pass the fault data by grabbing it and passing it via g0 to the function itself
DefFaultDispatcher override
DefFaultDispatcher trace
DefFaultDispatcher operation
DefFaultDispatcher arithmetic
DefFaultDispatcher floating_point
DefFaultDispatcher constraint
DefFaultDispatcher protection
DefFaultDispatcher machine
DefFaultDispatcher type
DefFaultDispatcher virtual_memory
DefFaultDispatcher structural
DefFaultDispatcher process
DefFaultDispatcher descriptor
DefFaultDispatcher event
DefFaultDispatcher reserved
# fault handlers
_user_process:
	ret
_user_structural:
	ret
_user_virtual_memory:
	ret
_user_descriptor:
	ret
_user_type:
	ret
_user_machine:
	ret
_user_protection:
	ret
_user_event:
	ret
_user_constraint:
	ret
_user_reserved:
	ret
_user_floating_point:
	ret
_user_override:
	ret
_user_trace:
	ret
_user_operation:
	ret
_user_arithmetic:
	ret
# interrupt lines handlers
_vect_INT0:
	ret
_vect_INT1:
	ret
_vect_INT2:
	ret
_vect_INT3:
	ret
# for now, increase the stacks to be sure
.bss _user_stack, 4096, 6
.bss _intr_stack , 4096, 6
.bss _sup_stack, 4096, 6
.bss _intr_ram, 1028, 6
.bss _prcb_ram, 176, 6

.set IOSpaceBase, 0xFE000000
.set CLK1SpeedPort, IOSpaceBase + 0x0
.set CLK2SpeedPort, IOSpaceBase + 0x4
.set ConsolePort, IOSpaceBase + 0x8
.set FlushPort, IOSpaceBase + 0xC
.macro Console_WriteCharacter value
	st \value, (ConsolePort)
.endm
.macro Console_ReadCharacter dest
	ld (ConsolePort), \dest
.endm
.macro Console_Flush 
	st g0, (FlushPort)
.endm
.macro Console_NewLine
	ldconst '\n', r15
	Console_WriteCharacter r15
	Console_Flush
.endm
.text
.align 6
# code actually begins here!
start_ip:
	mov 0, g14 
# transfer the interrupt table to ram
	ldconst 1028, g0
	ldconst intr_table, g1
	ldconst _intr_ram, g2
	ldconst 0, g3
	bal move_data
# transfer the PRCB to ram
	ldconst 176, g0
	ldconst prcb_ptr, g1
	ldconst _prcb_ram, g2
	ldconst 0, g3
	bal move_data

# now we need to fix up the prcb to point to the new interrupt table
	ldconst _intr_ram, g0  # load address of the ram based interrupt table
	ldconst _prcb_ram, g1 # load prcb in ram
	st g0, 20(g1) 		  # store into the PRCB
# pass control off to the interpreter/stage1
	ldconst 0xff000010, g5
	ldconst .Ljump_to_interpreter_iac, g6
	synmovq g5, g6
	
	.align 4
.Ljump_to_interpreter_iac:
	.word 0x93000000 /* reinitialize iac message */
	.word system_address_table
	.word _prcb_ram
	.word interpreter_entry
.align 6
	# a simple data transfer routine responsible for copying blocks of 16-bytes from one place and 
    # depositing them in another location
move_data:
	# g0 - size
	# g1 - src pointer
	# g2 - destination pointer
 	# g3 - offset
	# taken from the Kx manual and modified to look like the one found in SX
    #  manual and what I wrote for hitagimon (without the text output!)
	ldq  (g1)[g4*1], g8       # load 4 words into g8
	stq  g8, (g2)[g4*1]       # store to destination
	addi g4, 16, g4		      # next 16 bytes
	cmpibg g0, g4, move_data  # loop until done
	bx (g14)				  # return
_init_fp:
	cvtir 0, fp0
	movre fp0, fp1
	movre fp1, fp2
	movre fp2, fp3
	ret
fix_stack:
	flushreg
	or pfp, 7, pfp # put interrupt return code into pfp
	ldconst 0x1f0002, g0
	st g0, -16(fp) # store contrived PC
	ldconst 0x3b001000, g0 # setup arithmetic controls
	st g0, -12(fp)	       # store contrived AC
	ret
interpreter_entry:
	# before we enter into the interpreter, we leave interpreter state
	ldconst 64, g0 # bump up stack to make
	addo sp, g0, sp # room for simulated interrupt frame
	call fix_stack
	lda _user_stack, fp # setup user stack space
	lda -0x40(fp), pfp  # load pfp
	lda 0x40(fp), sp    # setup current stack pointer
	b _simple_vm
_forth_frontend:
	# at this point we are ready to enter into the interpreter
1:
	call _prompt
	call _getline
	cmpibe 0, g0, 2f
	call _display_input
2:
	b 1b
_getline:
	ldconst line_input, g0
	call _read_line
	st g0, (line_length)
	ret
	
_prompt:
	ldconst prompt0, g0
	call _print_string
	ret
_display_input:
	ldconst prompt1, g0
	call _print_string
	ldconst line_input, g0
	call _print_string
	ldconst newline, g0
	call _print_string
	ret
_read_line:
	# g0 is the storage cell as an input and the length when done
	ldconst 0, r4 # the number of characters read this invocation
	ldconst 0, r5 # the current character
1:
	Console_ReadCharacter r5 # get a character
	cmpibg 0, r5, 1b		 # we got a negative value so keep waiting
	cmpibe '\n', r5, 2f        # done so record the final thing
							 # stash the character and increment by 1
	stob r5, 0(g0)			 # save to memory
	incr r4					 # increment count by 1
	incr g0					 # increment address by 1
	b 1b
2:
	ldconst 0, r5
	stob r5, 0(r3)			 # stash a zero in the next cell after the last one
	mov r4, g0				 # return the number of characters read
	ret
_print_string:
	mov g0, r3
1:
	ldob 0(r3), g0 # load the first character
	cmpibe 0, g0, 2f
	Console_WriteCharacter g0
	incr r3				 # next character
	b 1b					  # go again
2:
	Console_Flush
	ret

prompt0: 
	.asciz "> "
prompt1:
	.asciz "you input: "
newline:
	.asciz "\n"
.bss line_input, 256, 6
.data
.align 4
line_metadata:
line_position:
	.word 0
line_length:
	.word 0

# this is a simple little routine to provide an execution body as needed
.text
.align 6
_sit_and_spin:
b _sit_and_spin
# This ROM needs to have a simple way to build up the system based off of some simple actions and operators
# each element is a single ascii character, I provide a way to compose more operators via a semi variable length design
# 
# This also requires a simple interpreter/vm to be used to setup the environment
.data
# we have a lookup table here
.macro ActionTableEntry target=0, x1=0, x2=0, x3=0
	.word \target, \x1, \x2, \x3
.endm
.align 6
CurrentActionTable:
	.word ActionTable # this is the current "instruction set" being executed
ActionTable:
# based off of the ascii codes set
	ActionTableEntry # 0x00 - NULL (null)
	ActionTableEntry # 0x01 - SOH (start of heading)
	ActionTableEntry # 0x02 - SOT (start of text)
	ActionTableEntry # 0x03 - ETX (end of text)
	ActionTableEntry # 0x04 - EOT (end of transmission)
	ActionTableEntry # 0x05 - ENQ (enquiry)
	ActionTableEntry # 0x06 - ACK (acknowledge)
	ActionTableEntry # 0x07 - BEL (bell)
	ActionTableEntry # 0x08 - BS  (backspace)
	ActionTableEntry # 0x09 - TAB (horizontal tab)
	ActionTableEntry # 0x0a - LF  (NL line feed, new line)
	ActionTableEntry # 0x0b - VT  (vertical tab)
	ActionTableEntry # 0x0c - FF (NP form feed, new page)
	ActionTableEntry # 0x0d - CR (carriage return)
	ActionTableEntry # 0x0e - SO (shift out) - switch to the other action set
	ActionTableEntry # 0x0f - SI (shift in) - switch to the original action set
	ActionTableEntry # 0x10 - DLE (data link escape)
	ActionTableEntry # 0x11 - DC1 (device control 1)
	ActionTableEntry # 0x12 - DC2 (device control 2)
	ActionTableEntry # 0x13 - DC3 (device control 3)
	ActionTableEntry # 0x14 - DC4 (device control 4)
	ActionTableEntry # 0x15 - NAK (negative acknowledge)
	ActionTableEntry # 0x16 - SYN (synchronous idle)
	ActionTableEntry # 0x17 - ETB (end of transmission block)
	ActionTableEntry # 0x18 - CAN (cancel)
	ActionTableEntry # 0x19 - EM  (end of medium)
	ActionTableEntry # 0x1a - SUB (substitute)
	ActionTableEntry # 0x1b - ESC (escape)
	ActionTableEntry # 0x1c - FS  (file separator)
	ActionTableEntry # 0x1d - GS  (group separator)
	ActionTableEntry # 0x1e - RS  (record separator)
	ActionTableEntry # 0x1f - US  (unit separator)
	ActionTableEntry # 0x20 - space
	ActionTableEntry # 0x21 - !
	ActionTableEntry # 0x22 - "
	ActionTableEntry # 0x23 - #
	ActionTableEntry # 0x24 - $
	ActionTableEntry # 0x25 - %
	ActionTableEntry # 0x26 - &
	ActionTableEntry # 0x27 - '
	ActionTableEntry # 0x28 - (
	ActionTableEntry # 0x29 - )
	ActionTableEntry # 0x2a - *
	ActionTableEntry # 0x2b - +
	ActionTableEntry # 0x2c - ,
	ActionTableEntry # 0x2d - -
	ActionTableEntry # 0x2e - .
	ActionTableEntry # 0x2f - /
	ActionTableEntry # 0x30 - 0
	ActionTableEntry # 0x31 - 1
	ActionTableEntry # 0x32 - 2
	ActionTableEntry # 0x33 - 3
	ActionTableEntry # 0x34 - 4
	ActionTableEntry # 0x35 - 5
	ActionTableEntry # 0x36 - 6
	ActionTableEntry # 0x37 - 7
	ActionTableEntry # 0x38 - 8
	ActionTableEntry # 0x39 - 9
	ActionTableEntry # 0x3a - :
	ActionTableEntry # 0x3b - ;
	ActionTableEntry # 0x3c - <
	ActionTableEntry # 0x3d - =
	ActionTableEntry # 0x3e - >
	ActionTableEntry # 0x3f - ?
	ActionTableEntry # 0x40 - @
	ActionTableEntry # 0x41 - A
	ActionTableEntry # 0x42 - B
	ActionTableEntry # 0x43 - C 
	ActionTableEntry # 0x44 - D 
	ActionTableEntry # 0x45 - E
	ActionTableEntry # 0x46 - F
	ActionTableEntry # 0x47 - G
	ActionTableEntry # 0x48 - H
	ActionTableEntry # 0x49 - I
	ActionTableEntry # 0x4a - J
	ActionTableEntry # 0x4b - K
	ActionTableEntry # 0x4c - L
	ActionTableEntry # 0x4d - M
	ActionTableEntry # 0x4e - N
	ActionTableEntry # 0x4f - O
	ActionTableEntry # 0x50 - P 
	ActionTableEntry # 0x51 - Q
	ActionTableEntry # 0x52 - R
	ActionTableEntry # 0x53 - S
	ActionTableEntry # 0x54 - T
	ActionTableEntry # 0x55 - U
	ActionTableEntry # 0x56 - V
	ActionTableEntry # 0x57 - W
	ActionTableEntry # 0x58 - X
	ActionTableEntry # 0x59 - Y
	ActionTableEntry # 0x5a - Z
	ActionTableEntry # 0x5b - [
	ActionTableEntry # 0x5c - \
	ActionTableEntry # 0x5d - ]
	ActionTableEntry # 0x5e - ^
	ActionTableEntry # 0x5f - _
	ActionTableEntry # 0x60 - `
	ActionTableEntry # 0x61 - a
	ActionTableEntry # 0x62 - b
	ActionTableEntry # 0x63 - c
	ActionTableEntry # 0x64 - d
	ActionTableEntry # 0x65 - e
	ActionTableEntry # 0x66 - f
	ActionTableEntry # 0x67 - g
	ActionTableEntry # 0x68 - h
	ActionTableEntry # 0x69 - i
	ActionTableEntry # 0x6a - j
	ActionTableEntry # 0x6b - k
	ActionTableEntry # 0x6c - l
	ActionTableEntry # 0x6d - m
	ActionTableEntry # 0x6e - n
	ActionTableEntry # 0x6f - o
	ActionTableEntry # 0x70 - p
	ActionTableEntry # 0x71 - q
	ActionTableEntry # 0x72 - r
	ActionTableEntry # 0x73 - s
	ActionTableEntry # 0x74 - t
	ActionTableEntry # 0x75 - u
	ActionTableEntry # 0x76 - v
	ActionTableEntry # 0x77 - w
	ActionTableEntry # 0x78 - x
	ActionTableEntry # 0x79 - y
	ActionTableEntry # 0x7a - z
	ActionTableEntry # 0x7b - {
	ActionTableEntry # 0x7c - |
	ActionTableEntry # 0x7d - }
	ActionTableEntry # 0x7e - ~
	ActionTableEntry # 0x7f - DEL
# extended ascii codes / C1 control codes
	ActionTableEntry # 0x80 - PAD (Padding Character)
	ActionTableEntry # 0x81 - HOP (High Octet Preset)
	ActionTableEntry # 0x82 - BPH (Break Permitted Here)
	ActionTableEntry # 0x83 - NBH (No Break Here)
	ActionTableEntry # 0x84 - IND (Index)
	ActionTableEntry # 0x85 - NEL (Next Line)
	ActionTableEntry # 0x86 - SSA (Start of Selected Area)
	ActionTableEntry # 0x87 - ESA (End of Selected Area)
	ActionTableEntry # 0x88 - HTS (Character Tabulation Set/Horizontal Tabulation Set)
	ActionTableEntry # 0x89 - HTJ (Character Tabulation With Justification/Horizontal Tabulation With Justification)
	ActionTableEntry # 0x8a - VTS (Line/Vertical Tabulation Set)
	ActionTableEntry # 0x8b - PLD (Partial Line Forward/Partial Line Down)
	ActionTableEntry # 0x8c - PLU (Partial Line Backward/Partial Line Up)
	ActionTableEntry # 0x8d - RI  (Reverse Line Feed / Reverse Index)
	ActionTableEntry # 0x8e - SS2 (Single Shift 2)
	ActionTableEntry # 0x8f - SS3 (Single Shift 3)
	ActionTableEntry # 0x90 - DCS (Device Control String)
	ActionTableEntry # 0x91 - PU1 (Private Use 1)
	ActionTableEntry # 0x92 - PU2 (Private Use 2)
	ActionTableEntry # 0x93 - STS (Set Transmit State)
	ActionTableEntry # 0x94 - CCH (Cancel character)
	ActionTableEntry # 0x95 - MW (Message Waiting)
	ActionTableEntry # 0x96 - SPA (Start of Protected Area)
	ActionTableEntry # 0x97 - EPA (End of Protected Area)
	ActionTableEntry # 0x98 - SOS (Start of String)
	ActionTableEntry # 0x99 - SGC/SGCI (Single Graphic Character Introducer [For unicode])
	ActionTableEntry PrintAscii # 0x9a - SCI (Single Character Introducer [To be followed by a single printable character (0x20 through 0x7e) or format effector (0x08 through 0x0d), and to print it as ASCII no matter what graphic or control sets were in use)
	ActionTableEntry # 0x9b - CSI (Control Sequence Introducer [Used to introduce control sequences that take parameters. ANSI escape sequences])
	ActionTableEntry # 0x9c - ST (String Terminator)
	ActionTableEntry # 0x9d - OSC (Operating System Command)
	ActionTableEntry # 0x9e - PM (Privacy Message)
	ActionTableEntry # 0x9f - APC (Application Program Command)
	ActionTableEntry # 0xa0
	ActionTableEntry # 0xa1
	ActionTableEntry # 0xa2
	ActionTableEntry # 0xa3
	ActionTableEntry # 0xa4
	ActionTableEntry # 0xa5
	ActionTableEntry # 0xa6
	ActionTableEntry # 0xa7
	ActionTableEntry # 0xa8
	ActionTableEntry # 0xa9
	ActionTableEntry # 0xaa
	ActionTableEntry # 0xab
	ActionTableEntry # 0xac
	ActionTableEntry # 0xad
	ActionTableEntry # 0xae
	ActionTableEntry # 0xaf
	ActionTableEntry # 0xb0
	ActionTableEntry # 0xb1
	ActionTableEntry # 0xb2
	ActionTableEntry # 0xb3
	ActionTableEntry # 0xb4
	ActionTableEntry # 0xb5
	ActionTableEntry # 0xb6
	ActionTableEntry # 0xb7
	ActionTableEntry # 0xb8
	ActionTableEntry # 0xb9
	ActionTableEntry # 0xba
	ActionTableEntry # 0xbb
	ActionTableEntry # 0xbc
	ActionTableEntry # 0xbd
	ActionTableEntry # 0xbe
	ActionTableEntry # 0xbf
	ActionTableEntry # 0xc0
	ActionTableEntry # 0xc1
	ActionTableEntry # 0xc2
	ActionTableEntry # 0xc3
	ActionTableEntry # 0xc4
	ActionTableEntry # 0xc5
	ActionTableEntry # 0xc6
	ActionTableEntry # 0xc7
	ActionTableEntry # 0xc8
	ActionTableEntry # 0xc9
	ActionTableEntry # 0xca
	ActionTableEntry # 0xcb
	ActionTableEntry # 0xcc
	ActionTableEntry # 0xcd
	ActionTableEntry # 0xce
	ActionTableEntry # 0xcf
	ActionTableEntry # 0xd0
	ActionTableEntry # 0xd1
	ActionTableEntry # 0xd2
	ActionTableEntry # 0xd3
	ActionTableEntry # 0xd4
	ActionTableEntry # 0xd5
	ActionTableEntry # 0xd6
	ActionTableEntry # 0xd7
	ActionTableEntry # 0xd8
	ActionTableEntry # 0xd9
	ActionTableEntry # 0xda
	ActionTableEntry # 0xdb
	ActionTableEntry # 0xdc
	ActionTableEntry # 0xdd
	ActionTableEntry # 0xde
	ActionTableEntry # 0xdf
	ActionTableEntry # 0xe0
	ActionTableEntry # 0xe1
	ActionTableEntry # 0xe2
	ActionTableEntry # 0xe3
	ActionTableEntry # 0xe4
	ActionTableEntry # 0xe5
	ActionTableEntry # 0xe6
	ActionTableEntry # 0xe7
	ActionTableEntry # 0xe8
	ActionTableEntry # 0xe9
	ActionTableEntry # 0xea
	ActionTableEntry # 0xeb
	ActionTableEntry # 0xec
	ActionTableEntry # 0xed
	ActionTableEntry # 0xee
	ActionTableEntry # 0xef
	ActionTableEntry # 0xf0
	ActionTableEntry # 0xf1
	ActionTableEntry # 0xf2
	ActionTableEntry # 0xf3
	ActionTableEntry # 0xf4
	ActionTableEntry # 0xf5
	ActionTableEntry # 0xf6
	ActionTableEntry # 0xf7
	ActionTableEntry # 0xf8
	ActionTableEntry # 0xf9
	ActionTableEntry # 0xfa
	ActionTableEntry # 0xfb
	ActionTableEntry # 0xfc
	ActionTableEntry # 0xfd
	ActionTableEntry # 0xfe
	ActionTableEntry # 0xff
.text
.align 6
PrintAscii: # Single Character Introducer (the print character instruction)
			# To be followed by a single character to be interpreted no matter the character set as an ascii character
	Console_ReadCharacter r3 # read the next character as we are going to print that one out
	ldconst 0x0000007F, r4   # convert to ascii code mask
	and r3, r4, r3
	Console_WriteCharacter r3 # then just write the masked value out
	Console_Flush
	ret
_dispatch_first_character:
	Console_ReadCharacter r3 # get the first character from the console port
	ldconst 0x000000FF, r4
	and r3, r4, r3 # convert to an 8-bit value for simplicity
	ldq  (ActionTable)[r3*16], r8       # load 4 words into r8 so I can interpret the entries themselves
	cmpibe 0, r8, .LFinished		   # not pointing to anything
	callx (r8)
.LFinished:
	ret


_simple_vm:
# this is our execution machine, each operation is like a monitor
# for example, we want to provide a way to store a value to memory
# !xxxxxxxxyyyyyyyy This will cause a 32-bit value (x) to be stored to a 32-bit address (y)
# We wrap all instructions with : and end with ;
# Otherwise, we ignore everything else
# We also view the '#' as a single line comment
# The newline character is important since no commands can be less than this line
#call _getline # reuse the commands that we were using earlier
	call _dispatch_first_character
	b _simple_vm
