// fuzz_msquares.c
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <math.h>

#define PAR_MSQUARES_IMPLEMENTATION
#include "par_msquares.h"

static uint32_t read_u32(const uint8_t *p) {
    return ((uint32_t)p[0] << 24) |
           ((uint32_t)p[1] << 16) |
           ((uint32_t)p[2] << 8)  |
           ((uint32_t)p[3]);
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    if (size < 32) {
        return 0;
    }

    const size_t header = 24;

    uint32_t w_raw    = read_u32(data + 0);
    uint32_t h_raw    = read_u32(data + 4);
    uint32_t cell_raw = read_u32(data + 8);
    uint32_t thr_raw  = read_u32(data + 12);

    // Limit width and height to prevent excessive allocation, 
    // and ensure width/height are multiples of cellsize initially.
    int cells_x = (int)(w_raw   % 64u) + 1;     // Range: 1..64
    int cells_y = (int)(h_raw   % 64u) + 1;     // Range: 1..64
    int cellsize = (int)(cell_raw % 16u) + 1;   // Range: 1..16

    int width  = cells_x * cellsize;
    int height = cells_y * cellsize;

    float threshold = (float)thr_raw / (float)UINT32_MAX;

    size_t num_pixels_from_data = (size - header) / 4; // One float per pixel
    if (num_pixels_from_data == 0) {
        return 0;
    }

    size_t target_pixels = (size_t)width * (size_t)height;

    // If there is insufficient data, shrink to an approximate square 
    // (here width/height are no longer guaranteed to be multiples of cellsize).
    if (num_pixels_from_data < target_pixels) {
        size_t side = (size_t)sqrt((double)num_pixels_from_data);
        if (side == 0) {
            return 0;
        }
        width = (int)side;
        height = (int)side;
        target_pixels = side * side;
    }

    // To comply with assertions in par_msquares_function:
    //   width > 0 && width % cellsize == 0
    // If width is no longer a multiple of cellsize, discard this input.
    if (width <= 0 || (width % cellsize) != 0) {
        return 0;
    }

    float *gray = (float *)malloc(target_pixels * sizeof(float));
    if (!gray) {
        return 0;
    }

    const uint8_t *p = data + header;
    for (size_t i = 0; i < target_pixels; ++i) {
        if ((size_t)(p - data + 4) > size) {
            gray[i] = 0.0f;
            continue;
        }
        uint32_t v = read_u32(p);
        p += 4;
        gray[i] = (float)v / (float)UINT32_MAX;
    }

    int flags = (int)data[header % size];

    par_msquares_meshlist *mlist =
        par_msquares_grayscale(gray, width, height, cellsize, threshold, flags);

    if (mlist) {
        int count = par_msquares_get_count(mlist);
        for (int i = 0; i < count; ++i) {
            const par_msquares_mesh *mesh = par_msquares_get_mesh(mlist, i);
            if (!mesh) continue;

            volatile int npoints     = mesh->npoints;
            volatile int ntriangles = mesh->ntriangles;
            (void)npoints;
            (void)ntriangles;
        }

        par_msquares_free(mlist);
    }

    free(gray);
    return 0;
}
