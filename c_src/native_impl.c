#include "erl_nif.h"

#define rotate_left(x, b) (unsigned long)(((x) << (b)) | ((x) >> (64 - (b))))

static ERL_NIF_TERM _compress(ErlNifEnv* env, int arc, const ERL_NIF_TERM argv[]) {
  const ERL_NIF_TERM** tuple;

  enif_get_tuple(env, argv[0], &argv, &tuple);

  unsigned long v0;
  unsigned long v1;
  unsigned long v2;
  unsigned long v3;

  enif_get_ulong(env, tuple[0], &v0);
  enif_get_ulong(env, tuple[1], &v1);
  enif_get_ulong(env, tuple[2], &v2);
  enif_get_ulong(env, tuple[3], &v3);

  v0 += v1;
  v2 += v3;
  v1 = rotate_left(v1, 13);
  v3 = rotate_left(v3, 16);

  v1 ^= v0;
  v3 ^= v2;
  v0 = rotate_left(v0, 32);

  v2 += v1;
  v0 += v3;
  v1 = rotate_left(v1, 17);
  v3 = rotate_left(v3, 21);

  v1 ^= v2;
  v3 ^= v0;
  v2 = rotate_left(v2, 32);

  return enif_make_tuple4(
    env,
    enif_make_ulong(env, v0),
    enif_make_ulong(env, v1),
    enif_make_ulong(env, v2),
    enif_make_ulong(env, v3)
  );
}

static ErlNifFunc nif_funcs[] = {
  { "compress", 1, _compress }
};

static int upgrade(ErlNifEnv* env, void** new, void** old, ERL_NIF_TERM info){
  return 0;
}

ERL_NIF_INIT(Elixir.SipHash.State,nif_funcs,NULL,NULL,upgrade,NULL)
