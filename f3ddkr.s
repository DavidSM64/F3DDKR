/*
 * I tried to make this file similar to the fast3d.s file in the sm64 repo.
 * https://github.com/n64decomp/sm64/blob/master/rsp/fast3d.s
 *
 * TODO: Lots of cleanup and documentation. 
   Take this file with a huge mountain of salt, just because this assembles correctly does not mean that the labels are accurate. 
 */

/*
 * ---- Required inputs ----
 * CODE_FILE: Output filename for the .text section
 * DATA_FILE: Output filename for the .data section
 * METHOD: Should either be "XBUS", "FIFO", or "DRAM_DUMP". 
           Determines how the output RDP triangle data is processed.
 * Usage: `armips.exe f3ddkr.s -strequ CODE_FILE <output code filepath> -strequ DATA_FILE <output data filepath> -strequ METHOD <XBUS|FIFO|DRAM_DUMP>`
 */ 

.if version() < 110
    .error "armips 0.11 or newer is required"
.endif

.if METHOD != "XBUS" && METHOD != "FIFO" && METHOD != "DRAM_DUMP"
    .error "METHOD must be defined as: XBUS, FIFO, or DRAM_DUMP!"
.endif

.rsp // N64 RSP code

// Overlay table data member offsets
overlay_load equ 0x0000
overlay_len  equ 0x0004
overlay_imem equ 0x0006
.macro OverlayEntry, loadStart, loadEnd, imemAddr
  .dw loadStart
  .dh (loadEnd - loadStart - 1) & 0xFFFF
  .dh (imemAddr) & 0xFFFF
.endmacro

.macro jumpTableEntry, addr
  .dh addr & 0xFFFF
.endmacro

.create DATA_FILE, 0x0000

// 0x0000-0x0027: Overlay Table
overlayInfo0: // Main overlay.
  OverlayEntry orga(Overlay0Address), orga(Overlay0End), Overlay0Address
overlayInfo1: // Vector Division overlay.
  OverlayEntry orga(Overlay1Address), orga(Overlay1End), Overlay1Address
overlayInfo2: // Clipping overlay.
  OverlayEntry orga(Overlay2Address), orga(Overlay2End), Overlay2Address
overlayInfo3: // Finished overlay.
  OverlayEntry orga(Overlay3Address), orga(Overlay3End), Overlay3Address
overlayInfo4: // Lighting overlay. Removed in F3DDKR.
  OverlayEntry 0, 1, Overlay4Address

// 0x0028-0x009F: ??
.dw 0x0FFAF006
.dw 0x7FFF0000
.dw 0x00000001
.dw 0x0002FFFF
.dw 0x40000004
.dw 0x06330200
.dw 0x7FFFFFF8
.dw 0x00080040
.dw 0x00208000
.dw 0x01CCCCCC
.dw 0x0001FFFF
.dw 0x00010001
.dw 0x0001FFFF
.dw 0x00010001
.dw 0x00020002
.dw 0x00020002

// 0x0068
.dw 0x00020002
.dw 0x00020002

data0070:
.dw 0x00010000

// 0x0074
.dh 0x0000
// 0x0076
.dh 0x0001

// 0x0078
.dw 0x00000001
.dw 0x00000001
.dw 0x00010000
.dw 0x0000FFFF
.dw 0x00000001
.dw 0x0000FFFF
.dw 0x00000000
.dw 0x0001FFFF
.dw 0x00000000
.dw 0x00010001

// 0x00A0-0x00A1
lightEntry:
  jumpTableEntry load_lighting

// 0x00A2-0x00A3: ??
.dh 0x7FFF

// 0x00A4-0x00B3: ??
.dw 0x571D3A0C
.dw 0x00010002
.dw 0x01000200
.dw 0x40000040

// 0x00B4
.dh 0x0000

// 0x00B6-0x00B7
taskDoneEntry:
  jumpTableEntry overlay_3_entry

// 0x00B8
lower24Mask:
.dw 0x00FFFFFF

// Operation Types
operationJumpTable:
  jumpTableEntry dispatch_dma  // cmds 0x00-0x3f
spNoopEntry:
  jumpTableEntry SP_NOOP // cmds 0x40-0x7f
  jumpTableEntry dispatch_imm  // cmds 0x80-0xbf
  jumpTableEntry dispatch_rdp  // cmds 0xc0-0xff
  
// See https://hack64.net/wiki/doku.php?id=f3ddkr for more info about these commands.

// DMA operations
dmaJumpTable:
  jumpTableEntry SP_NOOP     // 0x00
  jumpTableEntry dma_MTX     // 0x01
  jumpTableEntry SP_NOOP     // 0x02
  jumpTableEntry dma_MOVEMEM // 0x03
  jumpTableEntry dma_VTX     // 0x04
  jumpTableEntry dkr_TRIN    // 0x05, Added to F3DDKR. DMAs up to 16 triangles.
  jumpTableEntry dma_DL      // 0x06
  jumpTableEntry dkr_DMADL   // 0x07, Added to F3DDKR. DMAs a fixed-size display list directly to the RDP.
  jumpTableEntry SP_NOOP     // 0x08
  jumpTableEntry SP_NOOP     // 0x09

// 0x00D8, Immediate operations
immediateJumpTableBase equ (immediateJumpTable - ((0xB2 << 1) & 0xFE))
  jumpTableEntry imm_UNKNOWN
immediateJumpTable:
  jumpTableEntry imm_RDPHALF_CONT      // 0xB2
  jumpTableEntry imm_RDPHALF_2         // 0xB3
  jumpTableEntry imm_RDPHALF_1         // 0xB4
  jumpTableEntry SP_NOOP               // 0xB5?
  jumpTableEntry imm_CLEARGEOMETRYMODE // 0xB6
  jumpTableEntry imm_SETGEOMETRYMODE   // 0xB7
  jumpTableEntry imm_ENDDL             // 0xB8
  jumpTableEntry imm_SETOTHERMODE_L    // 0xB9
  jumpTableEntry imm_SETOTHERMODE_H    // 0xBA
  jumpTableEntry imm_TEXTURE           // 0xBB
  jumpTableEntry imm_MOVEWORD          // 0xBC
  jumpTableEntry imm_POPMTX            // 0xBD
  jumpTableEntry SP_NOOP //imm_CULLDL  // 0xBE
  jumpTableEntry imm_TRI1              // 0xBF

// 0x00F6, Label constants
labelLUT:
  jumpTableEntry found_in
foundOutEntry:
  jumpTableEntry found_out
  jumpTableEntry found_first_in
  jumpTableEntry found_first_out
clipDrawEntry:
  jumpTableEntry clip_draw_loop
performClipEntry:
  jumpTableEntry perform_clip
nextClipEntry:
  jumpTableEntry next_clip
DMAWaitEntry:
  jumpTableEntry dma_wait_dl
  
data0106:
.dh 0x0000

// 0x0108: DRAM pointer
dramPtr:
.dw 0x00000000
.dh 0x0000     // 0x010C: RDPHALF_2

.dh 0x0000

// 0x0110: display list stack size
displayListStackSize:
.dh 0x0000
.dh 0xFFFF     // 0x112: RDPHALF_1

.dw 0x00000000 // 0x114: geometrymode (bit 1 is texture ON)
.dw 0xEF080CFF // 0x118: othermode
.dw 0x00000000 // 0x11C
.dw 0x00000000 // 0x120: texture max mipmap levels, tile descriptor enable/disable
.dh 0x0000     // 0x124: texture scaling factor S axis (horizontal) U16 fraction
.dh 0x0000     // 0x126: texture scaling factor T axis (vertical)
.dw 0x00000000 // 0x128: some dpc dma address state

numLights:
.dw 0x80000040 // 0x12C: num lights, bit 31 = needs init, bits 11:0 = (num_lights+1)*32
.dw 0x00000000 // 0x130: dram stack pointer 1
.dw 0x00000000 // 0x134: dram stack pointer modelview matrices

data0138:
.dw 0x40004000 // 0x138: txtatt (unused?)
.dw 0x00000000
.dw 0x00000000
data0144:
.dw 0x00000000
data0148:
.dh 0x0000
.dh 0x0000
.dw 0x00000000

// 0x0150
.dw 0x00000000
.dw 0x00000000
.dw 0x00000000
.dw 0x00000000

// 0x0160: RSP memory segment table?
segmentTable:
.fill 0x30, 0

// 0x0190: ?
jumpTableEntry ovl0_04001750
.dh 0x0000
.dw 0x00000000
.dw 0x00000000
.dw 0x00000000

// 0x01A0

// Lights
//.dw 0x80000000
//.dw 0x80000000
//.dw 0x00000000
//.dw 0x00000000

lookAtY:
//.dw 0x00800000, 0x00800000, 0x7F000000, 0x00000000
//.dw 0x00000000, 0x00000000, 0x00000000, 0x00000000

lookAtX: 
//.dw 0x00000000, 0x00000000, 0x007F0000, 0x00000000
//.dw 0x00000000, 0x00000000, 0x00000000, 0x00000000

// 0x01A0: DMEM table
dmemTableOffset equ (dmemTable - 0x80)
dmemTable:
  .dh viewport, 0, 0, 0, 0, 0, 0, 0
  .dh 0, 0, 0, data0138, 0, 0, 0, mpMatrix
  .dh data0144, data0070, segmentTable, fogFactors, data0148, pointsBuffer
  .dh 0, 0
  
// Viewport (0x010 bytes)
viewport:
.dw 0x00000000, 0x00000000, 0x00000000, 0x00000000

// fog factors (three 16-bit integers: mul, add, min)
fogFactors:
.dh 0x0100, 0x0000, 0x00FF

// display list stack (return addresses)
displayListStack: // this is not 4-byte aligned
.fill 0x2a, 0

// 3 matrices
mpMatrix:
.fill 0xC0, 0

pointsBuffer:
.fill 0x280, 0

inputDisplayList:
.fill 0x140, 0

inputData:
.fill (0x800 - 0x690), 0

.close // DATA_FILE

// uninitialized variables
.definelabel setupTemp, 0x08E0
.definelabel data0914, 0x0914
.definelabel data0918, 0x0918
.definelabel data091c, 0x091C
.definelabel data0920, 0x0920
.definelabel clipTemp, 0x0970
.definelabel data0972, 0x0972
.definelabel data0974, 0x0974
.definelabel data0976, 0x0976
.definelabel rdpOutput, 0x09E0
.definelabel scratchSpace, 0x0DE0
.definelabel data0DE4, 0x0DE4
.definelabel data0DE8, 0x0DE8

.create CODE_FILE, 0x04001080

// Overlay 0
Overlay0Address:
    j ovl0_040017f0
     addi $29, $zero, 0x110
    jal segmented_to_physical
     add $19, $24, $zero
    add $20, $zero, $22
    jal dma_read_write
     addi $17, $zero, 0x0

// $1 = most significant 2 bits of cmd byte << 1
// $25 = first command word
dispatch_task:
    lh $2, 0xbc($1)
    jr $2
     srl $2, $25, 23
     
SP_NOOP:
    mfc0 $2, SP_STATUS
    andi $2, $2, 0x80
    bne $2, $zero, ovl0_040010cc
     lh $21, 0x1e($zero)
ovl0_040010b8:
    bgtz $28, read_next_task_entry
     nop
    j load_display_list_dma
     lh $31, 0x104($zero)
ovl0_040010c8:
    lh $21, 0xb6($zero)
ovl0_040010cc:
    j load_overlay
     ori $30, $zero, 0x18

load_display_list_dma:
    addi $28, $zero, 0x140
    add $21, $zero, $31
    addi $20, $zero, 0x6d0
    add $19, $zero, $26
    addi $18, $zero, 0x13f
    jal dma_read_write
     addi $17, $zero, 0x0
    jr $21
     addi $27, $zero, 0x6d0

// load overlay into IMEM
// $30 = offset into overlay table
// $21 = return address
load_overlay_fcn:
    add $21, $zero, $31
load_overlay:
    lw $19, 0x0($30)
    lh $18, 0x4($30)
    lh $20, 0x6($30)
    jal dma_read_write
     addi $17, $zero, 0x0
    jal wait_while_dma_busy
     nop
    jr $21

segmented_to_physical:
     lw $11, 0xb8($zero)
    srl $12, $19, 22
    andi $12, $12, 0x3c
    and $19, $19, $11
    add $13, $zero, $12
    lw $12, 0x160($13)
    jr $ra
     add $19, $19, $12

// $20 = SP_MEM address
// $19 = DRAM address
// $18 = length - 1
// $17 = 1:write, 0:read
dma_read_write:
@@SP_DMA_FULL:
    mfc0 $11, SP_DMA_FULL
    bne $11, $zero, @@SP_DMA_FULL
     nop
    mtc0 $20, SP_MEM_ADDR
    bgtz $17, @@dma_write
     mtc0 $19, SP_DRAM_ADDR
    jr $ra
     mtc0 $18, SP_RD_LEN
@@dma_write:
    jr $ra
     mtc0 $18, SP_WR_LEN

wait_while_dma_busy:
    mfc0 $11, SP_DMA_BUSY
    bne $11, $zero, wait_while_dma_busy
     nop
    jr $ra
     nop

.if METHOD == "XBUS"
ovl0_04001178:  // sends stuff to RDP
    addi $19, $zero, 0xe10
    add $20, $23, $18
    sub $19, $19, $20
    bgez $19, ovl0_040011ac
     nop
ovl0_0400118c:
    mfc0 $19, DPC_STATUS
    andi $19, $19, 0x400
    bne $19, $zero, ovl0_0400118c
ovl0_04001198:
     mfc0 $19, DPC_CURRENT
    addi $23, $zero, 0xa10
    beq $19, $23, ovl0_04001198
     nop
    mtc0 $23, DPC_START
ovl0_040011ac:
    mfc0 $19, DPC_CURRENT
    sub $20, $23, $19
    bgez $20, ovl0_040011c8
     add $20, $23, $18
    sub $19, $20, $19
    bgez $19, ovl0_040011ac
     nop
ovl0_040011c8:
    jr $ra
     nop
ovl0_040011d0:
    jr $ra
     mtc0 $23, DPC_END
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
.elseif METHOD == "FIFO"
ovl0_04001178:  // sends stuff to RDP
	add $21, $zero, $31
    lw $19, 0x18($29)
    addi $18, $23, 0xf5f0
    lw $23, 0x44($29)
    blez $18, ovl0_040011f4
     add $20, $19, $18
    sub $20, $23, $20
    bgez $20, ovl0_040011b8
ovl0_04001198:
     mfc0 $20, DPC_STATUS
    andi $20, $20, 0x400
    bne $20, $zero, ovl0_04001198
ovl0_040011a4:
     mfc0 $23, DPC_CURRENT
    lw $19, 0x40($29)
    beq $23, $19, ovl0_040011a4
     nop
    mtc0 $19, DPC_START
ovl0_040011b8:
    mfc0 $23, DPC_CURRENT
    sub $20, $19, $23
    bgez $20, ovl0_040011d4
     add $20, $19, $18
    sub $20, $20, $23
    bgez $20, ovl0_040011b8
     nop
ovl0_040011d4:
    add $23, $19, $18
    addi $18, $18, 0xffff
    addi $20, $zero, 0xa10
    jal dma_read_write
     addi $17, $zero, 0x1
    jal wait_while_dma_busy
     sw $23, 0x18($29)
    mtc0 $23, DPC_END
ovl0_040011f4:
    jr $21
     addi $23, $zero, 0xa10
.elseif METHOD == "DRAM_DUMP"
ovl0_04001178:
    lw $19, 0x18($29)
    addi $20, $zero, 0xa10
    lw $17, 0x44($29)
    sub $18, $23, $20
    add $17, $17, $18
    sw $17, 0x44($29)
    addi $18, $18, 0xffff
    bltz $18, ovl0_040011ac
     add $21, $zero, $31
    jal dma_read_write
     addi $17, $zero, 0x1
    jal wait_while_dma_busy
     nop
ovl0_040011ac:
    addi $23, $zero, 0xa10
    add $19, $19, $18
    addi $19, $19, 0x1
    jr $21
     sw $19, 0x18($29)
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
.endif

// codes 0x80-0xBF
// $2 = immediate cmd byte << 1
dispatch_imm:
    andi $2, $2, 0xfe
    lh $2, (immediateJumpTableBase)($2)
    jr $2
     lbu $1, -0x01($27)
     
imm_TRI1:
    j SP_NOOP
     nop
     
imm_POPMTX:
    j SP_NOOP
     nop
     
imm_MOVEWORD:
    lbu $1, 0xfffb($27)
    lhu $2, 0xfff9($27)
    lh $5, 0x1be($1)
    add $5, $5, $2
    j SP_NOOP
     sw $24, 0x0($5)
     
imm_TEXTURE:
    sw $25, 0x10($29)
    sw $24, 0x14($29)
    lh $2, 0x6($29)
    andi $2, $2, 0xfffd
    andi $3, $25, 0x1
    sll $3, $3, 1
    or $2, $2, $3
    j SP_NOOP
     sh $2, 0x6($29)

imm_SETOTHERMODE_H:
    j ovl0_04001260
     addi $7, $29, 0x8
imm_SETOTHERMODE_L:
    addi $7, $29, 0xc
ovl0_04001260:
    lw $3, 0x0($7)
    addi $8, $zero, 0xffff
    lbu $5, 0xfffb($27)
    lbu $6, 0xfffa($27)
    addi $2, $zero, 0x1
    sllv $2, $2, $5
    addi $2, $2, 0xffff
    sllv $2, $2, $6
    xor $2, $2, $8
    and $2, $2, $3
    or $3, $2, $24
    sw $3, 0x0($7)
    lw $25, 0x8($29)
    j ovl0_0400131c
     lw $24, 0xc($29)
     
// imm_CULLDL was removed.

imm_ENDDL:
    lb $2, 0x0($29)
    addi $2, $2, 0xfffc
    bltz $2, ovl0_040010c8
     addi $3, $2, 0x1e6
    lw $26, 0x0($3)
    sb $2, 0x0($29)
    j SP_NOOP
     addi $28, $zero, 0x0

imm_SETGEOMETRYMODE:
    lw $2, 0x4($29)
    or $2, $2, $24
    j SP_NOOP
     sw $2, 0x4($29)

imm_CLEARGEOMETRYMODE:
    lw $2, 0x4($29)
    addi $3, $zero, -1
    xor $3, $3, $24
    and $2, $2, $3
    j SP_NOOP
     sw $2, 0x4($29)

imm_RDPHALF_1:
    j SP_NOOP
     sh $24, 0x2($29)
imm_RDPHALF_2:
    j ovl0_040010b8
     sw $24, 0xfffc($29)
imm_UNKNOWN:     
    ori $2, $zero, 0x0
imm_RDPHALF_CONT:
    j ovl0_0400131c
     lw $25, 0xfffc($29)

// codes 0xC0-0xFF
dispatch_rdp:
    sra $2, $25, 24
    addi $2, $2, 0x3
    bltz $2, ovl0_0400131c
     addi $2, $2, 0x18
    jal segmented_to_physical
     add $19, $24, $zero
    add $24, $19, $zero
ovl0_0400131c:
.if METHOD == "XBUS"
    jal ovl0_04001178
     addi $18, $zero, 0x8
.endif
    sw $25, 0x0($23)
    sw $24, 0x4($23)
.if METHOD == "XBUS"
    jal ovl0_040011d0
.elseif METHOD == "FIFO" || METHOD == "DRAM_DUMP"
    jal ovl0_04001178
.endif
     addi $23, $23, 0x8
    bgtz $2, SP_NOOP
     nop
    j ovl0_040010b8

dispatch_dma:
     andi $2, $2, 0x1fe
    lh $2, 0xc4($2)
    jal wait_while_dma_busy
     lbu $1, 0xfff9($27)
    jr $2
     andi $6, $1, 0x1

dma_MTX:
    sw $1, 0x148($zero)
    addi $20, $1, 0x210
    lqv $v26[0], 0x30($22)
    lqv $v28[0], 0x10($22)
    lqv $v27[0], 0x20($22)
    sqv $v26[0], 0x30($20)
    lqv $v29[0], 0x0($22)
    sqv $v28[0], 0x10($20)
    sqv $v27[0], 0x20($20)
    sqv $v29[0], 0x0($20)
    j SP_NOOP
     addi $19, $3, 0x10
ovl0_04001388: // Unused? Doesn't seem to ever get here.
    vmudh $v5, $v31, $v31[0]
    addi $18, $1, 0x8
ovl0_04001390:
    ldv $v3[0], 0x0($2)
    ldv $v4[0], 0x20($2)
    lqv $v1[0], 0x0($1)
    lqv $v2[0], 0x20($1)
    ldv $v3[8], 0x0($2)
    ldv $v4[8], 0x20($2)
    vmadl $v6, $v4, $v2[0h]
    addi $1, $1, 0x2
    vmadm $v6, $v3, $v2[0h]
    addi $2, $2, 0x8
    vmadn $v6, $v4, $v1[0h]
    vmadh $v5, $v3, $v1[0h]
    bne $1, $18, ovl0_04001390
     vmadn $v6, $v31, $v31[0]
    addi $2, $2, 0xffe0
    addi $1, $1, 0x8
    sqv $v5[0], 0x0($3)
    sqv $v6[0], 0x20($3)
    bne $3, $19, ovl0_04001388
     addi $3, $3, 0x10
    jr $ra
     nop

ovl0_040013e8:
    addi $8, $zero, 0x1d0
    lqv $v3[0], 0x50($zero)
    lsv $v19[0], 0x2($29)
    lh $3, 0x4($29)
    ldv $v0[0], 0x0($8)
    ldv $v1[0], 0x8($8)
    ldv $v0[8], 0x0($8)
    ldv $v1[8], 0x8($8)
    jr $ra
     vmudh $v0, $v0, $v3

load_mp_matrix:
    lw $8, 0x148($zero)
    addi $8, $8, 0x210
    ldv $v11[0], 0x18($8)
    ldv $v11[8], 0x18($8)
    ldv $v15[0], 0x38($8)
    ldv $v15[8], 0x38($8)
    ldv $v8[0], 0x0($8)
    ldv $v9[0], 0x8($8)
    ldv $v10[0], 0x10($8)
    ldv $v12[0], 0x20($8)
    ldv $v13[0], 0x28($8)
    ldv $v14[0], 0x30($8)
    ldv $v8[8], 0x0($8)
    ldv $v9[8], 0x8($8)
    ldv $v10[8], 0x10($8)
    ldv $v12[8], 0x20($8)
    ldv $v13[8], 0x28($8)
    jr $ra
     ldv $v14[8], 0x30($8)

dma_MOVEMEM:
    lqv $v0[0], 0x0($22)
    lh $5, 0x120($1)
    j SP_NOOP
     sqv $v0[0], 0x0($5)

dma_VTX:
    lh $8, 0xbe($zero)
    sh $8, 0x106($zero)
    srl $5, $1, 3
    addi $5, $5, 0x1
    andi $1, $1, 0x6
    add $22, $22, $1
    addi $1, $22, 0xa
    addi $9, $5, 0x0
    ldv $v2[0], 0x0($22)
    ldv $v2[8], 0x0($1)
    addi $7, $zero, 0x2d0
    beq $6, $zero, ovl0_040014a8
     nop
    j ovl0_040014ac
     lh $6, 0x14c($zero)
ovl0_040014a8:
    sh $5, 0x14c($zero)
ovl0_040014ac:
    sll $8, $6, 5
    sll $6, $6, 3
    add $8, $6, $8
    jal ovl0_040013e8
     add $7, $7, $8
    addi $18, $zero, 0x2d0
    ldv $v16[0], 0x0($18)
    ldv $v16[8], 0x0($18)
    ldv $v18[0], 0x8($18)
    ldv $v18[8], 0x8($18)
    lw $17, 0x144($zero)
    llv $v17[0], 0x14($29)
    jal load_mp_matrix
     llv $v17[8], 0x14($29)
ovl0_040014e4:
    lw $15, 0x6($22)
    vmudn $v28, $v12, $v2[0h]
    vmadh $v28, $v8, $v2[0h]
    vmadn $v28, $v13, $v2[1h]
    vmadh $v28, $v9, $v2[1h]
    lw $16, 0x6($1)
    vmadn $v28, $v14, $v2[2h]
    vmadh $v28, $v10, $v2[2h]
    vmadn $v28, $v15, $v31[1]
    vmadh $v29, $v11, $v31[1]
    beq $17, $zero, ovl0_04001520
     nop
    vaddc $v28, $v28, $v18
    vadd $v29, $v29, $v16
.if METHOD != "FIFO" // XBUS and DRAM_DUMP have this nop
    nop
.endif
ovl0_04001520:
    addi $22, $22, 0x14
    addi $1, $1, 0x14
ovl0_04001528:
    lsv $v21[0], 0x76($zero)
    vmudn $v20, $v28, $v21[0]
    vmadh $v21, $v29, $v21[0]
    vch $v3, $v29, $v29[3h]
    vcl $v3, $v28, $v28[3h]
    cfc2 $13, $vcc
    vch $v3, $v29, $v21[3h]
    vcl $v3, $v28, $v20[3h]
    andi $8, $13, 0x707
    andi $13, $13, 0x7070
    sll $8, $8, 4
    sll $13, $13, 16
    or $13, $13, $8
    cfc2 $14, $vcc
    andi $8, $14, 0x707
    vadd $v21, $v29, $v31[0]
    andi $14, $14, 0x7070
    vadd $v20, $v28, $v31[0]
    sll $14, $14, 12
    vmudl $v28, $v28, $v19[0]
    or $8, $8, $14
    vmadm $v29, $v29, $v19[0]
    or $8, $8, $13
    vmadn $v28, $v31, $v31[0]
    sh $8, 0x24($7)
    jal ovl1_04001000
     nop
    vge $v6, $v27, $v31[0]
    sdv $v21[0], 0x0($7)
    vmrg $v6, $v27, $v30[0]
    sdv $v20[0], 0x8($7)
    vmudl $v5, $v20, $v26[3h]
    vmadm $v5, $v21, $v26[3h]
    vmadn $v5, $v20, $v6[3h]
    vmadh $v4, $v21, $v6[3h]
    addi $9, $9, 0xffff
    vmudl $v5, $v5, $v19[0]
    vmadm $v4, $v4, $v19[0]
    vmadn $v5, $v31, $v31[0]
    andi $12, $3, 0x1
    ldv $v2[0], 0x0($22)
    vmudh $v7, $v1, $v31[1]
    ldv $v2[8], 0x0($1)
    vmadn $v7, $v5, $v0
    ldv $v29[0], 0x28($zero)
    vmadh $v6, $v4, $v0
    ldv $v29[8], 0x28($zero)
    vmadn $v7, $v31, $v31[0]
    vge $v6, $v6, $v29[1q]
    sw $15, 0x10($7)
    beq $12, $zero, ovl0_04001620
     vlt $v6, $v6, $v29[0q]
    lqv $v3[0], 0x1e0($zero)
    vmudn $v5, $v5, $v3[0]
    vmadh $v4, $v4, $v3[0]
    vadd $v4, $v4, $v3[1]
    vge $v4, $v4, $v31[0]
    vlt $v4, $v4, $v3[2]
    sbv $v4[5], 0x13($7)
    sw $16, 0x18($7)
    sbv $v4[13], 0x1b($7)
    lw $16, 0x18($7)
ovl0_04001620:
    sdv $v6[0], 0x18($7)
    ssv $v7[4], 0x1e($7)
    ssv $v27[6], 0x20($7)
    ssv $v26[6], 0x22($7)
    slv $v18[0], 0x14($7)
    blez $9, ovl0_04001668
     addi $9, $9, 0xffff
    sdv $v21[8], 0x28($7)
    sdv $v20[8], 0x30($7)
    slv $v18[8], 0x3c($7)
    sw $16, 0x38($7)
    sdv $v6[8], 0x40($7)
    ssv $v7[12], 0x46($7)
    ssv $v27[14], 0x48($7)
    ssv $v26[14], 0x4a($7)
    sw $8, 0x4c($7)
    addi $7, $7, 0x50
    bgtz $9, ovl0_040014e4
ovl0_04001668:
     lh $8, 0x106($zero)
    jr $8
     nop
dkr_TRIN:
    srl $5, $1, 4
    addi $5, $5, 0x1
    ori $6, $zero, 0x810
    addi $7, $zero, 0xfffd
    lw $10, 0x114($zero)
    andi $11, $1, 0x1
    and $10, $10, $7
    sll $11, $11, 1
    or $10, $10, $11
    sw $10, 0x114($zero)
ovl0_0400169c:
    sh $5, 0x194($zero)
    sh $6, 0x196($zero)
    mfc0 $9, SP_STATUS
    andi $9, $9, 0x80
    bne $9, $zero, ovl0_040010cc
     lh $21, 0x1e($zero)
    blez $5, ovl0_04001764
     lbu $9, 0x0($6)
    addi $11, $zero, 0xdfff
    xori $7, $9, 0x40
    lw $10, 0x114($zero)
    andi $7, $7, 0x40
    sll $7, $7, 7
    and $10, $10, $11
    or $10, $10, $7
    sw $10, 0x114($zero)
    lbu $1, 0x1($6)
    lbu $2, 0x2($6)
    lbu $3, 0x3($6)
    sll $7, $1, 3
    sll $1, $1, 5
    add $1, $1, $7
    sll $7, $2, 3
    sll $2, $2, 5
    add $2, $2, $7
    sll $7, $3, 3
    sll $3, $3, 5
    add $3, $3, $7
    addi $1, $1, 0x2d0
    addi $2, $2, 0x2d0
    addi $3, $3, 0x2d0
    sw $1, 0xe10($zero)
    sw $2, 0xe14($zero)
    sw $3, 0xe18($zero)
    lw $4, 0xe10($zero)
    lw $8, 0x4($6)
    sw $8, 0x14($1)
    lw $8, 0x8($6)
    sw $8, 0x14($2)
    lw $8, 0xc($6)
    sw $8, 0x14($3)
    sh $6, 0x180($zero)
    sh $5, 0x182($zero)
    j ovl0_040019f8
     lh $30, 0x190($zero)
ovl0_04001750:
    lh $6, 0x180($zero)
    lh $5, 0x182($zero)
    addi $5, $5, 0xffff
    j ovl0_0400169c
     addi $6, $6, 0x10
ovl0_04001764:
    j SP_NOOP
     nop
dkr_DMADL:
    ori $2, $zero, 0x810
ovl0_04001770:
.if METHOD == "XBUS"
    jal ovl0_04001178
     ori $18, $zero, 0x8
.endif
    lw $25, 0x0($2)
    lw $24, 0x4($2)
    sw $25, 0x0($23)
    sw $24, 0x4($23)
.if METHOD == "XBUS"
    jal ovl0_040011d0
.elseif METHOD == "FIFO" || METHOD == "DRAM_DUMP"
    jal ovl0_04001178
.endif
     addi $23, $23, 0x8
    addi $1, $1, 0xffff
    bne $1, $zero, ovl0_04001770
     addi $2, $2, 0x8
    j SP_NOOP
     nop

dma_DL:
    bgtz $1, ovl0_040017c4
     lb $2, 0x0($29)
    addi $4, $2, 0xffdc
    bgtz $4, SP_NOOP
     addi $3, $2, 0x1e6
    addi $2, $2, 0x4
    sw $26, 0x0($3)
    sb $2, 0x0($29)
ovl0_040017c4:
    jal segmented_to_physical
     add $19, $24, $zero
    add $26, $19, $zero
    j SP_NOOP
     addi $28, $zero, 0x0

// Overlays 2-4 will overwrite the following code
ovl0_040017d8:
    ori $30, $zero, overlayInfo2
    beq $zero, $zero, load_overlay
     lh $21, performClipEntry

load_lighting: // This goes unused.
    ori $30, $zero, overlayInfo4
    beq $zero, $zero, load_overlay
     lh $21, lightEntry

ovl0_040017f0:
    ori $2, $zero, 0x2800
    mtc0 $2, SP_STATUS
    lqv $v31[0], 0x30($zero)
    lqv $v30[0], 0x40($zero)
    lw $4, 0xfc4($zero)
    andi $4, $4, 0x1
    bne $4, $zero, ovl0_0400189c
     nop
    lw $23, 0x28($1)
    lw $3, 0x2c($1)
.if METHOD == "XBUS"
    sw $zero, 0x18($29)
    sw $3, 0x30($29)
    addi $4, $zero, 0x2
    addi $23, $zero, 0x1000
    mtc0 $4, DPC_STATUS
    mtc0 $23, DPC_START
    mtc0 $23, DPC_END
.elseif METHOD == "FIFO"
    sw $23, 0x40($29)
    sw $3, 0x44($29)
    mfc0 $4, DPC_STATUS
    andi $4, $4, 0x1
    bne $4, $zero, ovl0_04001844
     mfc0 $4, DPC_END
    sub $23, $23, $4
    bgtz $23, ovl0_04001844
     mfc0 $5, DPC_CURRENT
    beq $5, $zero, ovl0_04001844
     nop
    beq $5, $4, ovl0_04001844
     nop
    j ovl0_04001860
     ori $3, $4, 0x0
ovl0_04001844:
    mfc0 $4, DPC_STATUS
    andi $4, $4, 0x400
    bne $4, $zero, ovl0_04001844
     addi $4, $zero, 0x1
    mtc0 $4, DPC_STATUS
    mtc0 $3, DPC_START
    mtc0 $3, DPC_END
ovl0_04001860:
    sw $3, 0x18($29)
    addi $23, $zero, 0xa10
.elseif METHOD == "DRAM_DUMP"
    sw $23, 0x18($29)
    sw $3, 0x30($29)
    addi $4, $zero, 0x1
    mtc0 $4, DPC_STATUS
    addi $23, $zero, 0xa10
.endif
    lw $5, 0x10($1)
    lw $2, 0x8($zero)
    lw $3, 0x10($zero)
    lw $4, 0x20($zero)
    lw $6, 0x18($zero)
    add $2, $2, $5
    add $3, $3, $5
    add $4, $4, $5
    add $6, $6, $5
    sw $2, 0x8($zero)
    sw $3, 0x10($zero)
    sw $4, 0x20($zero)
    sw $6, 0x18($zero)
    jal load_overlay_fcn
     addi $30, $zero, 0x8
    jal load_display_list_dma
     lw $26, 0x30($1)
    lw $2, 0x20($1)
    sw $2, 0x20($29)
    sw $2, 0x24($29)
    addi $2, $2, 0x280
    sw $2, 0x4c($29)
    lw $2, 0xfff8($zero)
    sw $2, 0x108($zero)
    j dma_wait_dl
     nop
ovl0_0400189c:
    jal load_overlay_fcn
     addi $30, $zero, 0x8
    lw $23, 0x920($zero)
    lw $28, 0x914($zero)
    lw $27, 0x918($zero)
    lw $26, 0x91c($zero)
    lh $5, 0x194($zero)
    bgtz $5, ovl0_0400169c
     lh $6, 0x196($zero)
    j SP_NOOP
     nop

// bunch of nops
.if METHOD == "XBUS"
    .fill 76*4, 0 // 76 nops
.elseif METHOD == "FIFO"
    .fill 59*4, 0 // 59 nops
.elseif METHOD == "DRAM_DUMP"
    .fill 78*4, 0 // 78 nops
.endif

// from G_TRI1
ovl0_040019f8:
    lh $11, 0x24($3)
    lh $8, 0x24($2)
    lh $9, 0x24($1)
    and $12, $11, $8
    or $11, $11, $8
    and $12, $12, $9
    andi $12, $12, 0x7070
    beq $12, $zero, ovl0_04001a20
     or $11, $11, $9
    jr $30
ovl0_04001a20:
     andi $11, $11, 0x4343
    bne $11, $zero, ovl0_040017d8
ovl0_04001a28:
     lw $13, 0x4($29)
    lsv $v21[0], 0x2($29)
    addi $8, $zero, 0x910
    llv $v13[0], 0x18($1)
    llv $v14[0], 0x18($2)
    llv $v15[0], 0x18($3)
    lsv $v5[0], 0x6($1)
    vsub $v10, $v14, $v13
    lsv $v6[0], 0xe($1)
    vsub $v9, $v15, $v13
    lsv $v5[2], 0x6($2)
    vsub $v12, $v13, $v14
    lsv $v6[2], 0xe($2)
    lsv $v5[4], 0x6($3)
    lsv $v6[4], 0xe($3)
    vmudh $v16, $v9, $v10[1]
    lh $9, 0x1a($1)
    vsar $v18, $v18, $v18[1]
    lh $10, 0x1a($2)
    vsar $v17, $v17, $v17[0]
    lh $11, 0x1a($3)
    vmudh $v16, $v12, $v9[1]
    andi $15, $13, 0x2000
    vsar $v20, $v20, $v20[1]
    andi $14, $13, 0x1000
    vsar $v19, $v19, $v19[0]
    beq $14, $zero, ovl0_04001aa0
     nop
    sra $14, $15, 1
    and $15, $zero, $zero
ovl0_04001aa0:
    addi $12, $zero, 0x0
ovl0_04001aa4:
    slt $7, $10, $9
    blez $7, ovl0_04001ac8
     add $7, $10, $zero
    add $10, $9, $zero
    add $9, $7, $zero
    addu $7, $2, $zero
    addu $2, $1, $zero
    addu $1, $7, $zero
    xori $12, $12, 0x1
ovl0_04001ac8:
    vaddc $v28, $v18, $v20
    slt $7, $11, $10
    vadd $v29, $v17, $v19
    blez $7, ovl0_04001af8
     add $7, $11, $zero
    add $11, $10, $zero
    add $10, $7, $zero
    addu $7, $3, $zero
    addu $3, $2, $zero
    addu $2, $7, $zero
    j ovl0_04001aa4
     xori $12, $12, 0x1
ovl0_04001af8:
    vlt $v27, $v29, $v31[0]
    llv $v15[0], 0x18($3)
    vor $v26, $v29, $v28
    llv $v14[0], 0x18($2)
    llv $v13[0], 0x18($1)
    blez $12, ovl0_04001b20
     vsub $v4, $v15, $v14
    vmudn $v28, $v28, $v31[3]
    vmadh $v29, $v29, $v31[3]
    vmadn $v28, $v31, $v31[0]
ovl0_04001b20:
    vsub $v10, $v14, $v13
    mfc2 $17, $v27[0]
    vsub $v9, $v15, $v13
    mfc2 $16, $v26[0]
    sra $17, $17, 31
    vmov $v29[3], $v29[0]
    and $15, $15, $17
    vmov $v28[3], $v28[0]
    vmov $v4[2], $v10[0]
    beq $16, $zero, ovl0_04001f5c
     xori $17, $17, 0xffff
    vlt $v27, $v29, $v31[0]
    and $14, $14, $17
    vmov $v4[3], $v10[1]
    or $16, $15, $14
    vmov $v4[4], $v9[0]
    bgtz $16, ovl0_04001f5c
     vmov $v4[5], $v9[1]
    mfc2 $7, $v27[0]
    jal ovl1_04001000
     addi $6, $zero, 0x80
    bltz $7, ovl0_04001b80
     lb $5, 0x7($29)
    addi $6, $zero, 0x0
ovl0_04001b80:
    vmudm $v9, $v4, $v31[4]
    vmadn $v10, $v31, $v31[0]
    vrcp $v8[1], $v4[1]
    vrcph $v7[1], $v31[0]
    ori $5, $5, 0xc8
    lb $7, 0x12($29)
    vrcp $v8[3], $v4[3]
    vrcph $v7[3], $v31[0]
    vrcp $v8[5], $v4[5]
    vrcph $v7[5], $v31[0]
    or $6, $6, $7
.if METHOD == "XBUS"
    jal ovl0_04001178
     addi $18, $zero, 0xb0
.endif
    vmudl $v8, $v8, $v30[4]
    sb $5, 0x0($23)
    vmadm $v7, $v7, $v30[4]
    sb $6, 0x1($23)
    vmadn $v8, $v31, $v31[0]
    vmudh $v4, $v4, $v31[5]
    lsv $v12[0], 0x18($2)
    vmudl $v6, $v6, $v21[0]
    lsv $v12[4], 0x18($1)
    vmadm $v5, $v5, $v21[0]
    lsv $v12[8], 0x18($1)
    vmadn $v6, $v31, $v31[0]
    sll $7, $9, 14
    vmudl $v1, $v8, $v10[0q]
    vmadm $v1, $v7, $v10[0q]
    vmadn $v1, $v8, $v9[0q]
    vmadh $v0, $v7, $v9[0q]
    mtc2 $7, $v2[0]
    vmadn $v1, $v31, $v31[0]
    sw $3, 0x0($8)
    vmudl $v8, $v8, $v31[4]
    vmadm $v7, $v7, $v31[4]
    vmadn $v8, $v31, $v31[0]
    vmudl $v1, $v1, $v31[4]
    vmadm $v0, $v0, $v31[4]
    vmadn $v1, $v31, $v31[0]
    sh $11, 0x2($23)
    vand $v16, $v1, $v30[1]
    sh $9, 0x6($23)
    vmudm $v12, $v12, $v31[4]
    sw $2, 0x4($8)
    vmadn $v13, $v31, $v31[0]
    sw $1, 0x8($8)
    sh $10, 0x4($23)
    vcr $v0, $v0, $v30[6]
    ssv $v12[0], 0x8($23)
    vmudl $v11, $v16, $v2[0]
    ssv $v13[0], 0xa($23)
    vmadm $v10, $v0, $v2[0]
    ssv $v0[2], 0xc($23)
    vmadn $v11, $v31, $v31[0]
    ssv $v1[2], 0xe($23)
    andi $7, $5, 0x2
    addi $15, $8, 0x8
    addi $16, $8, 0x10
    vsubc $v3, $v13, $v11[1q]
    ssv $v0[10], 0x14($23)
    vsub $v9, $v12, $v10[1q]
    ssv $v1[10], 0x16($23)
    vsubc $v21, $v6, $v6[1]
    ssv $v0[6], 0x1c($23)
    vlt $v19, $v5, $v5[1]
    ssv $v1[6], 0x1e($23)
    vmrg $v20, $v6, $v6[1]
    ssv $v9[8], 0x10($23)
    vsubc $v21, $v20, $v6[2]
    ssv $v3[8], 0x12($23)
    vlt $v19, $v19, $v5[2]
    ssv $v9[4], 0x18($23)
    vmrg $v20, $v20, $v6[2]
    ssv $v3[4], 0x1a($23)
    addi $23, $23, 0x20
    blez $7, ovl0_04001d74
     vmudl $v20, $v20, $v30[5]
    lw $14, 0x0($15)
    vmadm $v19, $v19, $v30[5]
    lw $17, 0xfffc($15)
    vmadn $v20, $v31, $v31[0]
    lw $18, 0xfff8($15)
    llv $v9[0], 0x14($14)
    llv $v9[8], 0x14($17)
    llv $v22[0], 0x14($18)
    lsv $v11[0], 0x22($14)
    lsv $v12[0], 0x20($14)
    lsv $v11[8], 0x22($17)
    vmov $v9[2], $v30[0]
    lsv $v12[8], 0x20($17)
    vmov $v9[6], $v30[0]
    lsv $v24[0], 0x22($18)
    vmov $v22[2], $v30[0]
    lsv $v25[0], 0x20($18)
    vmudl $v6, $v11, $v20[0]
    vmadm $v6, $v12, $v20[0]
    ssv $v19[0], 0x44($8)
    vmadn $v6, $v11, $v19[0]
    ssv $v20[0], 0x4c($8)
    vmadh $v5, $v12, $v19[0]
    vmudl $v16, $v24, $v20[0]
    vmadm $v16, $v25, $v20[0]
    vmadn $v20, $v24, $v19[0]
    vmadh $v19, $v25, $v19[0]
    vmudm $v16, $v9, $v6[0h]
    vmadh $v9, $v9, $v5[0h]
    vmadn $v10, $v31, $v31[0]
    vmudm $v16, $v22, $v20[0]
    vmadh $v22, $v22, $v19[0]
    vmadn $v23, $v31, $v31[0]
    sdv $v9[8], 0x10($16)
    sdv $v10[8], 0x18($16)
    sdv $v9[0], 0x0($16)
    sdv $v10[0], 0x8($16)
    sdv $v22[0], 0x20($16)
    sdv $v23[0], 0x28($16)
    vabs $v9, $v9, $v9
    llv $v19[0], 0x10($16)
    vabs $v22, $v22, $v22
    llv $v20[0], 0x18($16)
    vabs $v19, $v19, $v19
    vge $v17, $v9, $v22
    vmrg $v18, $v10, $v23
    vge $v17, $v17, $v19
    vmrg $v18, $v18, $v20
ovl0_04001d74:
    slv $v17[0], 0x40($8)
    slv $v18[0], 0x48($8)
    andi $7, $5, 0x7
    blez $7, ovl0_04001f58
     vxor $v18, $v31, $v31
    luv $v25[0], 0x10($3)
    vadd $v16, $v18, $v30[5]
    luv $v15[0], 0x10($1)
    vadd $v24, $v18, $v30[5]
    andi $7, $13, 0x200
    vadd $v5, $v18, $v30[5]
    bgtz $7, ovl0_04001db4
     luv $v23[0], 0x10($2)
    luv $v25[0], 0x10($4)
    luv $v15[0], 0x10($4)
    luv $v23[0], 0x10($4)
ovl0_04001db4:
    vmudm $v25, $v25, $v31[7]
    vmudm $v15, $v15, $v31[7]
    vmudm $v23, $v23, $v31[7]
    ldv $v16[8], 0x18($8)
    ldv $v15[8], 0x10($8)
    ldv $v24[8], 0x28($8)
    ldv $v23[8], 0x20($8)
    ldv $v5[8], 0x38($8)
    ldv $v25[8], 0x30($8)
    lsv $v16[14], 0x1e($1)
    lsv $v15[14], 0x1c($1)
    lsv $v24[14], 0x1e($2)
    lsv $v23[14], 0x1c($2)
    lsv $v5[14], 0x1e($3)
    lsv $v25[14], 0x1c($3)
    vsubc $v12, $v24, $v16
    vsub $v11, $v23, $v15
    vsubc $v20, $v16, $v5
    vsub $v19, $v15, $v25
    vsubc $v10, $v5, $v16
    vsub $v9, $v25, $v15
    vsubc $v22, $v16, $v24
    vsub $v21, $v15, $v23
    vmudn $v6, $v10, $v4[3]
    vmadh $v6, $v9, $v4[3]
    vmadn $v6, $v22, $v4[5]
    vmadh $v6, $v21, $v4[5]
    vsar $v9, $v9, $v9[0]
    vsar $v10, $v10, $v10[1]
    vmudn $v6, $v12, $v4[4]
    vmadh $v6, $v11, $v4[4]
    vmadn $v6, $v20, $v4[2]
    vmadh $v6, $v19, $v4[2]
    vsar $v11, $v11, $v11[0]
    vsar $v12, $v12, $v12[1]
    vmudl $v6, $v10, $v26[3]
    vmadm $v6, $v9, $v26[3]
    vmadn $v10, $v10, $v27[3]
    vmadh $v9, $v9, $v27[3]
    vmudl $v6, $v12, $v26[3]
    vmadm $v6, $v11, $v26[3]
    vmadn $v12, $v12, $v27[3]
    sdv $v9[0], 0x8($23)
    vmadh $v11, $v11, $v27[3]
    sdv $v10[0], 0x18($23)
    vmudn $v6, $v12, $v31[1]
    vmadh $v6, $v11, $v31[1]
    vmadl $v6, $v10, $v1[5]
    vmadm $v6, $v9, $v1[5]
    vmadn $v14, $v10, $v0[5]
    sdv $v11[0], 0x28($23)
    vmadh $v13, $v9, $v0[5]
    sdv $v12[0], 0x38($23)
    vmudl $v28, $v14, $v2[0]
    sdv $v13[0], 0x20($23)
    vmadm $v6, $v13, $v2[0]
    sdv $v14[0], 0x30($23)
    vmadn $v28, $v31, $v31[0]
    vsubc $v18, $v16, $v28
    vsub $v17, $v15, $v6
    andi $7, $5, 0x4
    blez $7, ovl0_04001ebc
     andi $7, $5, 0x2
    addi $23, $23, 0x40
    sdv $v17[0], -0x40($23)
    sdv $v18[0], -0x30($23)
ovl0_04001ebc:
    blez $7, ovl0_04001ee8
     andi $7, $5, 0x1
    sdv $v17[8], 0x0($23)
    sdv $v18[8], 0x10($23)
    sdv $v9[8], 0x8($23)
    sdv $v10[8], 0x18($23)
    sdv $v11[8], 0x28($23)
    sdv $v12[8], 0x38($23)
    addi $23, $23, 0x40
    sdv $v13[8], -0x20($23)
    sdv $v14[8], -0x10($23)
ovl0_04001ee8:
    blez $7, ovl0_04001f58
     nop
    vmudn $v14, $v14, $v30[4]
    vmadh $v13, $v13, $v30[4]
    vmadn $v14, $v31, $v31[0]
    vmudn $v16, $v16, $v30[4]
    vmadh $v15, $v15, $v30[4]
    vmadn $v16, $v31, $v31[0]
    ssv $v13[14], 0x8($23)
    vmudn $v10, $v10, $v30[4]
    ssv $v14[14], 0xa($23)
    vmadh $v9, $v9, $v30[4]
    vmadn $v10, $v31, $v31[0]
    vmudn $v12, $v12, $v30[4]
    vmadh $v11, $v11, $v30[4]
    vmadn $v12, $v31, $v31[0]
    ssv $v9[14], 0x4($23)
    vmudl $v28, $v14, $v2[0]
    ssv $v10[14], 0x6($23)
    vmadm $v6, $v13, $v2[0]
    ssv $v11[14], 0xc($23)
    vmadn $v28, $v31, $v31[0]
    ssv $v12[14], 0xe($23)
    vsubc $v18, $v16, $v28
    vsub $v17, $v15, $v6
    addi $23, $23, 0x10
    ssv $v17[14], -0x10($23)
    ssv $v18[14], -0xe($23)
ovl0_04001f58:
.if METHOD == "XBUS"
    jal ovl0_040011d0
.elseif METHOD == "FIFO" || METHOD == "DRAM_DUMP"
    jal ovl0_04001178
.endif
ovl0_04001f5c:
     nop
    jr $30
     nop

Overlay0End:

// Overlay 1, Vector Division 
.headersize 0x04001000 - orga()
.definelabel Overlay1LoadStart, orga()
// reciprocal method, see RSP Programmers Guide page 79
// $v29[3]=s_int, $v28[3]=s_frac, $v29[7]=t_int, $v28[7]=t_frac
// out: $v27[3,7]=s,t int, $v26[3,7]=s,t frac
Overlay1Address:
ovl1_04001000:
    vrcph $v27[3], $v29[3]
    vrcpl $v26[3], $v28[3]
    vrcph $v27[3], $v29[7]
    vrcpl $v26[7], $v28[7]
    vrcph $v27[7], $v31[0]
    vmudn $v26, $v26, $v31[2] // 0002, << 1 since input is S15.16
    vmadh $v27, $v27, $v31[2]
    vmadn $v26, $v31, $v31[0]
    // $v27[3]=sres_int, $v26[3]=sres_frac, $v27[7]=tres_int, $v26[7]=tres_frac
    lqv   $v23[0], 0x60($zero)
    vxor  $v22, $v31, $v31 // (1/w)*w
    vmudl $v24, $v26, $v28
    vmadm $v24, $v27, $v28
    vmadn $v24, $v26, $v29
    vmadh $v25, $v27, $v29
    // $v24=frac, $v25=int, should be very close to 1.0
    vsubc $v24, $v22, $v24 // take 2.0-result (better rounding?)
    vsub  $v25, $v23, $v25
    vmudl $v22, $v26, $v24 // (2.0-(1/w)*w)*(1/w)
    vmadm $v23, $v27, $v24
    vmadn $v26, $v26, $v25
    vmadh $v27, $v27, $v25
    jr $ra
     nop

dma_wait_dl:
    jal wait_while_dma_busy
     addi $27, $zero, 0x6d0

read_next_task_entry:
    lw $25, 0x0($27)
    lw $24, 0x4($27)
    srl $1, $25, 29
    andi $1, $1, 0x6
    addi $26, $26, 0x8
    addi $27, $27, 0x8
    addi $28, $28, 0xfff8
    bgtz $1, dispatch_task
     andi $18, $25, 0x1ff
    addi $22, $zero, 0x810
Overlay1End:

// Overlay 2, Clipping
.if METHOD == "XBUS" || METHOD == "DRAM_DUMP"
    .headersize 0x040017d8 - orga()
.elseif METHOD == "FIFO"
    .headersize 0x040017c8 - orga()
.endif
Overlay2Address:

    b perform_clip
     sh $31, 0x158($zero)
    nop
    nop
    ori $30, $zero, 0x20
    b load_overlay
     lh $21, lightEntry // 0xa0($zero)
perform_clip:
    sh $3, clipTemp // 0x970($zero)
    sh $2, data0972 // 0x972($zero)
    sh $1, data0974 // 0x974($zero)
    sh $zero, data0976 // 0x976($zero)
    ori $7, $zero, 0xde8
    ori $30, $zero, clipTemp
    ori $6, $zero, 0xc
next_clip:
    or $5, $30, $30
    xori $30, $30, 0xf4
ovl2_04001818:
    beq $6, $zero, ovl2_040019c4
     lh $11, 0xa6($6)
    addi $6, $6, 0xfffe
    ori $17, $zero, 0x0
    or $18, $zero, $zero
found_in:
    ori $2, $5, 0x0
found_out:
    j ovl2_04001844
     addi $14, $30, 0x2
ovl2_04001838:
    and $8, $8, $11
    beq $8, $18, ovl2_04001874
     addi $2, $2, 0x2
ovl2_04001844:
    or $20, $10, $zero
    sh $10, 0x0($14)
    addi $14, $14, 0x2
ovl2_04001850:
    lh $10, 0x0($2)
    bne $10, $zero, ovl2_04001838
     lh $8, 0x24($10)
    addi $8, $17, 0xfffe
    bgtz $8, ovl2_04001850
     ori $2, $5, 0x0
    beq $8, $zero, ovl2_04001818
     nop
    j ovl2_040019f0
ovl2_04001874:
     xor $18, $18, $11
    lh $8, lo(labelLUT)($17)
    addi $17, $17, 0x2
    jr $8
     lh $8, 0x102($zero)
     
found_first_in:
    mtc2 $10, $v13[0]
    or $10, $20, $zero
    mfc2 $20, $v13[0]
    ori $14, $30, 0x0
    lh $8, 0xf8($zero)

found_first_out:
    sh $8, 0x106($zero)
    addi $7, $7, 0x28
    sh $7, 0x0($14)
    sh $zero, 0x2($14)
    ldv $v9[0], 0x0($10)
    ldv $v10[0], 0x8($10)
    ldv $v4[0], 0x0($20)
    ldv $v5[0], 0x8($20)
    sll $8, $6, 2
    ldv $v1[0], 0x70($8)
    vmudh $v0, $v1, $v31[3]
    vmudn $v12, $v5, $v1
    vmadh $v11, $v4, $v1
    vmadn $v12, $v31, $v31[0]
    vmadn $v28, $v10, $v0
    vmadh $v29, $v9, $v0
    vmadn $v28, $v31, $v31[0]
    vaddc $v26, $v28, $v28[0q]
    vadd $v27, $v29, $v29[0q]
    vaddc $v28, $v26, $v26[1h]
    vadd $v29, $v27, $v27[1h]
    mfc2 $8, $v29[6]
    vrcph $v7[3], $v29[3]
    vrcpl $v3[3], $v28[3]
    vrcph $v7[3], $v31[0]
    vmudn $v3, $v3, $v31[2]
    bgez $8, ovl2_04001914
     vmadh $v7, $v7, $v31[2]
    vmudn $v3, $v3, $v31[3]
    vmadh $v7, $v7, $v31[3]
ovl2_04001914:
    veq $v7, $v7, $v31[0]
    vmrg $v3, $v3, $v31[3]
    vmudl $v28, $v28, $v3[3]
    vmadm $v29, $v29, $v3[3]
    jal ovl1_04001000
     vmadn $v28, $v31, $v31[0]
    vaddc $v28, $v12, $v12[0q]
    vadd $v29, $v11, $v11[0q]
    vaddc $v12, $v28, $v28[1h]
    vadd $v11, $v29, $v29[1h]
    vmudl $v15, $v12, $v26
    vmadm $v15, $v11, $v26
    vmadn $v15, $v12, $v27
    vmadh $v8, $v11, $v27
    vmudl $v28, $v31, $v31[5]
    vmadl $v15, $v15, $v3[3]
    vmadm $v8, $v8, $v3[3]
    vmadn $v15, $v31, $v31[0]
    veq $v8, $v8, $v31[0]
    vmrg $v15, $v15, $v31[3]
    vne $v15, $v15, $v31[0]
    vmrg $v15, $v15, $v31[1]
    vnxor $v8, $v15, $v31[0]
    vaddc $v8, $v8, $v31[1]
    vadd $v29, $v29, $v29
    vmudl $v28, $v5, $v8[3h]
    vmadm $v29, $v4, $v8[3h]
    vmadl $v28, $v10, $v15[3h]
    vmadm $v29, $v9, $v15[3h]
    vmadn $v28, $v31, $v31[0]
    luv $v12[0], 0x10($10)
    luv $v11[0], 0x10($20)
    llv $v12[8], 0x14($10)
    llv $v11[8], 0x14($20)
    vmudm $v18, $v12, $v15[3]
    vmadm $v18, $v11, $v8[3]
    suv $v18[0], 0x0($7)
    sdv $v18[8], 0x8($7)
    ldv $v18[0], 0x8($7)
    jal ovl0_040013e8
     lw $15, 0x0($7)
    mfc2 $10, $v13[0]
    j ovl0_04001528
     ori $9, $zero, 0x1
ovl2_040019c4:
    lh $8, 0x0($5)
    sh $8, 0xb4($zero)
    sh $5, 0x106($zero)
    lh $30, 0xfe($zero)
clip_draw_loop:
    lh $8, 0x106($zero)
    lh $3, 0xb4($zero)
    lh $2, 0x2($8)
    lh $1, 0x4($8)
    addi $8, $8, 0x2
    bne $1, $zero, ovl0_04001a28
     sh $8, 0x106($zero)
ovl2_040019f0:
    j ovl0_04001750
     nop
Overlay2End:

// Overlay 3, Finished overlay; Overlay 4 in Fast3D
.if METHOD == "XBUS" || METHOD == "DRAM_DUMP"
    .headersize 0x040017d8 - orga()
.elseif METHOD == "FIFO"
    .headersize 0x040017c8 - orga()
.endif
Overlay3Address:
    j ovl3_040017f8
     nop
overlay_3_entry:
    .if METHOD == "XBUS" || METHOD == "FIFO"
        nop
    .elseif METHOD == "DRAM_DUMP"
        addi $20, $29, 0x40
        lw $19, 0x30($29)
        addi $17, $zero, 0x1
        jal dma_read_write
         addi $18, $zero, 0x7
    .endif
    jal wait_while_dma_busy
     ori $2, $zero, 0x4000
    mtc0 $2, SP_STATUS
    break
    nop
ovl3_040017f8:
    ori $2, $zero, 0x1000
    sw $28, data0914 // 0x914($zero)
    sw $27, data0918 // 0x918($zero)
    sw $26, data091C // 0x91c($zero)
    sw $23, data0920 // 0x920($zero)
    lw $19, dramPtr // 0x108($zero)
    ori $20, $zero, 0x0
    ori $18, $zero, 0x92f
    jal dma_read_write
     ori $17, $zero, 0x1
    jal wait_while_dma_busy
     nop
    j ovl0_040010c8
     mtc0 $2, SP_STATUS
    nop
    nop
    addiu $zero, $zero, 0xbeef
    nop
Overlay3End:

 // Overlay 4 ; Lighting, not included.
.if METHOD == "XBUS" || METHOD == "DRAM_DUMP"
    .headersize 0x040017d8 - orga()
.elseif METHOD == "FIFO"
    .headersize 0x040017c8 - orga()
.endif
Overlay4Address:
Overlay4End:

// Make sure the entire file is 16-byte aligned.
.aligna 16

.close 



