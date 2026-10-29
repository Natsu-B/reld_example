.text

.globl put
.type put, @function
put:
    # void put(const char *s, long len);
    # write(1, s, len)

    movq %rsi, %rdx       # 第3引数: len
    movq %rdi, %rsi       # 第2引数: s
    movl $1, %edi         # 第1引数: stdout
    movl $1, %eax         # SYS_write = 1
    syscall
    ret
