void put(const char *s, long len);

static long length(const char *s) {
    long n = 0;
    while (s[n]) n++;
    return n;
}

void greet(const char *name) {
    put("Hello, ", 7);
    put(name, length(name));
    put("!\n", 2);
}
