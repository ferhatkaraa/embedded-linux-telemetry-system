#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <stdint.h>
#include <signal.h>
#include <time.h>
#include <unistd.h>
#include <string.h>

#define TELEMETRY_INTERVAL_SEC 1
#define TEMP_MIN_C     20.0f
#define TEMP_MAX_C     85.0f
#define LOAD_MIN       0
#define LOAD_MAX       100

typedef struct {
    float temperature_c;
    int system_load;
    bool status_ok;
} telemetry_data_t;

static volatile sig_atomic_t g_running = 1;

static void signal_handler(int signo) {
    (void)signo;
    g_running = 0;
}

static float random_float(float min, float max) {
    return min + ((float)rand() / (float)RAND_MAX) * (max - min);
}

static int random_int(int min, int max) {
    return min + (rand() % (max - min + 1));
}

static void get_timestamp(char *buffer, size_t size) {
    time_t now = time(NULL);
    struct tm tm_info;
    if (localtime_r(&now, &tm_info) == NULL) {
        snprintf(buffer, size, "UNKNOWN_TIME");
        return;
    }
    strftime(buffer, size, "%Y-%m-%d %H:%M:%S", &tm_info);
}

int main(void) {
    /* --- KRİTİK DÜZELTME SATIRI --- */
    /* Yönlendirme (Pipe/FIFO) yapıldığında kernel'ın tam arabellek (fully buffered) 
       moduna geçmesini engeller, satır bazlı anlık gönderim sağlar. */
    setvbuf(stdout, NULL, _IOLBF, 0);

    struct sigaction sa;
    srand((unsigned int)time(NULL));
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = signal_handler;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGINT, &sa, NULL);
    sigaction(SIGTERM, &sa, NULL);

    telemetry_data_t telemetry;
    char timestamp[32];

    while (g_running) {
        telemetry.temperature_c = random_float(TEMP_MIN_C, TEMP_MAX_C);
        telemetry.system_load   = random_int(LOAD_MIN, LOAD_MAX);
        telemetry.status_ok     = (telemetry.temperature_c <= 75.0f && telemetry.system_load <= 90);

        get_timestamp(timestamp, sizeof(timestamp));
        
        printf("[%s] TEMP: %.1fC | LOAD: %d%% | STATUS: %s\n",
               timestamp, telemetry.temperature_c, telemetry.system_load, telemetry.status_ok ? "OK" : "FAIL");

        sleep(TELEMETRY_INTERVAL_SEC);
    }

    printf("Telemetry System shutting down gracefully...\n");
    return EXIT_SUCCESS;
}