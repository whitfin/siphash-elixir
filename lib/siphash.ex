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
  """

  # alias both SipHash.State/Util
  alias SipHash.State, as: State
  alias SipHash.Util, as: Util

  # define types
  @type s :: { number, number, number, number }

  @doc """
  Based on the algorithm as described in https://131002.net/siphash/siphash.pdf,
  and therefore requires a key alongside the input to use as a seed. This key
  is required to be 16 bytes, and is measured by `Kernel.byte_size/1`. An error
  will be raised if this is not the case. The default implementation is a 2-4
  hash, but this can be controlled through the options provided.

  Your input *must* be a binary. It's possible to add a catch-all to `SipHash.hash/3`
  which simply wraps the input in `Kernel.inspect/2`, but such usage is not
  encourage. It's better to be more explicit about what is being hashed, and
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
    * `:hex` - when `true` returns the output as a hex string
    * `:padding` - when `true`, pads left with zeroes to 16 chars as necessary

  ## Examples

      iex> SipHash.hash("0123456789ABCDEF", "hello")
      4402678656023170274

      iex> SipHash.hash("0123456789ABCDEF", "hello", hex: true)
      "3D1974E948748CE2"

      iex> SipHash.hash("0123456789ABCDEF", "abcdefgh", hex: true)
      "1AE57886F899E65F"

      iex> SipHash.hash("0123456789ABCDEF", "my long strings", hex: true)
      "1323400B0804036D"

      iex> SipHash.hash("0123456789ABCDEF", "hello", hex: true, case: :lower)
      "3d1974e948748ce2"

      iex> SipHash.hash("0123456789ABCDEF", "zymotechnics", hex: true, padding: :true)
      "09B57037CD3F8F0C"

      iex> SipHash.hash("0123456789ABCDEF", "hello", c: 4, d: 8)
      14986662229302055855

      iex> SipHash.hash("invalid_bytes", "hello")
      ** (RuntimeError) Key must be exactly 16 bytes.

      iex> SipHash.hash("FEDCBA9876543210", %{ "test" => "one" })
      ** (FunctionClauseError) no function clause matching in SipHash.hash/3

  """
  @spec hash(binary, binary, [ { atom, atom } ]) :: binary
  def hash(key, input, opts \\ [])
  when is_binary(key) and is_binary(input) and is_list(opts) do
    if byte_size(key) != 16 do
      raise "Key must be exactly 16 bytes."
    end

    in_len = byte_size(input)

    s_case = :upper
    c_pass = 2
    d_pass = 4
    to_hex = false
    l_pad  = false

    case opts do
      [] -> ;
      [_h|_t] ->
        s_case = Keyword.get(opts, :case, s_case)
        c_pass = Keyword.get(opts, :c, c_pass)
        d_pass = Keyword.get(opts, :d, d_pass)
        to_hex = Keyword.get(opts, :hex, to_hex)
        l_pad  = Keyword.get(opts, :padding, l_pad)
    end

    state = SipHash.State.initialize(key)

    input
    |> Util.chunk_string(8)
    |> Enum.reduce(state, fn(chunk, state) ->
        case byte_size(chunk) do
          8 ->
            State.apply_block(state, chunk, c_pass)
          l ->
            { chunk, state, l }
        end
       end)
    |> State.apply_last_block(in_len, c_pass)
    |> State.finalize(d_pass)
    |> Util.to_hex(to_hex)
    |> Util.to_case(s_case, :upper)
    |> Util.pad_left(l_pad)
  end

  @doc """
  Wrapper around `SipHash.hash/3` to rotate the arguments, allowing for more
  convenient usage when creating a pipeline (you can rotate key/input as needed).

  ## Examples

      iex> SipHash.hash_r("hello", "0123456789ABCDEF")
      4402678656023170274

  """
  @spec hash_r(binary, binary | s, [ { atom, atom } ]) :: binary
  def hash_r(input, key_or_state, opts \\ []), do: hash(key_or_state, input, opts)

end
