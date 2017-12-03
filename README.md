# SipHash
[![Build Status](https://travis-ci.org/whitfin/siphash-elixir.svg?branch=master)](https://travis-ci.org/whitfin/siphash-elixir) [![Coverage Status](https://coveralls.io/repos/whitfin/siphash-elixir/badge.svg?branch=master&service=github)](https://coveralls.io/github/whitfin/siphash-elixir?branch=master)

An Elixir implementation of the SipHash cryptographic hash family using native components for faster execution. Supports any variation, although defaults to the widely used SipHash-2-4. Previous versions focused on correctness, now there is a larger emphasis on performance optimizations as I intend to use it in a production environment (so naturally correctness will be upheld).

## Installation

This package can be installed via Hex:

  1. Add siphash to your list of dependencies in `mix.exs`:

        def deps do
          [{:siphash, "~> 3.2"}]
        end

  2. Ensure siphash is started before your application:

        def application do
          [applications: [:siphash]]
        end

## Quick Usage

It's straightforward to get going, you just supply your key and input to `SipHash.hash/3`.

```elixir
iex(1)> SipHash.hash("0123456789ABCDEF", "Hello, World!")
{ :ok, 16916637876837948234 }
iex(2)> SipHash.hash!("0123456789ABCDEF", "Hello, World!") # default in v2.x
16916637876837948234
iex(2)> SipHash.hash!("0123456789ABCDEF", "Hello, World!", hex: true) # default in v1.x
"EAC3F88552D81B4A"
```

For further examples, as well as different flags to customize output, please see the [documentation](http://hexdocs.pm/siphash/SipHash.html).

## Migration to v3.1.x

The only change with v3.1.x is a deprecation label on using the `SIPHASH_IMPL` environment variable to control whether a NIF is loaded or not. In future, you should control it via the application configuration as follows:

```elixir
config :siphash,
  disable_nifs: true
```

This is just generally a better way to control this, rather than tainting the execution environment. In order to preserve backwards compatibility for the time being, the default value for `disable_nifs` will just be `System.get_env("SIPHASH_IMPL") == "embedded"`. In future this will be removed and modified to simply be `false`; this will likely happen if/when a v3.2.x comes alone.

## Migration to v3.x

With v3.x come huge performance gains over all prior versions, roughly 200x the speed of the initial implementations. This is due to a smarter NIF binding, so it's recommended to use the NIF whenever possible.

It was previously possible to disable different types of NIF using both the `HASH_IMPL` and `STATE_IMPL` environment variables. The new implementation uses a single NIF, and can only be disabled by setting `SIPHASH_IMPL` to `embedded`. This will fall back to using an Elixir implementation. This version is somewhat slower, but it comes with less risk attached (although the NIF is pretty bulletproof when used correctly).

In addition, the typical Elixir standard of `{ :ok, result }` and `{ :error, message }` has been adopted as of v3.0.0. As such, all hashes are returned in a tuple signifying whether the hash was a success or not. Below is an example of both cases:

```elixir
iex(1)> SipHash.hash("0123456789ABCDEF", "Hello, World!")
{ :ok, 16916637876837948234 }
iex(2)> SipHash.hash("invalid_bytes", "Hello, World!")
{ :error, "Key must be exactly 16 bytes!" }
```

Because all potential errors are pretty much down to programmer error, you should be safe to use the alternate `SipHash.hash!/3` implementation which returns the straight result (or raises the appropriate error). This is the same behavior as that of `< v3.0.0`.

```elixir
iex(1)> SipHash.hash!("0123456789ABCDEF", "Hello, World!")
16916637876837948234
iex(2)> SipHash.hash!("invalid_bytes", "Hello, World!")
** (ArgumentError) Key must be exactly 16 bytes!
```

## Issues/Contributions

If you spot any issues with the implementation, please file an [issue](http://github.com/whitfin/siphash-elixir/issues) or even a PR. The faster we can make it, the better!

Make sure to test your changes though!

```bash
$ SIPHASH_IMPL=native mix test --trace    # test NIF  successes/failures
$ SIPHASH_IMPL=embedded mix test --trace  # test Elixir successes/failures
$ SIPHASH_IMPL=embedded mix coveralls     # code coverage, try keep 100% please!
```
