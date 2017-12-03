#include "nif.h"
#include <stdio.h>
#include <inttypes.h>

#define ROTATE_LEFT(x, b) (unsigned long)(((x) << (b)) | ((x) >> (64 - (b))))

#define COMPRESS                \
  v0 += v1;                     \
  v2 += v3;                     \
  v1 = ROTATE_LEFT(v1, 13);     \
  v3 = ROTATE_LEFT(v3, 16);     \
  v1 ^= v0;                     \
  v3 ^= v2;                     \
  v0 = ROTATE_LEFT(v0, 32);     \
  v2 += v1;                     \
  v0 += v3;                     \
  v1 = ROTATE_LEFT(v1, 17);     \
  v3 = ROTATE_LEFT(v3, 21);     \
  v1 ^= v2;                     \
  v3 ^= v0;                     \
  v2 = ROTATE_LEFT(v2, 32);

#define DIGEST_BLOCK            \
  v3 ^= m;                      \
  do {                          \
    int i;                      \
    for(i = 0; i < c; i++){     \
      COMPRESS                  \
    }                           \
  } while (0);                  \
  v0 ^= m;

#define U8TO64_LE(p)                                            \
  (((uint64_t)((p)[0])) | ((uint64_t)((p)[1]) << 8) |           \
   ((uint64_t)((p)[2]) << 16) | ((uint64_t)((p)[3]) << 24) |    \
   ((uint64_t)((p)[4]) << 32) | ((uint64_t)((p)[5]) << 40) |    \
   ((uint64_t)((p)[6]) << 48) | ((uint64_t)((p)[7]) << 56))

NIF(hash){
  ErlNifBinary key, data;

  enif_inspect_binary(env, argv[0], &key);
  enif_inspect_binary(env, argv[1], &data);

  int c, d;

  enif_get_int(env, argv[2], &c);
  enif_get_int(env, argv[3], &d);

  uint64_t k0 = U8TO64_LE(key.data);
  uint64_t k1 = U8TO64_LE(key.data + 8);

  uint64_t v0 = 0x736f6d6570736575ULL ^ k0;
  uint64_t v1 = 0x646f72616e646f6dULL ^ k1;
  uint64_t v2 = 0x6c7967656e657261ULL ^ k0;
  uint64_t v3 = 0x7465646279746573ULL ^ k1;

  uint64_t m = 0;

  int iter = 0, index = 0;

  for (; index < data.size; index++) {
    m |= ((uint64_t) data.data[index]) << (iter++ * 8);
    if (iter >= 8) {
      DIGEST_BLOCK
      iter = 0;
      m = 0;
    }
  }

  while (iter < 7) {
    m |= 0 << (iter++ * 8);
  }

  m |= ((uint64_t) data.size) << (iter * 8);

  DIGEST_BLOCK

  v2 ^= 0xff;

  int i;
  for(i = 0; i < d; i++){
    COMPRESS
  }

  uint64_t output = ((uint64_t) v0 ^ v1 ^ v2 ^ v3);

  if (argc == 4) {
    return enif_make_ulong(env, output);
  }

  ErlNifBinary ret, format;

  enif_alloc_binary(16, &ret);
  enif_inspect_binary(env, argv[4], &format);

  sprintf(ret.data, format.data, output);

  return enif_make_binary(env, &ret);
}

static ErlNifFunc nif_funcs[] = {
  { "hash", 4, hash },
  { "hash", 5, hash },
  { "nif_loaded?", 0, nif_loaded }
};

ERL_NIF_INIT(Elixir.SipHash.Digest,nif_funcs,NULL,NULL,upgrade,NULL)
