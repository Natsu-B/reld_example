void greet(const char *name);
void exit_with(int code);

void run(void) {
    greet("linker");
    exit_with(0);
}
