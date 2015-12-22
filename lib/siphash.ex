defmodule SipHash do
  use Bitwise
  @moduledoc """
  Module for hashing values using the SipHash hash family.
  """

  # alias both SipHash.State/Util
  alias SipHash.State, as: State
  alias SipHash.Util, as: Utils

  # define the (constant) grouping pattern
  @eighth_group_regex ~r/.{1,8}/

  @doc """
  Based on the algorithm as described in https://131002.net/siphash/siphash.pdf,
  and therefore requires a key alongside the input to use as a seed. This key
  is required to be 16 bytes, and is measured by `Kernel.byte_size/1`. An error
  will be raised if this is not the case. The default implementation is a 2-4
  hash, but this can be controlled through the options provided.

  Your input *must* be a binary. It's possible to add a catch-all to `SipHash.hash/3`
  which simply wraps the input in `Kernel.inspect/1`, but such usage is not
  encourage. It's better to be more explicit about what is being hashed, and
  `Kernel.inspect/1` does not always perform the fastest available conversion
  (for example, using Poison to encode Maps is far faster, whilst also being more
  reliable). In addition, the output of `Kernel.inspect/1` is specific to Elixir,
  making it annoyingly unportable.

  The current implementation is just a functional hash, with more effort on the
  code being readable rather than optimized, and as such it's likely to change
  in future (if it needs speeding up).

  ## Options

    * `:case` - either of `:upper` or `:lower`, defaults to using `:upper`
    * `:c` and `:d` - the number of compression rounds, default to `2` and `4`
    * `:padding` - when `true`, pads left with zeroes to 16 chars as necessary

  ## Examples

      iex> SipHash.hash("0123456789ABCDEF", "hello")
      "3D1974E948748CE2"

      iex> SipHash.hash("0123456789ABCDEF", "this is a longer input")
      "C7D6D8A1E7D359DD"

      iex> SipHash.hash("0123456789ABCDEF", "hello", case: :lower)
      "3d1974e948748ce2"

      iex> SipHash.hash("0123456789ABCDEF", "zymotechnics", padding: :true)
      "09B57037CD3F8F0C"

      iex> SipHash.hash("0123456789ABCDEF", "hello", c: 4, d: 8)
      "CFFB51E5125013AF"

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

    length = byte_size(input)
    remain = rem(length, 8)
    s_case = Keyword.get(opts, :case, :upper)
    c_pass = Keyword.get(opts, :c, 2)
    d_pass = Keyword.get(opts, :d, 4)
    l_pad  = Keyword.get(opts, :padding, false)
    state  = State.initialize(key)
    chunks = Regex.scan(@eighth_group_regex, input)
    last_m = Utils.apply_mask64(length <<< 56)

    state =
      chunks
      |> Stream.map(&List.first/1)
      |> Stream.take_while(&(byte_size(&1) == 8))
      |> Enum.reduce(state, (&State.apply_block(&2, &1, c_pass)))

    if remain > 0 do
      { _, last_m } =
        chunks
        |> List.last
        |> List.first
        |> String.reverse
        |> String.codepoints
        |> Enum.reduce({ remain, last_m }, fn(point, acc) ->
            { index, last_m } = acc

            next_index  = index - 1
            point_bytes = Utils.bytes_to_long(point)

            right_side =
              if remain >= index and index != 1 do
                (point_bytes <<< (next_index * 8))
              else
                point_bytes
              end

            { next_index, (last_m ||| right_side) }
           end)
    end

    state
    |> State.apply_block(last_m, c_pass)
    |> State.finalize(d_pass)
    |> Integer.to_string(16)
    |> (&(if s_case == :upper, do: &1, else: String.downcase(&1))).()
    |> (&(if l_pad == false, do: &1, else: String.rjust(&1, 16, ?0))).()
  end

  @doc """
  Wrapper around `SipHash.hash/3` to rotate the arguments, allowing for more
  convenient usage when creating a pipeline (you can rotate key/input as needed).

  ## Examples

      iex> SipHash.hash_r("hello", "0123456789ABCDEF")
      "3D1974E948748CE2"

      iex> SipHash.hash_r("this is a longer input", "0123456789ABCDEF")
      "C7D6D8A1E7D359DD"

      iex> SipHash.hash_r("hello", "0123456789ABCDEF", case: :lower)
      "3d1974e948748ce2"

      iex> SipHash.hash_r("zymotechnics", "0123456789ABCDEF", padding: :true)
      "09B57037CD3F8F0C"

      iex> SipHash.hash_r("hello", "invalid_bytes")
      ** (RuntimeError) Key must be exactly 16 bytes.

      iex> SipHash.hash_r(%{ "test" => "one" }, "FEDCBA9876543210")
      ** (FunctionClauseError) no function clause matching in SipHash.hash/3

  """
  @spec hash_r(binary, binary, [ { atom, atom } ]) :: binary
  def hash_r(input, key, opts \\ []), do: hash(key, input, opts)

end
