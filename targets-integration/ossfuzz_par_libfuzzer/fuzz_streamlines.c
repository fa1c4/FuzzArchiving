// fuzz_streamlines.c
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>

#define PAR_STREAMLINES_IMPLEMENTATION
#include "par_streamlines.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    if (size < 8) {
        return 0;
    }

    // 4 bytes per vertex: x(16bit) + y(16bit)
    const size_t BYTES_PER_VERTEX = 4;
    size_t max_vertices = size / BYTES_PER_VERTEX;
    if (max_vertices < 2) {  // At least one line segment is required
        return 0;
    }

    if (max_vertices > 256) {
        max_vertices = 256;
    }

    parsl_position *vertices =
        (parsl_position *)malloc(max_vertices * sizeof(parsl_position));
    if (!vertices) {
        return 0;
    }

    size_t offset = 0;
    for (size_t i = 0; i < max_vertices; ++i) {
        if (offset + 3 >= size) {
            vertices[i].x = 0.0f;
            vertices[i].y = 0.0f;
            continue;
        }
        uint16_t x_raw = (uint16_t)(data[offset] | (data[offset + 1] << 8));
        uint16_t y_raw = (uint16_t)(data[offset + 2] | (data[offset + 3] << 8));
        offset += BYTES_PER_VERTEX;

        // Map to the [-1, 1] range
        vertices[i].x = (float)x_raw / 32767.5f - 1.0f;
        vertices[i].y = (float)y_raw / 32767.5f - 1.0f;
    }

    uint16_t *spine_lengths = (uint16_t *)malloc(sizeof(uint16_t));
    if (!spine_lengths) {
        free(vertices);
        return 0;
    }
    spine_lengths[0] = (uint16_t)max_vertices;

    parsl_spine_list spines;
    spines.num_vertices = (uint32_t)max_vertices;
    spines.num_spines   = 1;
    spines.vertices     = vertices;
    spines.spine_lengths = spine_lengths;
    spines.closed       = (data[0] & 1) != 0;

    parsl_config config;
    config.thickness = 1.0f + (data[1] / 255.0f) * 10.0f;
    config.flags = PARSL_FLAG_ANNOTATIONS |
                   PARSL_FLAG_SPINE_LENGTHS |
                   PARSL_FLAG_RANDOM_OFFSETS;
    config.u_mode = (parsl_u_mode)(data[2] % 4);
    config.curves_max_flatness = 0.1f + (data[3] / 255.0f);
    config.streamlines_seed_spacing = 0.1f + (data[4] / 255.0f);
    config.streamlines_seed_viewport.left   = -1.0f;
    config.streamlines_seed_viewport.top    = -1.0f;
    config.streamlines_seed_viewport.right  =  1.0f;
    config.streamlines_seed_viewport.bottom =  1.0f;
    config.miter_limit = 1.0f + (data[5] / 255.0f) * 5.0f;

    parsl_context *ctx = parsl_create_context(config);
    if (ctx) {
        parsl_mesh *mesh = parsl_mesh_from_lines(ctx, spines);
        // Mesh ownership is held by ctx; simply destroying the context is enough
        (void)mesh;
        parsl_destroy_context(ctx);
    }

    free(vertices);
    free(spine_lengths);
    return 0;
}
