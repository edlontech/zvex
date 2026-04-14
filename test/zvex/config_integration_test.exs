defmodule Zvex.ConfigIntegrationTest do
  use ExUnit.Case, async: false

  alias Zvex.Config

  setup do
    on_exit(fn ->
      if Zvex.initialized?(), do: Zvex.shutdown()
    end)

    :ok
  end

  describe "initialize/1 with config" do
    test "initializes with default config (all nils)" do
      config = Config.new()
      assert :ok = Zvex.initialize(config)
      assert Zvex.initialized?()
    end

    test "initializes with memory_limit" do
      config = Config.new() |> Config.memory_limit(1_073_741_824)
      assert :ok = Zvex.initialize(config)
    end

    test "initializes with query and optimize threads" do
      config = Config.new() |> Config.query_threads(2) |> Config.optimize_threads(1)
      assert :ok = Zvex.initialize(config)
    end

    test "initializes with console log config" do
      config = Config.new() |> Config.log(:console, level: :warn)
      assert :ok = Zvex.initialize(config)
    end

    test "initializes with all config options" do
      config =
        Config.new()
        |> Config.memory_limit(512_000_000)
        |> Config.query_threads(2)
        |> Config.optimize_threads(1)
        |> Config.invert_to_forward_scan_ratio(0.5)
        |> Config.brute_force_by_keys_ratio(0.1)
        |> Config.log(:console, level: :error)

      assert :ok = Zvex.initialize(config)
    end

    test "shutdown works after configured init" do
      config = Config.new() |> Config.memory_limit(512_000_000)
      assert :ok = Zvex.initialize(config)
      assert :ok = Zvex.shutdown()
      refute Zvex.initialized?()
    end

    test "invalid config returns error without reaching NIF" do
      config = Config.new() |> Config.memory_limit(-1)
      assert {:error, %Zvex.Error.Invalid.Argument{}} = Zvex.initialize(config)
      refute Zvex.initialized?()
    end

    test "double initialize with config" do
      assert :ok = Zvex.initialize()
      config = Config.new() |> Config.memory_limit(512_000_000)

      case Zvex.initialize(config) do
        :ok ->
          assert Zvex.initialized?()

        {:error, %{class: class}} when class in [:invalid, :conflict, :unknown] ->
          assert Zvex.initialized?()
      end
    end
  end

  describe "initialize!/1 bang variant" do
    test "returns :ok with valid config" do
      config = Config.new() |> Config.memory_limit(512_000_000)
      assert :ok = Zvex.initialize!(config)
    end

    test "raises on invalid config" do
      config = Config.new() |> Config.memory_limit(-1)
      assert_raise Zvex.Error.Invalid.Argument, fn -> Zvex.initialize!(config) end
    end
  end
end
