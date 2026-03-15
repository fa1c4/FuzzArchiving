// fuzz_json_to_struct.c
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#include "s2j.h"   // s2j.h already includes cJSON.h

/* Example structures: similar to Student/Hometown in the README */
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

/* Initialize struct2json (and cJSON hooks) only once */
static void s2j_init_once(void) {
    static int initialized = 0;
    if (!initialized) {
        s2j_init(NULL);  // Use default malloc/free
        initialized = 1;
    }
}

/* Helper function for JSON -> Student conversion using struct2json macros */
static Student *json_to_struct_student(cJSON *json_student) {
    if (json_student == NULL) {
        return NULL;
    }

    /* Create structure object; internally uses s2jHook.malloc_fn for allocation and zeroing */
    s2j_create_struct_obj(student, Student);
    if (student == NULL) {
        return NULL;
    }

    /* Basic type fields */
    s2j_struct_get_basic_element(student, json_student, int, id);
    s2j_struct_get_array_element(student, json_student, int, scores);
    s2j_struct_get_basic_element(student, json_student, string, name);
    s2j_struct_get_basic_element(student, json_student, double, weight);

    /* Sub-structure field: hometown */
    s2j_struct_get_struct_element(struct_hometown,
                                  student,
                                  json_hometown,
                                  json_student,
                                  Hometown,
                                  hometown);
    if (json_hometown) {
        s2j_struct_get_basic_element(struct_hometown, json_hometown, string, name);
    }

    return student;
}

/* libFuzzer entry point */
int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    s2j_init_once();

    if (data == NULL || size == 0) {
        return 0;
    }

    /* Copy to a null-terminated string to avoid dependency on cJSON_ParseWithLength */
    char *json_text = (char *)malloc(size + 1);
    if (!json_text) {
        return 0;
    }
    memcpy(json_text, data, size);
    json_text[size] = '\0';

    cJSON *root = cJSON_Parse(json_text);
    free(json_text);

    if (!root) {
        return 0;
    }

    Student *student = json_to_struct_student(root);
    if (student) {
        /* This only handles construction and destruction; actual logic validation is left to the sanitizers */
        s2j_delete_struct_obj(student);
    }

    cJSON_Delete(root);
    return 0;
}
