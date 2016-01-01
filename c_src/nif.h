#ifndef NIF_H_
#define NIF_H_

#include "erl_nif.h"

#define NIF(name) \
  ERL_NIF_TERM name(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])

NIF(nif_loaded) {
  return enif_make_atom(env, "true");
}

int upgrade(ErlNifEnv* env, void** new, void** old, ERL_NIF_TERM info){
  return 0;
}

#endif
