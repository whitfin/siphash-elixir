defmodule SipHash do
  use Bitwise
  @moduledoc """
  Module for hashing values using the SipHash hash family.

  This module makes use of NIFs for better performance and throughput, but this
  can be disabled by setting the `HASH_IMPL` environment variable to `embedded`.
  This is controlled via the environment rather than a specific function arg as
  the NIFs are automatically loaded during the start of the application. Please
  note that the use of NIFs brings a significant performance improvement, and so
  you should only disable them with good reason.

  Due to the use of NIFs, please only use the public `SipHash` functions. Do not
  rely on the behaviour of any submodules, as incorrect use of native functions
  can result in crashes in your application.
  """

  # alias both SipHash.State/Util
  alias SipHash.State, as: State
  alias SipHash.Util, as: Util

  # store key error message
  @kerr "Key must be exactly 16 bytes!"

  # define types
  @type s :: { number, number, number, number }

  @doc """
  Based on the algorithm as described in https://131002.net/siphash/siphash.pdf,
  and therefore requires a key alongside the input to use as a seed. This key
  should consist of 16 bytes, and is measured by `Kernel.byte_size/1`. An error
  will be raised if this is not the case. The default implementation is a 2-4
  hash, but this can be controlled through the options provided.

  In the interest of performance; if you're repeatedly using the same key it's
  possible to create an initial state from your key once, thus avoiding wasted
  key calculations. This can be created by calling `SipHash.init/1` with your
  key. The returned state can be provided instead of a key when hashing; this
  shaves roughly ~0.5 µs/op, so it's recommended to use this method when possible.

  Your input *must* be a binary. It's possible to add a catch-all to `SipHash.hash/3`
  which simply wraps the input in `Kernel.inspect/2`, but such usage is not
  encouraged. It's better to be more explicit about what is being hashed, and
  `Kernel.inspect/2` does not always perform the fastest available conversion
  (for example, using Poison to encode Maps is far faster, whilst also being more
  reliable). In addition, the output of `Kernel.inspect/2` is specific to Elixir,
  making it annoyingly unportable.

  By default, all values are returned as numbers (i.e. the result of the hash),
  but you can set `:hex` to true as an option to get a hex string output. The
  reason for this is that converting to hex takes an extra couple of µs, and the
  default is intended to be the optimal use case. Please note that any of the
  options related to hex string formatting will be ignored if `:hex` is not set
  to true (e.g. `:case`).

  ## Options

    * `:case` - either of `:upper` or `:lower`, defaults to using `:upper`
    * `:c` and `:d` - the number of compression rounds, default to `2` and `4`
    * `:hex` - when `true` returns the output as a hex string, defaults to `false`

  ## Examples

      iex> SipHash.hash("0123456789ABCDEF", "hello")
      4402678656023170274

      iex> SipHash.init("0123456789ABCDEF") |> SipHash.hash("hello")
      4402678656023170274

      iex> SipHash.hash("0123456789ABCDEF", "hello", hex: true)
      "3D1974E948748CE2"

      iex> SipHash.hash("0123456789ABCDEF", "abcdefgh", hex: true)
      "1AE57886F899E65F"

      iex> SipHash.hash("0123456789ABCDEF", "my long strings", hex: true)
      "1323400B0804036D"

      iex> SipHash.hash("0123456789ABCDEF", "hello", hex: true, case: :lower)
      "3d1974e948748ce2"

      iex> SipHash.hash("0123456789ABCDEF", "hello", c: 4, d: 8)
      14986662229302055855

      iex> SipHash.hash("invalid_bytes", "hello")
      ** (RuntimeError) Key must be exactly 16 bytes!

      iex> SipHash.hash("FEDCBA9876543210", %{ "test" => "one" })
      ** (FunctionClauseError) no function clause matching in SipHash.hash/3

  """
  @spec hash(binary | s, binary, [ { atom, atom } ]) :: binary
  def hash({ _v0, _v1, _v2, _v3 } = state, input, opts)
  when is_binary(input) and is_list(opts) do
    length = byte_size(input)
    s_case = :upper
    c_pass = 2
    d_pass = 4
    to_hex = false

    unless Enum.empty?(opts) do
      s_case = Keyword.get(opts, :case, s_case)
      c_pass = Keyword.get(opts, :c, c_pass)
      d_pass = Keyword.get(opts, :d, d_pass)
      to_hex = Keyword.get(opts, :hex, to_hex)
    end

    input
    |> Util.process_by_chunk(8, state, fn(state, chunk) ->
        case byte_size(chunk) do
          8 -> State.apply_block(state, chunk, c_pass)
          l -> State.apply_last_block({ chunk, state, l }, length, c_pass)
        end
       end)
    |> State.finalize(d_pass)
    |> Util.format(to_hex, s_case)
  end
  def hash(key, input, opts) when byte_size(key) == 16 do
    key
    |> State.initialize
    |> hash(input, opts)
  end
  def hash(key, _input, _opts) when is_binary(key), do: raise @kerr
  def hash(key, input), do: hash(key, input, [])

  @doc """
  Takes an initial seed key and creates a state with the initial values for
  v0, v1, v2 and v3. This state can then be provided to `SipHash.hash/3` to
  avoid repeatedly recalculating this step when using the same key for every
  hash.

  ## Examples

      iex> SipHash.init("0123456789ABCDEF")
      {4925064773550298181, 2461839666708829781, 6579568090023412561,
       3611922228250500171}

      iex> SipHash.init("invalid")
      ** (RuntimeError) Key must be exactly 16 bytes!

  """
  @spec init(binary) :: s
  def init(key) when byte_size(key) == 16, do: State.initialize(key)
  def init(_), do: raise @kerr

end
