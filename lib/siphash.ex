defmodule SipHash do
  @moduledoc """
  This module provides a simple but performant interface for hashing values using
  the SipHash hash family.

  The `SipHash.hash/3` function allows for flags specifying things such as the
  number of rounds of compression, allowing use of SipHash-C-D, where `C` and `D`
  are customizable. Values can be converted to hexidecimal strings as required,
  but by default this module deals with numbers (as that's the optimal way to
  work with these hashes).

  _**Note**:  This module makes use of NIFs for better performance and throughput,
  but this can be disabled by setting the `SIPHASH_IMPL` environment variable
  to the value "embedded". Please note that the use of NIFs brings a significant
  performance improvement, and so you should only disable them with good reason._
  """
  use Bitwise

  # alias SipHash.Internals
  alias SipHash.Internals

  # store key error message
  @kerr "Key must be exactly 16 bytes!"

  # store input error message
  @ierr "Hash input must be a binary!"

  # passes error message
  @perr "Passes C and D must be valid numbers greater than 0!"

  @doc """
  Based on the algorithm as described in https://131002.net/siphash/siphash.pdf,
  and therefore requires a key alongside the input to use as a seed. This key
  should consist of 16 bytes, and is measured by `byte_size/1`. An error
  will be returned if this is not the case. The default implementation is a 2-4
  hash, but this can be controlled through the options provided.

  This function returns output as a tuple with either format of `{ :ok, value }`
  or `{ :error, message }`. By default, all values are returned as numbers
  (i.e. the result of the hash), but you can set `:hex` to true as an option to
  get a hex string output. The reason for this is that converting to hex typically
  takes an extra couple of microseconds, and the default is intended to be the
  optimal use case. lease note that any of the options related to hex string
  formatting will be ignored if `:hex` is not set to true (e.g. `:case`).

  ## Options

    * `:case` - either of `:upper` or `:lower` (defaults to using `:upper`)
    * `:c` and `:d` - the number of compression rounds (default to 2 and 4)
    * `:hex` - when true returns the output as a hex string (defaults to false)

  ## Examples

      iex> SipHash.hash("0123456789ABCDEF", "hello")
      { :ok, 4402678656023170274 }

      iex> SipHash.hash("0123456789ABCDEF", "hello", hex: true)
      { :ok, "3D1974E948748CE2" }

      iex> SipHash.hash("0123456789ABCDEF", "abcdefgh", hex: true)
      { :ok, "1AE57886F899E65F" }

      iex> SipHash.hash("0123456789ABCDEF", "my long strings", hex: true)
      { :ok, "1323400B0804036D" }

      iex> SipHash.hash("0123456789ABCDEF", "hello", hex: true, case: :lower)
      { :ok, "3d1974e948748ce2" }

      iex> SipHash.hash("0123456789ABCDEF", "hello", c: 4, d: 8)
      { :ok, 14986662229302055855 }

      iex> SipHash.hash("invalid_bytes", "hello")
      { :error, "Key must be exactly 16 bytes!" }

      iex> SipHash.hash("0123456789ABCDEF", "hello", c: 0, d: 0)
      { :error, "Passes C and D must be valid numbers greater than 0!" }

      iex> SipHash.hash("0123456789ABCDEF", %{ "test" => "one" })
      { :error, "Hash input must be a binary!" }

  """
  @spec hash(binary, binary, [ { atom, atom } ]) :: { atom, binary }
  def hash(key, input, opts \\ [])
  def hash(key, _input, _opts) when byte_size(key) != 16, do: { :error, @kerr }
  def hash(_key, input, _opts) when not is_binary(input), do: { :error, @ierr }
  def hash(key, input, opts) when is_binary(input) and is_list(opts) do
    c_pass = Keyword.get(opts, :c, 2)
    d_pass = Keyword.get(opts, :d, 4)

    case valid_passes?(c_pass, d_pass) do
      :error ->
        { :error, @perr }
      :ok ->
        format = if Keyword.get(opts, :hex) do
          case Keyword.get(opts, :case, :upper) do
            :lower -> "%016lx"
            _upper -> "%016lX"
          end
        else
          false
        end

        result = if format do
          Internals.hash(key, input, c_pass, d_pass, format)
        else
          Internals.hash(key, input, c_pass, d_pass)
        end

        { :ok, result }
    end
  end

  @doc """
  A functional equivalent of `SipHash.hash/3`, but rather than returning the
  value inside a tuple the value is returned instead. Any errors will be raised
  as exceptions. There are typically very few cases causing errors which aren't
  due to programmer error, but caution is advised all the same.

  ## Examples

      iex> SipHash.hash!("0123456789ABCDEF", "hello")
      4402678656023170274

      iex> SipHash.hash!("0123456789ABCDEF", "hello", hex: true)
      "3D1974E948748CE2"

      iex> SipHash.hash!("0123456789ABCDEF", "abcdefgh", hex: true)
      "1AE57886F899E65F"

      iex> SipHash.hash!("0123456789ABCDEF", "my long strings", hex: true)
      "1323400B0804036D"

      iex> SipHash.hash!("0123456789ABCDEF", "hello", hex: true, case: :lower)
      "3d1974e948748ce2"

      iex> SipHash.hash!("0123456789ABCDEF", "hello", c: 4, d: 8)
      14986662229302055855

      iex> SipHash.hash!("invalid_bytes", "hello")
      ** (ArgumentError) Key must be exactly 16 bytes!

      iex> SipHash.hash!("0123456789ABCDEF", "hello", c: 0, d: 0)
      ** (ArgumentError) Passes C and D must be valid numbers greater than 0!

      iex> SipHash.hash!("0123456789ABCDEF", %{ "test" => "one" })
      ** (ArgumentError) Hash input must be a binary!

  """
  @spec hash!(binary, binary, [ { atom, atom } ]) :: binary
  def hash!(key, input, opts \\ []) do
    case hash(key, input, opts) do
      { :ok, hash } -> hash
      { :error, msg } -> raise ArgumentError, message: msg
    end
  end

  @doc """
  Used to quickly determine if NIFs have been loaded for this module. Returns
  true if it has, false if it hasn't. This will only return false if either the
  `SIPHASH_IMPL` environment variable is set to "embedded", or there was an error
  when compiling the C implementation.
  """
  @spec nif_loaded? :: true | false
  defdelegate nif_loaded?, to: Internals

  # Determines whether the `c` and `d` values are passed in are valid numbers
  # and larger than 0 (it would make no sense to skip a compression). We return
  # an `:ok` atom if validation passes, otherwise `:error`.
  defp valid_passes?(c, d) when c > 0 and d > 0, do: :ok
  defp valid_passes?(_c, _d), do: :error

end
