#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "api.h"

/**
 * Fuzzing harness for PQClean's ML-KEM-768 (Kyber) implementation.
 * This harness tests both the encapsulation and decapsulation processes
 * using the provided fuzzer data as potential public keys, ciphertexts,
 * and secret keys.
 */

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    // Fuzzing crypto_kem_dec (Decapsulation)
    // Requires a ciphertext and a secret key.
    // We use the namespaced constants provided by PQClean's api.h.
    if (size >= PQCLEAN_MLKEM768_CLEAN_CRYPTO_CIPHERTEXTBYTES + PQCLEAN_MLKEM768_CLEAN_CRYPTO_SECRETKEYBYTES) {
        uint8_t ss[PQCLEAN_MLKEM768_CLEAN_CRYPTO_BYTES];
        const uint8_t *ct = data;
        const uint8_t *sk = data + PQCLEAN_MLKEM768_CLEAN_CRYPTO_CIPHERTEXTBYTES;
        
        // The return value indicates success/failure of decapsulation (e.g., implicit rejection)
        PQCLEAN_MLKEM768_CLEAN_crypto_kem_dec(ss, ct, sk);
    }

    // Fuzzing crypto_kem_enc (Encapsulation)
    // Requires a public key.
    if (size >= PQCLEAN_MLKEM768_CLEAN_CRYPTO_PUBLICKEYBYTES) {
        uint8_t ct[PQCLEAN_MLKEM768_CLEAN_CRYPTO_CIPHERTEXTBYTES];
        uint8_t ss[PQCLEAN_MLKEM768_CLEAN_CRYPTO_BYTES];
        const uint8_t *pk = data;
        
        // Encapsulation uses randombytes internally to generate the shared secret.
        PQCLEAN_MLKEM768_CLEAN_crypto_kem_enc(ct, ss, pk);
    }

    return 0;
}