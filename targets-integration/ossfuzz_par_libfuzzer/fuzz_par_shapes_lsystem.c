// fuzz_par_shapes_lsystem.c
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>

#define PAR_SHAPES_IMPLEMENTATION
#include "par_shapes.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    if (size == 0) {
        return 0;
    }

    // Create a copy and ensure it is null-terminated ('\0')
    char *program = (char *)malloc(size + 1);
    if (!program) {
        return 0;
    }
    for (size_t i = 0; i < size; ++i) {
        // Keep the original bytes
        program[i] = (char)data[i];
    }
    program[size] = '\0';

    int slices   = (int)(data[0] % 32u) + 3;  // Minimum of 3 to avoid degenerate cases
    int maxdepth = 1;
    if (size > 1) {
        maxdepth = (int)(data[1] % 6u) + 1;   // 1..6 to prevent recursion from being too deep
    }

    par_shapes_mesh *mesh =
        par_shapes_create_lsystem(program, slices, maxdepth);

    if (mesh) {
        // Exercise as many code paths as possible
        par_shapes_compute_normals(mesh);

        par_shapes_scale(mesh, 0.5f, 0.5f, 0.5f);
        par_shapes_translate(mesh, 0.1f, -0.2f, 0.3f);

        // Welding (this generates a new mesh)
        par_shapes_mesh *welded = par_shapes_weld(mesh, 0.0001f, NULL);
        if (welded) {
            par_shapes_compute_normals(welded);
            par_shapes_free_mesh(welded);
        }

        // Finally, free the original mesh
        par_shapes_free_mesh(mesh);
    }

    free(program);
    return 0;
}
