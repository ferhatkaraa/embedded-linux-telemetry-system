#define _XOPEN_SOURCE 500
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>

#define FIFO_PATH "/tmp/telemetry_fifo"

int main(void) {
    char buffer[256];
    int fd;

    printf("Telemetry IPC Receiver Station Started...\n");
    printf("Press Ctrl+C to terminate\n\n");

    /* Eski boru hattı kalıntısı varsa temizle ve yenisini aç */
    unlink(FIFO_PATH);
    if (mkfifo(FIFO_PATH, 0666) < 0) {
        perror("mkfifo");
        return EXIT_FAILURE;
    }

    while (1) {
        /* FIFO'yu bloklamalı modda okuma için aç */
        fd = open(FIFO_PATH, O_RDONLY);
        if (fd != -1) {
            memset(buffer, 0, sizeof(buffer));
            ssize_t bytes_read = read(fd, buffer, sizeof(buffer) - 1);
            if (bytes_read > 0) {
                buffer[bytes_read] = '\0';
                /* Gelen veriyi bas ve stdout buffer'ını anında boşalt */
                printf("[IPC RECEIVED] %s", buffer);
                fflush(stdout);
            }
            close(fd);
        }
        usleep(100000); /* 100ms dinlenme hızı */
    }

    return EXIT_SUCCESS;
}