defmodule Zvex.ErrorTest do
  use ExUnit.Case, async: true

  describe "from_native/1" do
    test "passes through :ok" do
      assert :ok = Zvex.Error.from_native(:ok)
    end

    test "passes through {:ok, value}" do
      assert {:ok, "hello"} = Zvex.Error.from_native({:ok, "hello"})
    end

    test "maps :invalid_argument to Invalid.Argument" do
      assert {:error, %Zvex.Error.Invalid.Argument{message: "bad arg"}} =
               Zvex.Error.from_native({:error, {:invalid_argument, "bad arg"}})
    end

    test "maps :failed_precondition to Invalid.FailedPrecondition" do
      assert {:error, %Zvex.Error.Invalid.FailedPrecondition{message: "not ready"}} =
               Zvex.Error.from_native({:error, {:failed_precondition, "not ready"}})
    end

    test "maps :not_found to NotFound.NotFound" do
      assert {:error, %Zvex.Error.NotFound.NotFound{message: "missing"}} =
               Zvex.Error.from_native({:error, {:not_found, "missing"}})
    end

    test "maps :already_exists to Conflict.AlreadyExists" do
      assert {:error, %Zvex.Error.Conflict.AlreadyExists{message: "exists"}} =
               Zvex.Error.from_native({:error, {:already_exists, "exists"}})
    end

    test "maps :permission_denied to Unavailable.PermissionDenied" do
      assert {:error, %Zvex.Error.Unavailable.PermissionDenied{message: "denied"}} =
               Zvex.Error.from_native({:error, {:permission_denied, "denied"}})
    end

    test "maps :resource_exhausted to Unavailable.ResourceExhausted" do
      assert {:error, %Zvex.Error.Unavailable.ResourceExhausted{message: "full"}} =
               Zvex.Error.from_native({:error, {:resource_exhausted, "full"}})
    end

    test "maps :unavailable to Unavailable.Unavailable" do
      assert {:error, %Zvex.Error.Unavailable.Unavailable{message: "down"}} =
               Zvex.Error.from_native({:error, {:unavailable, "down"}})
    end

    test "maps :not_supported to Unavailable.NotSupported" do
      assert {:error, %Zvex.Error.Unavailable.NotSupported{message: "nope"}} =
               Zvex.Error.from_native({:error, {:not_supported, "nope"}})
    end

    test "maps :internal_error to Internal.InternalError" do
      assert {:error, %Zvex.Error.Internal.InternalError{message: "boom"}} =
               Zvex.Error.from_native({:error, {:internal_error, "boom"}})
    end

    test "maps :unknown to Unknown.Unknown" do
      assert {:error, %Zvex.Error.Unknown.Unknown{message: "???"}} =
               Zvex.Error.from_native({:error, {:unknown, "???"}})
    end

    test "maps unrecognized codes to Unknown.Unknown" do
      assert {:error, %Zvex.Error.Unknown.Unknown{message: "wat"}} =
               Zvex.Error.from_native({:error, {:some_future_code, "wat"}})
    end
  end

  describe "unwrap!/1" do
    test "returns value on {:ok, value}" do
      assert "hello" = Zvex.Error.unwrap!({:ok, "hello"})
    end

    test "returns :ok on :ok" do
      assert :ok = Zvex.Error.unwrap!(:ok)
    end

    test "raises on {:error, splode_error}" do
      error = Zvex.Error.Invalid.Argument.exception(message: "bad")

      assert_raise Zvex.Error.Invalid.Argument, fn ->
        Zvex.Error.unwrap!({:error, error})
      end
    end
  end
end
