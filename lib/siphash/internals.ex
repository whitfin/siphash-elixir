defmodule SipHash.Internals do
  @moduledoc false
  # Internal hashing module for SipHash. This modules makes use of a
  # NIF to override the implementation of `SipHash.Internals.hash/5` in
  # order to improve performance. An Elixir implementation is also provided
  # as a fallback. Where possible, the NIF should be used as it is roughly
  # 100x faster, providing sub-microsecond hashing.

  # alias both SipHash.State/Util
  alias SipHash.State, as: State
  alias SipHash.Util, as: Util

  # setup init load
  @on_load :init

  @doc false
  # Loads any NIFs needed for this module. Because we have a valid fallback
  # implementation, we don't have to exit on failure.
  def init do
    case System.get_env("SIPHASH_IMPL") do
      "embedded" ->
        :ok
      _native ->
        :siphash
        |> :code.priv_dir
        |> :filename.join('siphash')
        |> :erlang.load_nif(0)
    end
  end

  @doc """
  This function provides an internal place to carry out any hashing, and allows
  for NIF overrides to provide faster execution. If NIFs are disabled there is a
  fallback implementation to allow the user to continue with only Elixir. This
  comes with a performance penalty but is arguably safer.

  _Warning: DO NOT CALL THIS UNLESS YOU KNOW WHAT YOU'RE DOING. This function
  can be overridden by a native implementation, and so you should not call this
  directly unless you know exactly which values need to be passed. An invalid
  type passed to a NIF **will** crash and terminate your application._
  """
  @spec hash(binary, binary, number, number, false | binary) :: number | binary
  def hash(key, input, c, d, format \\ false) do
    input
    |> Util.process_by_chunk(8, State.initialize(key), fn(state, chunk) ->
        case byte_size(chunk) do
          8 -> State.apply_block(state, chunk, c)
          l -> State.apply_last_block({ chunk, state, l }, byte_size(input), c)
        end
       end)
    |> State.finalize(d)
    |> Util.format(format)
  end

  @doc """
  Used to quickly determine if NIFs have been loaded for this module. Returns
  `true` if it has, `false` if it hasn't.

  ## Examples

      iex> res = case System.get_env("SIPHASH_IMPL") do
      ...>   "embedded" -> false
      ...>   _other -> true
      ...> end
      iex> SipHash.Internals.nif_loaded? == res
      true

  """
  @spec nif_loaded? :: true | false
  def nif_loaded?, do: false

end
