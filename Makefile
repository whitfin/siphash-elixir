ERLANG_PATH = $(shell erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/erts-", erlang:system_info(version), "/include"])])' -s init stop -noshell)
CFLAGS = -g -O3 -ansi -pedantic -Wall -Wextra -I$(ERLANG_PATH)

ifneq ($(OS),Windows_NT)
	CFLAGS += -fPIC

	ifeq ($(shell uname),Darwin)
		LDFLAGS += -dynamiclib -undefined dynamic_lookup
	endif
endif

_native/native_impl.so: clean
	mkdir -p _native
	$(CC) -w $(CFLAGS) -shared $(LDFLAGS) -o $@ c_src/native_impl.c

clean:
	$(RM) -r _native/*
