defmodule SipHash.State do
  use Bitwise
  @moduledoc """
  Module for representing state and state transformations of a digest
  whilst moving through the hasing pipeline.
  """

  # alias SipHash.Util for fast use
  alias SipHash.Util, as: Utils

  # define a state struct of v0, v1, v2, v3
  # as defined by the SipHash specifications
  defstruct v0: nil, v1: nil, v2: nil, v3: nil

  # define types
  @type s :: %SipHash.State { }

  # magic 64 bit words
  @initial_v0 0x736f6d6570736575
  @initial_v1 0x646f72616e646f6d
  @initial_v2 0x6c7967656e657261
  @initial_v3 0x7465646279746573

  @doc """
  Applies a block (an 8-byte chunk) to the digest, and returns the state after
  transformation. If a binary chunk is passed in, it's converted to a number (as
  little endian) before being passed to the main body. First we XOR v3 before
  compressing the state twice. Once complete, we then XOR v0, and return the
  final state.
  """
  @spec apply_block(s, binary | number, number) :: s
  def apply_block(%SipHash.State{ } = state, m, c) when is_binary(m) and is_number(c) do
    apply_block(state, Utils.bytes_to_long(m), c)
  end
  def apply_block(%SipHash.State{ } = state, m, c) when is_number(m) and is_number(c) do
    state = %SipHash.State{ state | v3: state.v3 ^^^ m }
    state = compress(state, c)
    state = %SipHash.State{ state | v0: state.v0 ^^^ m }
    state
  end

  @doc """
  Provides a recursive wrapper around `SipHash.Util.compress/1`. Used to easily
  modify the c-d values of the SipHash algorithm.
  """
  @spec compress(s, number) :: s
  def compress(%SipHash.State{ } = state, n) when n > 0 do
    state |> compress |> compress(n - 1)
  end
  def compress(%SipHash.State{ } = state, 0), do: state

  @doc """
  Performs the equivalent of SipRound on the provided state, making sure to mask
  numbers as it goes (because Elixir precision gets too large). Once all steps
  are completed, the new state is returned.

  Incidentally, this function is named `SipHash.State.compress/1` rather than
  `SipHash.State.round/1` to avoid clashing with `Kernel.round/1` internally.
  """
  @spec compress(s) :: s
  def compress(%SipHash.State{ v0: v0, v1: v1, v2: v2, v3: v3 }) do
    v0 = Utils.apply_mask64(v0 + v1)
    v2 = Utils.apply_mask64(v2 + v3)
    v1 = rotate_left(v1, 13);
    v3 = rotate_left(v3, 16);

    v1 = v1 ^^^ v0
    v3 = v3 ^^^ v2
    v0 = rotate_left(v0, 32);

    v2 = Utils.apply_mask64(v2 + v1)
    v0 = Utils.apply_mask64(v0 + v3)
    v1 = rotate_left(v1, 17);
    v3 = rotate_left(v3, 21);

    v1 = v1 ^^^ v2
    v3 = v3 ^^^ v0
    v2 = rotate_left(v2, 32);

    %SipHash.State{ v0: v0, v1: v1, v2: v2, v3: v3 }
  end

  @doc """
  Finalizes a digest by XOR'ing v2 and performing SipRound `d` times. After the
  rotation, all properties of the state are XOR'd from left to right.
  """
  @spec finalize(s, number) :: s
  def finalize(%SipHash.State{ } = state, d) when is_number(d) do
    %SipHash.State{ state | v2: state.v2 ^^^ 0xff }
     |> compress(d)
     |> (&(&1.v0 ^^^ &1.v1 ^^^ &1.v2 ^^^ &1.v3)).()
  end

  @doc """
  Initializes a state based on an input key, using the technique defined in
  the SipHash specifications. First we take the input key, split it in two,
  and convert to the little endian version of the bytes. We then create a struct
  using the magic numbers and XOR them against the two key words created.
  """
  @spec initialize(binary) :: s
  def initialize(key) when is_binary(key) do
    [k0,k1] =
      key
      |> String.split_at(8)
      |> Tuple.to_list
      |> Enum.map(&Utils.bytes_to_long/1)

    %SipHash.State{
      v0: @initial_v0 ^^^ k0,
      v1: @initial_v1 ^^^ k1,
      v2: @initial_v2 ^^^ k0,
      v3: @initial_v3 ^^^ k1
    }
  end

  @doc """
  Rotates an input number `val` left by `shift` number of bits. Bits which are
  pushed off to the left are rotated back onto the right, making this a left
  rotation (a circular shift).

  ## Examples

      iex> SipHash.State.rotate_left(8, 3)
      64

      iex> SipHash.State.rotate_left(3, 8)
      768

  """
  @spec rotate_left(number, number) :: number
  def rotate_left(val, shift) when is_number(val) and is_number(shift) do
    Utils.apply_mask64(val <<< shift) ||| (val >>> (64 - shift))
  end

end
