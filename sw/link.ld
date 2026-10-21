SECTIONS {
    . = 0x80000000;
    .text : { *(.text) }
    . = ALIGN(4);
    .data : { *(.data) *(.bss) }
}
