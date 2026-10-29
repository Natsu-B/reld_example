#include <stdio.h>

_Thread_local int counter = 41;

int main(void) {
    counter++;
    printf("Hello, glibc! counter=%d\n", counter);
    return 0;
}
