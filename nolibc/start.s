.text
.globl _start
.type _start, @function
_start:
    andq $-16, %rsp
    call run
    ud2
