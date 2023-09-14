#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>
#include <string.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdio.h>

int
parse(char* str) {
    char* end;
    int res = strtol(str, &end, 10);

    return res;
}

int
main(int argc, char* argv[]) {
    if (argc <= 2) {
        fprintf(stderr, "Usage <filenamelength> <filepath> [filename length]\n");
        exit(1);
    }
    char* filepath = argv[1];
    int length = parse(argv[2]);

    char* memory = "ok";
    size_t size = strlen(memory);

    size_t preallocation = 1048;
    char* buffer = (char*) calloc(preallocation, 1);
    int min = preallocation;
    if (length < min) {
        min = length;
    }
    for (int i = 0; i < min; i++) {
        buffer[i] = 'a';
    }

    FILE* fdc = fopen(buffer, "w");
    if (fdc == 0) {
        fprintf(stderr, "Error opening file: %s\n", buffer);
        exit(2);
    }
    fwrite(memory, size, 1, fdc);

    FILE* fd = fopen(filepath, "w");
    if (fd == 0) {
        fprintf(stderr, "Error opening file: %s\n", filepath);
        exit(2);
    }
    fwrite(memory, size, 1, fd);
}
