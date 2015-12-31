# SipHash
[![Build Status](https://travis-ci.org/zackehh/siphash-elixir.svg?branch=master)](https://travis-ci.org/zackehh/siphash-elixir) [![Coverage Status](https://coveralls.io/repos/zackehh/siphash-elixir/badge.svg?branch=master&service=github)](https://coveralls.io/github/zackehh/siphash-elixir?branch=master)

An Elixir implementation of the SipHash cryptographic hash family using native components for faster execution. Supports any variation, although defaults to the widely used SipHash-2-4. Previous versions focused on correctness, now there is a larger emphasis on performance optimizations as I intend to use it in a production environment (so naturally correctness will be upheld).

## Installation

This package can be installed via Hex:

  1. Add siphash to your list of dependencies in `mix.exs`:

        def deps do
          [{:siphash, "~> 2.1.0"}]
        end

  2. Ensure siphash is started before your application:

        def application do
          [applications: [:siphash]]
        end

## Quick Usage

It's straightforward to get going, you just supply your key and input to `SipHash.hash/3`.

```elixir
iex(1)> SipHash.hash("0123456789ABCDEF", "Hello, World!")
16916637876837948234
iex(2)> SipHash.hash("0123456789ABCDEF", "Hello, World!", hex: true) # default in v1.x
"EAC3F88552D81B4A"
```

For further examples, as well as different flags to customize output, please see the [documentation](http://hexdocs.pm/siphash/SipHash.html).

## Migration to v2.1.x

The move to v2.1.x comes with even further performance gains, roughly 3x the speed of v2.0.x. There are a few notable changes in this version bump which make it necessary to document;

Previously, NIFs were disabled by setting `HASH_IMPL` to `embedded` in your environment. As of v2.1.x, there are two places native implementations are used, and so they have to be disabled separately via the `STATE_IMPL` and `UTIL_IMPL` environment variables. Setting them to `embedded` will force them to use an internal Elixir implementation (which will very likely be slower). Both can be disabled independently of each other.

Please also note that as of v2.1.x, the `:padding` key does not change any behaviour. In prior versions it was possible to **not** left-pad your hashes with 0s (in Hex). This has been removed because it make a lot of things a pain, and it's arguably an unneeded use case anyway. As such, all hashes will be left-padded to 16 bytes as required (by default, and unnegotiable).

## Issues/Contributions

If you spot any issues with the implementation, please file an [issue](http://github.com/zackehh/siphash-elixir/issues) or even a PR. The faster we can make it, the better!

Make sure to test your changes though!

```bash
$ mix test --trace  # test successes/failures
$ mix coveralls     # code coverage, try keep 100% please!
```
