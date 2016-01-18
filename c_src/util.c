#include "nif.h"

NIF(format){
  unsigned long n;
  ErlNifBinary f, r;

  enif_alloc_binary(16, &r);
  enif_get_ulong(env, argv[0], &n);
  enif_inspect_binary(env, argv[1], &f);

  sprintf(r.data, f.data, n);

  return enif_make_binary(env, &r);
}

static ErlNifFunc nif_funcs[] = {
  { "format", 2, format },
  { "nif_loaded?", 0, nif_loaded }
};

ERL_NIF_INIT(Elixir.SipHash.Util,nif_funcs,NULL,NULL,upgrade,NULL)
