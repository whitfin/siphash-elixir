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

end
