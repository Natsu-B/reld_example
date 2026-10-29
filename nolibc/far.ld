ENTRY(_start)
SECTIONS
{
  . = 0x400000 + SIZEOF_HEADERS;
  . = ALIGN(0x1000);
  .text : { *(.text .text.*) }
  . = 0x100000000;
  .rodata : { *(.rodata .rodata.*) }
}
