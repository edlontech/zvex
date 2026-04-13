defmodule Zvex.TestDir do
  @moduledoc false

  @doc """
  ExUnit named setup that creates a unique temp directory per test.

  Unlike ExUnit's built-in `:tmp_dir` tag, paths contain only
  alphanumeric characters — compatible with zvec's path regex validation.

  Populates `%{test_dir: path}` in the test context and cleans up on exit.

  ## Usage

      import Zvex.TestDir
      setup :create_test_dir

      test "something", %{test_dir: test_dir} do
        path = Path.join(test_dir, "my_collection")
        # ...
      end
  """
  def create_test_dir(_context) do
    dir = Path.join(System.tmp_dir!(), "zvex_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    ExUnit.Callbacks.on_exit(fn -> File.rm_rf(dir) end)
    %{test_dir: dir}
  end
end
