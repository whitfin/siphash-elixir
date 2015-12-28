defmodule SipHash.Util do
  use Bitwise
  @moduledoc """
  Utility module for minor masking and binary conversions.
  """

  # a mask for forcing to 64 bits
  @mask_64 0xFFFFFFFFFFFFFFFF

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
  Chunks a binary input into groups of N, where N is passed in. If a group does
  not have enough chars to be chunked again, it will be added to the list as is.

  ## Examples

      iex> SipHash.Util.chunk_string("12345678", 4)
      ["1234","5678"]

  """
  @spec chunk_string(binary, number) :: list
  def chunk_string(str, n) when byte_size(str) >= n do
    { chunk, rest } = :erlang.split_binary(str, n)
    [chunk|chunk_string(rest, n)]
  end
  def chunk_string(<<>>, _), do: []
  def chunk_string(str, _), do: [str]

  @doc """
  Pads a binary input with zeroes. This only occurs when the second argument
  is `true`, otherwise there's a short-circuit to return the input as is. This
  is due to the options being passed to `SipHash.hash/3` being the primary use
  case here. If the provided input is not a binary, simply return the value
  passed in.

  ## Examples

      iex> SipHash.Util.pad_left("12345678", true)
      "0000000012345678"

      iex> SipHash.Util.pad_left("12345678", false)
      "12345678"

      iex> SipHash.Util.pad_left(12345678, false)
      12345678

  """
  @spec pad_left(binary, true | false) :: binary
  def pad_left(s, _) when not is_binary(s), do: s
  def pad_left(s, false), do: s
  def pad_left(s, true), do: String.rjust(s, 16, ?0)

  @doc """
  Converts a binary input to the provided case, short circuiting if the input
  is already in the correct case (specified in the third parameter). If the
  provided input is not a binary, simply return the value passed in.

  ## Examples

      iex> SipHash.Util.to_case("test", :lower, :lower)
      "test"

      iex> SipHash.Util.to_case("test", :upper, :lower)
      "TEST"

      iex> SipHash.Util.to_case("TEST", :lower, :upper)
      "test"

      iex> SipHash.Util.to_case("TEST", :upper, :upper)
      "TEST"

      iex> SipHash.Util.to_case(5, :upper, :upper)
      5

  """
  @spec to_case(binary, atom, atom) :: binary
  def to_case(s, _, _) when not is_binary(s), do: s
  def to_case(s, t, t), do: s
  def to_case(s, :lower, _), do: String.downcase(s)
  def to_case(s, :upper, _), do: String.upcase(s)

  @spec to_hex(number, true | false) :: binary
  def to_hex(s, false), do: s
  def to_hex(s, true), do: Integer.to_string(s, 16)

end
