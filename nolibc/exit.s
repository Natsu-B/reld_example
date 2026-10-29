.text

.globl exit_with
.type exit_with, @function
exit_with:
    # void exit_with(int status);

    movl $60, %eax        # SYS_exit = 60
    syscall               # rdi = status
    ud2                   # 到達不能
