#include "erl_nif.h"

static ERL_NIF_TERM format(ErlNifEnv* env, int arc, const ERL_NIF_TERM argv[]) {
  unsigned long n;
  ErlNifBinary f, r;

  enif_alloc_binary(16, &r);
  enif_get_ulong(env, argv[0], &n);
  enif_inspect_binary(env, argv[1], &f);

  sprintf(r.data, f.data, n);

  return enif_make_binary(env, &r);
}

static ErlNifFunc nif_funcs[] = {
  { "format", 2, format }
};

static int upgrade(ErlNifEnv* env, void** new, void** old, ERL_NIF_TERM info){
  return 0;
}

ERL_NIF_INIT(Elixir.SipHash.Util,nif_funcs,NULL,NULL,upgrade,NULL)
