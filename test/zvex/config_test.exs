defmodule Zvex.ConfigTest do
  use ExUnit.Case, async: true

  alias Zvex.Config

  describe "new/0" do
    test "returns struct with all nil fields" do
      config = Config.new()
      assert %Config{} = config
      assert is_nil(config.memory_limit)
      assert is_nil(config.query_threads)
      assert is_nil(config.optimize_threads)
      assert is_nil(config.invert_to_forward_scan_ratio)
      assert is_nil(config.brute_force_by_keys_ratio)
      assert is_nil(config.log)
    end
  end

  describe "builder functions" do
    test "memory_limit/2 sets the field" do
      config = Config.new() |> Config.memory_limit(1024)
      assert config.memory_limit == 1024
    end

    test "query_threads/2 sets the field" do
      config = Config.new() |> Config.query_threads(4)
      assert config.query_threads == 4
    end

    test "optimize_threads/2 sets the field" do
      config = Config.new() |> Config.optimize_threads(2)
      assert config.optimize_threads == 2
    end

    test "invert_to_forward_scan_ratio/2 sets the field" do
      config = Config.new() |> Config.invert_to_forward_scan_ratio(0.5)
      assert config.invert_to_forward_scan_ratio == 0.5
    end

    test "brute_force_by_keys_ratio/2 sets the field" do
      config = Config.new() |> Config.brute_force_by_keys_ratio(0.1)
      assert config.brute_force_by_keys_ratio == 0.1
    end

    test "log/3 sets console config" do
      config = Config.new() |> Config.log(:console, level: :warn)
      assert config.log == {:console, %{level: :warn}}
    end

    test "log/3 called twice replaces previous config" do
      config =
        Config.new()
        |> Config.log(:console, level: :warn)
        |> Config.log(:console, level: :error)

      assert {:console, %{level: :error}} = config.log
    end

    test "full pipeline builds config" do
      config =
        Config.new()
        |> Config.memory_limit(1_073_741_824)
        |> Config.query_threads(4)
        |> Config.optimize_threads(2)
        |> Config.invert_to_forward_scan_ratio(0.5)
        |> Config.brute_force_by_keys_ratio(0.1)
        |> Config.log(:console, level: :warn)

      assert config.memory_limit == 1_073_741_824
      assert config.query_threads == 4
      assert config.optimize_threads == 2
      assert config.invert_to_forward_scan_ratio == 0.5
      assert config.brute_force_by_keys_ratio == 0.1
      assert config.log == {:console, %{level: :warn}}
    end
  end

  describe "validate/1" do
    test "accepts all-nil config" do
      assert {:ok, %Config{}} = Config.new() |> Config.validate()
    end

    test "accepts valid config with all fields set" do
      config =
        Config.new()
        |> Config.memory_limit(1024)
        |> Config.query_threads(4)
        |> Config.log(:console, level: :debug)

      assert {:ok, ^config} = Config.validate(config)
    end

    test "rejects negative memory_limit" do
      config = Config.new() |> Config.memory_limit(-1)
      assert {:error, %Zvex.Error.Invalid.Argument{}} = Config.validate(config)
    end

    test "rejects negative ratio" do
      config = Config.new() |> Config.invert_to_forward_scan_ratio(-0.5)
      assert {:error, %Zvex.Error.Invalid.Argument{}} = Config.validate(config)
    end

    test "rejects invalid log level" do
      config = Config.new() |> Config.log(:console, level: :bogus)
      assert {:error, %Zvex.Error.Invalid.Argument{}} = Config.validate(config)
    end
  end

  describe "to_native_map/1" do
    test "strips nil fields" do
      native = Config.new() |> Config.to_native_map()
      assert native == %{}
    end

    test "keeps non-nil fields" do
      native =
        Config.new()
        |> Config.memory_limit(1024)
        |> Config.query_threads(4)
        |> Config.to_native_map()

      assert native == %{memory_limit: 1024, query_threads: 4}
    end

    test "converts console log tuple to map" do
      native =
        Config.new()
        |> Config.log(:console, level: :warn)
        |> Config.to_native_map()

      assert native.log == %{type: :console, level: :warn}
    end
  end
end
