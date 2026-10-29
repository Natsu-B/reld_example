void greet(const char *name);
void exit_with(int code);
__attribute__((weak)) void on_exit_hook(void);

void run(void) {
    greet("linker");
    if (on_exit_hook) on_exit_hook();
    exit_with(0);
}
