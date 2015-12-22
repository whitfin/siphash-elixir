# SipHash
[![Build Status](https://travis-ci.org/zackehh/siphash-elixir.svg?branch=master)](https://travis-ci.org/zackehh/siphash-elixir) [![Coverage Status](https://coveralls.io/repos/zackehh/siphash-elixir/badge.svg?branch=master&service=github)](https://coveralls.io/github/zackehh/siphash-elixir?branch=master)

An Elixir implementation of the SipHash cryptographic hash family. Supports any variation, although defaults to SipHash-2-4. Current implementation aims to be functional with a focus on correctness; future versions will focus more on speed.

## Installation

This package can be installed via Hex:

  1. Add siphash to your list of dependencies in `mix.exs`:

        def deps do
          [{:siphash, "~> 1.0.0"}]
        end

  2. Ensure siphash is started before your application:

        def application do
          [applications: [:siphash]]
        end

## Quick Usage

It's straightforward to get going, you just supply your key and input to `SipHash.hash/2`.

```elixir
iex(1)> SipHash.hash("0123456789ABCDEF", "Hello, World!")
"EAC3F88552D81B4A"
```

For further examples, as well as different flags to customize output, please see the [documentation](http://hexdocs.pm/siphash/SipHash.html).

## Issues/Contributions

If you spot any issues with the implementation, please file an [issue](http://github.com/zackehh/siphash-elixir/issues) or even a PR. The faster we can make it, the better!

Make sure to test your changes though!

```bash
$ mix test --trace  # test successes/failures
$ mix coveralls     # code coverage, try keep 100% please!
```
