#include "erl_nif.h"
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

static ERL_NIF_TERM apply_block(ErlNifEnv* env, int arc, const ERL_NIF_TERM argv[]) {
  int arity;
  const ERL_NIF_TERM** tuple;

  enif_get_tuple(env, argv[0], &arity, &tuple);

  unsigned long v0;
  unsigned long v1;
  unsigned long v2;
  unsigned long v3;
  unsigned long m;

  enif_get_ulong(env, tuple[0], &v0);
  enif_get_ulong(env, tuple[1], &v1);
  enif_get_ulong(env, tuple[2], &v2);
  enif_get_ulong(env, tuple[3], &v3);
  enif_get_ulong(env, argv[1], &m);

  int c;

  enif_get_int(env, argv[2], &c);

  v3 ^= m;
  for(int i = 0; i < c; i++){
    COMPRESS
  }
  v0 ^= m;

  return enif_make_tuple4(
    env,
    enif_make_ulong(env, v0),
    enif_make_ulong(env, v1),
    enif_make_ulong(env, v2),
    enif_make_ulong(env, v3)
  );
}

static ERL_NIF_TERM finalize(ErlNifEnv* env, int arc, const ERL_NIF_TERM argv[]) {
  int arity;
  const ERL_NIF_TERM** tuple;

  enif_get_tuple(env, argv[0], &arity, &tuple);

  unsigned long v0;
  unsigned long v1;
  unsigned long v2;
  unsigned long v3;

  enif_get_ulong(env, tuple[0], &v0);
  enif_get_ulong(env, tuple[1], &v1);
  enif_get_ulong(env, tuple[2], &v2);
  enif_get_ulong(env, tuple[3], &v3);

  int d;

  enif_get_int(env, argv[1], &d);

  v2 ^= 0xff;
  for(int i = 0; i < d; i++){
    COMPRESS
  }

  return enif_make_ulong(env, v0 ^ v1 ^ v2 ^ v3);
}

static ErlNifFunc nif_funcs[] = {
  { "apply_internal_block", 3, apply_block },
  { "finalize", 2, finalize }
};

static int upgrade(ErlNifEnv* env, void** new, void** old, ERL_NIF_TERM info){
  return 0;
}

ERL_NIF_INIT(Elixir.SipHash.State,nif_funcs,NULL,NULL,upgrade,NULL)
