defmodule SipHash.Util do
  use Bitwise
  @moduledoc """
  Utility module for minor masking and binary conversions.
  """

  # a mask for forcing to 64 bits
  @mask_64 0xFFFFFFFFFFFFFFFF

  # define native implementation
  @native_impl [".", "_native", "util"] |> Path.join |> Path.expand

  # setup init load
  @on_load :init

  @doc """
  Loads any NIFs needed for this module. Because we have a valid fallback
  implementation, we don't have to exit on failure.
  """
  def init do
    case System.get_env("UTIL_IMPL") do
      "embedded" -> :ok;
      _other -> :erlang.load_nif(@native_impl, 0)
    end
  end

  @doc """
  Applies a 64 bit mask to the passed in number to force it to use only 64 bits.
  Any bits extending further than the 64th bit are zeroed and dropped.

  ## Examples

      iex> SipHash.Util.apply_mask64(9223372036854775808)
      9223372036854775808

      iex> SipHash.Util.apply_mask64(92233720368547758077)
      18446744073709551613

      iex> SipHash.Util.apply_mask64("test_string")
      ** (FunctionClauseError) no function clause matching in SipHash.Util.apply_mask64/1

  """
  @spec apply_mask64(number) :: number
  def apply_mask64(input) when is_number(input), do: input &&& @mask_64

  @doc """
  Converts a binary input to an unsigned number using little endian.

  ## Examples

      iex> SipHash.Util.bytes_to_long(<<169,138,199>>)
      13077161

      iex> SipHash.Util.bytes_to_long("test_string")
      125040764888893876906190196

      iex> SipHash.Util.bytes_to_long(5)
      ** (FunctionClauseError) no function clause matching in SipHash.Util.bytes_to_long/1

  """
  @spec bytes_to_long(binary) :: number
  def bytes_to_long(input) when is_binary(input) do
    :binary.decode_unsigned(input, :little)
  end

  @doc """
  Formats a resulting hash into a chosen format. Arguments are provided by the
  options passed in by the user when `SipHash.hash/3` is called. The internal
  version of this function is overridden by a NIF which uses `sprintf` to do the
  any formatting. The Elixir implementation just pattern matches on the format
  chars and provides an backup. The NIF implementation is roughly 1 microsecond
  quicker, so it's worth the override.

  ## Examples

      iex> SipHash.Util.format(699588702094987020, false, :upper)
      699588702094987020

      iex> SipHash.Util.format(699588702094987020, true, :upper)
      "09B57037CD3F8F0C"

      iex> SipHash.Util.format(699588702094987020, true, :lower)
      "09b57037cd3f8f0c"

  """
  @spec format(binary, true | false | binary, atom) :: binary
  def format(input, false, _case), do: input
  def format(input, true, :upper), do: format(input, "%016lX")
  def format(input, true, :lower), do: format(input, "%016lx")
  @doc false
  def format(num, "%016lX") do
    num
    |> to_hex
    |> pad_left
  end
  def format(num, "%016lx") do
    num
    |> to_hex
    |> to_case(:lower)
    |> pad_left
  end

  @doc """
  Used to quickly determine if NIFs have been loaded for this module. Returns
  `true` if it has, `false` if it hasn't.

  ## Examples

      iex> res = case System.get_env("UTIL_IMPL") do
      ...>   "embedded" -> false
      ...>   _other -> true
      ...> end
      iex> SipHash.Util.nif_loaded? == res
      true

  """
  @spec nif_loaded? :: true | false
  def nif_loaded?, do: false

  @doc """
  Pads a binary input with zeroes. If the provided input is not a binary, simply
  return the value passed in.

  ## Examples

      iex> SipHash.Util.pad_left("12345678")
      "0000000012345678"

      iex> SipHash.Util.pad_left(12345678)
      12345678

  """
  @spec pad_left(binary) :: binary
  def pad_left(input) when not is_binary(input), do: input
  def pad_left(input), do: String.rjust(input, 16, ?0)

  @doc """
  Chunks a binary into groups of N, where N is a value passed in. If a group
  does not have enough chars to be chunked into a group of N, it is added as is.
  A function is provided to process binaries in a single pass, to avoid iterating
  the bytes twice (as was the case in previous versions).

  ## Examples

      iex> SipHash.Util.process_by_chunk("12345678", 4, {}, &(Tuple.append/2))
      {"1234", "5678", ""}

      iex> SipHash.Util.process_by_chunk(12345678, 4, {}, &(Tuple.append/2))
      ** (FunctionClauseError) no function clause matching in SipHash.Util.process_by_chunk/4

  """
  # @spec process_by_chunk(binary, number, any, (any, binary -> any)) :: any
  def process_by_chunk(input, size, state, fun) when byte_size(input) >= size do
    { chunk, rest } = :erlang.split_binary(input, size)
    process_by_chunk(rest, size, fun.(state, chunk), fun)
  end
  def process_by_chunk(input, _size, state, fun) when is_binary(input) do
    fun.(state, input)
  end

  @doc """
  Converts a binary input to the provided case. If the provided input is not a
  binary, simply return the value passed in.

  ## Examples

      iex> SipHash.Util.to_case("TEST", :lower)
      "test"

      iex> SipHash.Util.to_case("test", :upper)
      "TEST"

      iex> SipHash.Util.to_case(5, :upper)
      5

  """
  @spec to_case(binary, atom) :: binary
  def to_case(input, _case) when not is_binary(input), do: input
  def to_case(input, :upper), do: String.upcase(input)
  def to_case(input, :lower), do: String.downcase(input)

  @doc """
  Converts a number input to a base-16 output (as a string). If the first arg
  is not a number, simple return the first argument as is.

  ## Examples

      iex> SipHash.Util.to_hex(1215135325)
      "486D7E5D"

      iex> SipHash.Util.to_hex("test")
      "test"

  """
  @spec to_hex(number) :: binary
  def to_hex(num) when not is_number(num), do: num
  def to_hex(num), do: :erlang.integer_to_binary(num, 16)

end
