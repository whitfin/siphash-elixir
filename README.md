# SipHash
[![Build Status](https://travis-ci.org/zackehh/siphash-elixir.svg?branch=master)](https://travis-ci.org/zackehh/siphash-elixir) [![Coverage Status](https://coveralls.io/repos/zackehh/siphash-elixir/badge.svg?branch=master&service=github)](https://coveralls.io/github/zackehh/siphash-elixir?branch=master)

An Elixir implementation of the SipHash cryptographic hash family using native components for faster execution. Supports any variation, although defaults to the widely used SipHash-2-4. Previous versions focused on correctness, now there is a larger emphasis on performance optimizations as I intend to use it in a production environment (so naturally correctness will be upheld).

## Installation

This package can be installed via Hex:

  1. Add siphash to your list of dependencies in `mix.exs`:

        def deps do
          [{:siphash, "~> 2.0.0"}]
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

## Migration to v2.x

Naturally I'm forced to I take back what I said in the v1.1.0 notes; v2.0.0 is now almost 20x faster than the original implementation (when using NIFs). Without NIFs it's only a few microseconds faster than v1.1.0, but faster nonetheless. Turns out the 64-bit masks in v1.x were causing a bottleneck (since they have to be applied so often). Once these were migrated to NIFs, everything became much faster.

If for any reason you desire to use the pure Elixir implementation without using NIFs, you can set the `HASH_IMPL` environment variable to `embedded`. Please note that there is likely a significant performance hit when doing this, so I don't recommend it. The embedded implementation is also the fallback in case a NIF cannot be loaded for some reason (a message is logged on startup displaying which implementation is being used).

This release also made `SipHash.hash/3` come more inline with actual SipHash, in that it returns the numeric result rather than Hex. The reason for this is that the Hex conversion is additional overhead, and it's incorrect to assume everyone wants this format. To replicate the old behaviour, just supply `hex: true` in the option list passed to `SipHash.hash/3` (example above).

## Issues/Contributions

If you spot any issues with the implementation, please file an [issue](http://github.com/zackehh/siphash-elixir/issues) or even a PR. The faster we can make it, the better!

Make sure to test your changes though!

```bash
$ mix test --trace  # test successes/failures
$ mix coveralls     # code coverage, try keep 100% please!
```
