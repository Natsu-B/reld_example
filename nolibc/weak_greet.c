void put(const char *s, long len);

__attribute__((weak)) void greet(const char *name) {
    (void)name;
    put("(default greeting)\n", 19);
}
