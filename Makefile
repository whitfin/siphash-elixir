ERLANG_PATH = $(shell erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/erts-", erlang:system_info(version), "/include"])])' -s init stop -noshell)
CFLAGS = -g -O3 -ansi -pedantic -Wall -Wextra -I$(ERLANG_PATH)

ifneq ($(OS),Windows_NT)
	CFLAGS += -fPIC

	ifeq ($(shell uname),Darwin)
		LDFLAGS += -dynamiclib -undefined dynamic_lookup
	endif
endif

_native: clean
	mkdir -p _native
	$(CC) -w $(CFLAGS) -shared $(LDFLAGS) -o $@/state.so c_src/state.c
	$(CC) -w $(CFLAGS) -shared $(LDFLAGS) -o $@/util.so c_src/util.c

clean:
	$(RM) -r _native/*
