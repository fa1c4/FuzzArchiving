// fuzz_netflow_v9.c
#include <limits.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "config.h"
#include "collector.h"
#include "metric.h"

#define WriteBlock FuzzWriteBlock

/*
 * Key point: Only include the NetFlow v9 decoding implementation.
 * netflow_v9.c is located in /src/nfdump/src; since -I/src/nfdump/src is used 
 * during compilation, we can directly #include "netflow_v9.c" here.
 */
static dataBlock_t *FuzzWriteBlock(nffile_t *nffile, dataBlock_t *dataBlock);

#include "netflow_v9.c"

#undef WriteBlock

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

typedef struct {
    nffile_t nffile;
    stat_record_t stat_record;
    struct {
        dataBlock_t header;
        uint8_t payload[BUFFSIZE];
    } data;
} fuzz_runtime_t;

static fuzz_runtime_t runtime;

static dataBlock_t *FuzzWriteBlock(nffile_t *nffile, dataBlock_t *dataBlock) {
    (void)nffile;
    (void)dataBlock;

    runtime.data.header.NumRecords = 0;
    runtime.data.header.size = 0;
    runtime.data.header.type = DATA_BLOCK_TYPE_3;
    runtime.data.header.flags = 0;

    return &runtime.data.header;
}

static void free_exporter(exporterDomain_t *exporter) {
    while (exporter->template) {
        removeTemplate(exporter, exporter->template->id);
    }

    sampler_t *sampler = exporter->sampler;
    while (sampler) {
        sampler_t *next = sampler->next;
        free(sampler);
        sampler = next;
    }
}

static void reset_fuzz_source(FlowSource_t *fs) {
    while (fs->exporter_data) {
        exporterDomain_t *exporter = (exporterDomain_t *)fs->exporter_data;
        fs->exporter_data = (exporter_t *)exporter->next;
        free_exporter(exporter);
        free(exporter);
    }

    fs->exporter_count = 0;
    fs->bad_packets = 0;
    memset(&fs->received, 0, sizeof(fs->received));
    memset(fs->nffile->stat_record, 0, sizeof(*fs->nffile->stat_record));
    fs->nffile->stat_record->msecFirstSeen = INT64_MAX;
    fs->dataBlock = FuzzWriteBlock(fs->nffile, fs->dataBlock);
}

static FlowSource_t *get_fuzz_source(void) {
    static FlowSource_t fs;
    static int initialized = 0;

    if (!initialized) {
        memset(&fs, 0, sizeof(fs));
        memset(&runtime, 0, sizeof(runtime));

        runtime.nffile.ident = "fuzz";
        runtime.nffile.buff_size = BUFFSIZE;
        runtime.nffile.stat_record = &runtime.stat_record;

        fs.nffile = &runtime.nffile;
        fs.dataBlock = FuzzWriteBlock(fs.nffile, NULL);
        if (!Init_v9(0, 0, NULL)) {
            return NULL;
        }

        initialized = 1;
    }

    reset_fuzz_source(&fs);
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
    if (!fs) {
        return 0;
    }

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
