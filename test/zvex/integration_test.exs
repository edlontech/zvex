defmodule Zvex.IntegrationTest do
  use ExUnit.Case, async: false

  doctest Zvex

  setup do
    on_exit(fn ->
      if Zvex.initialized?(), do: Zvex.shutdown()
    end)

    :ok
  end

  describe "version/0" do
    test "returns a map with version components" do
      version = Zvex.version()

      assert is_map(version)
      assert is_integer(version.major)
      assert is_integer(version.minor)
      assert is_integer(version.patch)
      assert is_binary(version.raw)
      assert version.major >= 0
      assert version.minor >= 0
      assert version.patch >= 0
      assert byte_size(version.raw) > 0
    end
  end

  describe "initialize/shutdown lifecycle" do
    test "initialize returns :ok" do
      assert :ok = Zvex.initialize()
      assert Zvex.initialized?()
    end

    test "shutdown returns :ok after init" do
      assert :ok = Zvex.initialize()
      assert :ok = Zvex.shutdown()
      refute Zvex.initialized?()
    end

    test "initialized? reflects state across lifecycle" do
      refute Zvex.initialized?()
      assert :ok = Zvex.initialize()
      assert Zvex.initialized?()
      assert :ok = Zvex.shutdown()
      refute Zvex.initialized?()
    end

    test "double initialize behavior is documented" do
      assert :ok = Zvex.initialize()

      case Zvex.initialize() do
        :ok ->
          assert Zvex.initialized?()

        {:error, %{class: class}} when class in [:invalid, :conflict, :unknown] ->
          assert Zvex.initialized?()
      end
    end
  end

  describe "bang variants" do
    test "initialize! returns :ok" do
      assert :ok = Zvex.initialize!()
    end

    test "shutdown! returns :ok after init" do
      Zvex.initialize!()
      assert :ok = Zvex.shutdown!()
    end
  end
end
