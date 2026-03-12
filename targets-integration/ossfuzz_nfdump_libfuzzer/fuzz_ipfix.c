// fuzz_ipfix.c
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <stdlib.h>   // malloc, free

#include "config.h"
#include "collector.h"
#include "metric.h"   // To obtain the declaration of EXgenericFlow_t

/*
 * Include only the IPFIX decoding implementation.
 * ipfix.c is located in /src/nfdump/src; since -I/src/nfdump/src is used 
 * during compilation, we can directly #include "ipfix.c" here.
 */
#include "ipfix.c"

/* ---- Stub out auxiliary functions that ipfix.c depends on but are not in the library ---- */

int ScanExtension(char *extensionList) {
    (void)extensionList;
    return 0;
}

char *GetExporterIP(FlowSource_t *fs) {
    (void)fs;
    return NULL;
}

int FlushInfoExporter(FlowSource_t *fs, exporter_info_record_t *exporter) {
    (void)fs;
    (void)exporter;
    return 0;
}

void UpdateMetric(char *ident, uint32_t exporterID, EXgenericFlow_t *genericFlow) {
    (void)ident;
    (void)exporterID;
    (void)genericFlow;
}

/* ---- libFuzzer harness ---- */

static FlowSource_t *get_fuzz_source(void) {
    static FlowSource_t fs;
    static int initialized = 0;

    if (!initialized) {
        memset(&fs, 0, sizeof(fs));
        initialized = 1;
    }

    return &fs;
}

/*
 * This target is specifically for fuzzing IPFIX:
 * - Calls Process_IPFIX only when version == 10
 */
int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    if (size < 4) {
        return 0;
    }

    /* NetFlow/IPFIX version number is in the first 16 bits, big-endian */
    uint16_t version = (uint16_t)((data[0] << 8) | data[1]);
    if (version != 10 && version != 0x000a) {
        /* If it's not an IPFIX packet, discard it and leave it for other targets to handle */
        return 0;
    }

    FlowSource_t *fs = get_fuzz_source();

    /* Also make a copy to avoid modifying the data managed by libFuzzer */
    uint8_t *buf = (uint8_t *)malloc(size);
    if (!buf) {
        return 0;
    }
    memcpy(buf, data, size);

    Process_IPFIX(buf, (ssize_t)size, fs);

    free(buf);

    return 0;
}
