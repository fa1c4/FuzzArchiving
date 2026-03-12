// fuzz_netflow_v9.c
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <stdlib.h>   // malloc, free

#include "config.h"
#include "collector.h"
#include "metric.h"

/*
 * Key point: Only include the NetFlow v9 decoding implementation.
 * netflow_v9.c is located in /src/nfdump/src; since -I/src/nfdump/src is used 
 * during compilation, we can directly #include "netflow_v9.c" here.
 */
#include "netflow_v9.c"

/* ---- Same as fuzz_ipfix, stub out auxiliary functions that might be required ---- */

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
 * This target is specifically for fuzzing NetFlow v9:
 * - Calls Process_v9 only when version == 9
 */
int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    if (size < 4) {
        return 0;
    }

    /* NetFlow/IPFIX version number is in the first 16 bits, big-endian */
    uint16_t version = (uint16_t)((data[0] << 8) | data[1]);
    if (version != 9) {
        /* If it's not a v9 packet, discard it and leave it for other targets to handle */
        return 0;
    }

    FlowSource_t *fs = get_fuzz_source();

    /* Do not operate directly on data; copy it to a writable buffer */
    uint8_t *buf = (uint8_t *)malloc(size);
    if (!buf) {
        return 0;
    }
    memcpy(buf, data, size);

    Process_v9(buf, (ssize_t)size, fs);

    free(buf);

    return 0;
}
