ERLANG_PATH = $(shell erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/erts-", erlang:system_info(version), "/include"])])' -s init stop -noshell)
CFLAGS = -g -O3 -ansi -pedantic -Wall -Wextra -I$(ERLANG_PATH)
MIX = mix

ifneq ($(OS),Windows_NT)
	CFLAGS += -fPIC

	ifeq ($(shell uname),Darwin)
		LDFLAGS += -dynamiclib -undefined dynamic_lookup
	endif
endif

all: siphash

siphash:
	$(MIX) compile

priv/siphash.so: c_src/siphash.c
	mkdir priv
	$(CC) -w $(CFLAGS) -shared $(LDFLAGS) -o $@ c_src/siphash.c

clean:
	$(MIX) clean
	$(RM) priv/siphash.so
