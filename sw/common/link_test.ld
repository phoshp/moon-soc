OUTPUT_ARCH("riscv")
ENTRY(_start)

SECTIONS
{
  . = 0x00001000;
  .text : {
    *(.text._start)
    *(.text*)
  }
  .rodata : {
    *(.rodata*)
  }
  . = 0x80000000;
  .data : {
    *(.data*)
  }
  .bss : {
    *(.bss*)
  }
}
