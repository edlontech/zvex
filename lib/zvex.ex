defmodule Zvex do
  @moduledoc """
  Elixir bindings for zvec, an in-process vector database.
  """

  @doc """
  Returns the zvec library version.

  ## Examples

      iex> version = Zvex.version()
      iex> is_integer(version.major) and is_integer(version.minor) and is_integer(version.patch)
      true
  """
  def version do
    %{
      major: Zvex.Native.version_major(),
      minor: Zvex.Native.version_minor(),
      patch: Zvex.Native.version_patch(),
      raw: Zvex.Native.version()
    }
  end

  @doc """
  Initializes the zvec library with default configuration.
  """
  def initialize do
    Zvex.Native.initialize()
    |> Zvex.Error.from_native()
  end

  @doc """
  Initializes the zvec library with the given configuration.
  """
  def initialize(%Zvex.Config{} = config) do
    with {:ok, _validated} <- Zvex.Config.validate(config) do
      config
      |> Zvex.Config.to_native_map()
      |> Zvex.Native.initialize_with_config()
      |> Zvex.Error.from_native()
    end
  end

  @doc """
  Initializes the zvec library. Raises on error.
  """
  def initialize! do
    initialize()
    |> Zvex.Error.unwrap!()
  end

  @doc """
  Initializes the zvec library with the given configuration. Raises on error.
  """
  def initialize!(%Zvex.Config{} = config) do
    initialize(config)
    |> Zvex.Error.unwrap!()
  end

  @doc """
  Shuts down the zvec library.
  """
  def shutdown do
    Zvex.Native.shutdown()
    |> Zvex.Error.from_native()
  end

  @doc """
  Shuts down the zvec library. Raises on error.
  """
  def shutdown! do
    shutdown()
    |> Zvex.Error.unwrap!()
  end

  @doc """
  Returns whether the zvec library is initialized.
  """
  def initialized? do
    Zvex.Native.is_initialized()
  end
end
