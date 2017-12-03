defmodule SipHash.Digest do
  @moduledoc false
  # Internal hashing module for SipHash. This modules makes use of a
  # NIF to override the implementation of `SipHash.Internals.hash/5` in
  # order to improve performance. An Elixir implementation is also provided
  # as a fallback. Where possible, the NIF should be used as it is roughly
  # 100x faster, providing sub-microsecond hashing.
  use Bitwise
  import Record

  # create a record to represent the state of a hash
  defrecord :digest, v0: nil, v1: nil, v2: nil, v3: nil

  # a 64 bit mask to enforce
  @mask_64 0xFFFFFFFFFFFFFFFF

  # magic 64 bit words
  @initial_v0 0x736f6d6570736575
  @initial_v1 0x646f72616e646f6d
  @initial_v2 0x6c7967656e657261
  @initial_v3 0x7465646279746573

  # setup init load
  @compile :no_native
  @on_load :init

  @doc false
  # Loads any NIFs needed for this module. Because we have a valid fallback
  # implementation, we don't have to exit on failure.
  def init do
    if Application.get_env(:siphash, :disable_nifs) do
      :ok
    else
      :siphash
      |> :code.priv_dir
      |> :filename.join('siphash')
      |> :erlang.load_nif(0)
    end
  end

  # Internal binding to the SipHash internals.
  #
  # This function provides an internal place to carry out any hashing, and allows
  # for NIF overrides to provide faster execution. If NIFs are disabled there is a
  # fallback implementation to allow the user to continue with only Elixir. This
  # comes with a performance penalty but is arguably safer.
  #
  # _Warning: DO NOT CALL THIS UNLESS YOU KNOW WHAT YOU'RE DOING. This function
  # can be overridden by a native implementation, and so you should not call this
  # directly unless you know exactly which values need to be passed. An invalid
  # type passed to a NIF **will** crash and terminate your application._
  @spec hash(binary, binary, integer, integer, binary) :: number | binary
  def hash(key, input, c, d, format \\ nil) do
    { a, b } = :erlang.split_binary(key, 8)

    k0 = :binary.decode_unsigned(a, :little)
    k1 = :binary.decode_unsigned(b, :little)

    initial = digest([
      v0: @initial_v0 ^^^ k0,
      v1: @initial_v1 ^^^ k1,
      v2: @initial_v2 ^^^ k0,
      v3: @initial_v3 ^^^ k1
    ])

    finalized = do_transform(c, d, byte_size(input), input, initial)

    case format do
      "%016lX" ->
        format(finalized)
      "%016lx" ->
        String.downcase(format(finalized))
      _ ->
        finalized
    end
  end

  @doc """
  Used to quickly determine if NIFs have been loaded for this module. Returns
  `true` if it has, `false` if it hasn't.

  ## Examples

      iex> SipHash.nif_loaded? == !Application.get_env(:siphash, :disable_nifs)
      true

  """
  @spec nif_loaded? :: boolean
  def nif_loaded?,
    do: false

  # Recursive transformation function to apply digest blocks.
  defp do_transform(c, d, length, << block :: binary-8, rest :: binary >>, digest),
    do: do_transform(c, d, length, rest, apply_block(digest, block, c))
  defp do_transform(c, d, length, << block :: binary >>, digest) do
    digest
    |> apply_last_block(block, c, length)
    |> finalize(d)
  end

  # Applies a block (an 8-byte chunk) to the digest.
  #
  # The provided block is converted to a number before being applied to
  # the digest. First we XOR v3 before running through compression using
  # `c` rounds of compression. Then we XOR v0 and return the new digest.
  defp apply_block(digest(v3: v3) = digest, block, c) do
    m = :binary.decode_unsigned(block, :little)

    digest = digest(digest, v3: v3 ^^^ m)
    digest = compress(digest, c)
    digest(v0: v0) = digest

    digest(digest, v0: v0 ^^^ m)
  end

  # Applies a last-block transformation to the digest.
  #
  # This block may be less than 8-bytes, and if so we pad it with zeroed bytes
  # (up to 7 bytes). We then add the length of the input as a byte and update
  # using the block as normal.
  defp apply_last_block(digest, block, c, length) do
    last_block = case byte_size(block) do
      7 -> block
      l -> block <> :binary.copy(<<0>>, 7 - l)
    end
    apply_block(digest, last_block <> <<length>>, c)
  end

  # Provides a recursive wrapper around `compress/1`.
  defp compress(digest, 0),
    do: digest
  defp compress(digest, i),
    do: compress(compress(digest), i - 1)

  # Performs SipRound on the provided digest.
  defp compress(digest(v0: v0, v1: v1, v2: v2, v3: v3)) do
    v0 = (v0 + v1) &&& @mask_64
    v2 = (v2 + v3) &&& @mask_64
    v1 = rotate_left(v1, 13);
    v3 = rotate_left(v3, 16);

    v1 = v1 ^^^ v0
    v3 = v3 ^^^ v2
    v0 = rotate_left(v0, 32);

    v2 = (v2 + v1) &&& @mask_64
    v0 = (v0 + v3) &&& @mask_64
    v1 = rotate_left(v1, 17);
    v3 = rotate_left(v3, 21);

    v1 = v1 ^^^ v2
    v3 = v3 ^^^ v0
    v2 = rotate_left(v2, 32);

    digest(v0: v0, v1: v1, v2: v2, v3: v3)
  end

  # Finalizes a digest by XOR'ing v2 and performing SipRound `d` times.
  defp finalize(digest(v2: v2) = digest, d) do
    digest = digest(digest, v2: v2 ^^^ 0xff)

    digest(v0: v0, v1: v1, v2: v2, v3: v3) = compress(digest, d)

    (v0 ^^^ v1 ^^^ v2 ^^^ v3)
  end

  # Formats a final results as a binary.
  defp format(num) do
    bin = :erlang.integer_to_binary(num, 16)

    case byte_size(bin) do
      n when n < 16 ->
        :binary.copy(<<0>>, 16 - n)
      _ ->
        bin
    end
  end

  # Rotates an input number `val` left by `shift` number of bits.
  defp rotate_left(value, shift),
    do: ((value <<< shift) &&& @mask_64) ||| (value >>> (64 - shift))
end
