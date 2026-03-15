// fuzz_struct_to_json.c
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#include "s2j.h"   // s2j.h already includes cJSON.h

typedef struct {
    char name[16];
} Hometown;

typedef struct {
    int id;
    int scores[8];
    char name[10];
    double weight;
    Hometown hometown;
} Student;

static void s2j_init_once(void) {
    static int initialized = 0;
    if (!initialized) {
        s2j_init(NULL);   // Use default malloc/free
        initialized = 1;
    }
}

/* Helper function for Student -> JSON conversion using struct2json macros */
static cJSON *struct_to_json_student(Student *student) {
    if (student == NULL) {
        return NULL;
    }

    /* Create JSON object */
    s2j_create_json_obj(json_student);
    if (json_student == NULL) {
        return NULL;
    }

    /* Basic type fields */
    s2j_json_set_basic_element(json_student, student, int, id);
    s2j_json_set_array_element(json_student, student, int, scores,
                               S2J_ARRAY_SIZE(student->scores));
    s2j_json_set_basic_element(json_student, student, string, name);
    s2j_json_set_basic_element(json_student, student, double, weight);

    /* Sub-structure: hometown */
    s2j_json_set_struct_element(json_hometown,
                                json_student,
                                struct_hometown,
                                student,
                                Hometown,
                                hometown);
    s2j_json_set_basic_element(json_hometown, struct_hometown, string, name);

    return json_student;
}

/* libFuzzer entry point */
int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    s2j_init_once();

    Student student;
    memset(&student, 0, sizeof(student));

    /* Simply fill the Student structure's byte content with fuzz data */
    if (data != NULL && size > 0) {
        size_t copy_size = size;
        if (copy_size > sizeof(student)) {
            copy_size = sizeof(student);
        }
        memcpy(&student, data, copy_size);
    }

    cJSON *json = struct_to_json_student(&student);
    if (json) {
        /* Print as a string to cover more cJSON logic */
        char *out = cJSON_PrintUnformatted(json);
        if (out) {
            /* cJSON uses malloc/free by default */
            free(out);
        }
        cJSON_Delete(json);
    }

    return 0;
}
