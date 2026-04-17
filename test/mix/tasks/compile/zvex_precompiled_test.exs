defmodule Mix.Tasks.Compile.ZvexPrecompiledTest do
  use ExUnit.Case, async: false

  alias Mix.Tasks.Compile.ZvexPrecompiled

  describe "normalize_architecture/1" do
    test "maps x86_64-pc-linux-gnu to linux-x86_64-gnu" do
      assert {:ok, "linux-x86_64-gnu"} =
               ZvexPrecompiled.normalize_architecture("x86_64-pc-linux-gnu")
    end

    test "maps x86_64-pc-linux-musl to linux-x86_64-musl" do
      assert {:ok, "linux-x86_64-musl"} =
               ZvexPrecompiled.normalize_architecture("x86_64-pc-linux-musl")
    end

    test "maps aarch64-unknown-linux-gnu to linux-aarch64-gnu" do
      assert {:ok, "linux-aarch64-gnu"} =
               ZvexPrecompiled.normalize_architecture("aarch64-unknown-linux-gnu")
    end

    test "maps aarch64-apple-darwin23.0.0 to darwin-aarch64" do
      assert {:ok, "darwin-aarch64"} =
               ZvexPrecompiled.normalize_architecture("aarch64-apple-darwin23.0.0")
    end

    test "returns :unsupported for x86_64-apple-darwin23.0.0" do
      assert :unsupported = ZvexPrecompiled.normalize_architecture("x86_64-apple-darwin23.0.0")
    end

    test "returns :unsupported for x86_64-pc-windows-msvc" do
      assert :unsupported = ZvexPrecompiled.normalize_architecture("x86_64-pc-windows-msvc")
    end
  end

  describe "detect_target/0" do
    test "returns a valid target tuple or :unsupported on the host" do
      assert ZvexPrecompiled.detect_target() in [
               {:ok, "linux-x86_64-gnu"},
               {:ok, "linux-aarch64-gnu"},
               {:ok, "linux-x86_64-musl"},
               {:ok, "darwin-aarch64"},
               :unsupported
             ]
    end
  end

  describe "verify_sha256!/2" do
    @tag :tmp_dir
    test "accepts matching checksum", %{tmp_dir: dir} do
      tarball = Path.join(dir, "t.tar.gz")
      File.write!(tarball, "hello")
      sha = :crypto.hash(:sha256, "hello") |> Base.encode16(case: :lower)
      sha_file = tarball <> ".sha256"
      File.write!(sha_file, "#{sha}  t.tar.gz\n")
      assert :ok = ZvexPrecompiled.verify_sha256!(tarball, sha_file)
      assert File.exists?(tarball)
      assert File.exists?(sha_file)
    end

    @tag :tmp_dir
    test "raises and deletes both files on mismatch", %{tmp_dir: dir} do
      tarball = Path.join(dir, "t.tar.gz")
      File.write!(tarball, "hello")
      sha_file = tarball <> ".sha256"
      File.write!(sha_file, String.duplicate("0", 64) <> "\n")

      assert_raise Mix.Error, ~r/checksum mismatch/, fn ->
        ZvexPrecompiled.verify_sha256!(tarball, sha_file)
      end

      refute File.exists?(tarball)
      refute File.exists?(sha_file)
    end

    @tag :tmp_dir
    test "accepts uppercase hex digest", %{tmp_dir: dir} do
      tarball = Path.join(dir, "t.tar.gz")
      File.write!(tarball, "hello")
      sha = :crypto.hash(:sha256, "hello") |> Base.encode16(case: :upper)
      sha_file = tarball <> ".sha256"
      File.write!(sha_file, "#{sha}  t.tar.gz\n")
      assert :ok = ZvexPrecompiled.verify_sha256!(tarball, sha_file)
    end
  end

  describe "extract!/2" do
    @tag :tmp_dir
    test "raises and deletes tarball when entry has absolute path", %{tmp_dir: dir} do
      tarball = Path.join(dir, "evil.tar.gz")
      dest = Path.join(dir, "dest")
      File.mkdir_p!(dest)

      write_tarball!(tarball, [{~c"/tmp/evil", "pwned"}])

      assert_raise Mix.Error, ~r/unsafe entry path/, fn ->
        ZvexPrecompiled.extract!(tarball, dest)
      end

      refute File.exists?(tarball)
    end

    @tag :tmp_dir
    test "raises and deletes tarball when entry has traversal path", %{tmp_dir: dir} do
      tarball = Path.join(dir, "evil.tar.gz")
      dest = Path.join(dir, "dest")
      File.mkdir_p!(dest)

      write_tarball!(tarball, [{~c"../evil", "pwned"}])

      assert_raise Mix.Error, ~r/unsafe entry path/, fn ->
        ZvexPrecompiled.extract!(tarball, dest)
      end

      refute File.exists?(tarball)
    end

    @tag :tmp_dir
    test "extracts safe tarball successfully", %{tmp_dir: dir} do
      tarball = Path.join(dir, "ok.tar.gz")
      dest = Path.join(dir, "dest")
      File.mkdir_p!(dest)

      write_tarball!(tarball, [{~c"lib/hello.txt", "world"}])

      assert :ok = ZvexPrecompiled.extract!(tarball, dest)
      assert File.read!(Path.join([dest, "lib", "hello.txt"])) == "world"
    end
  end

  describe "cache_complete?/2" do
    @tag :tmp_dir
    test "returns false when tarball exists but sha file is missing", %{tmp_dir: dir} do
      tarball = Path.join(dir, "t.tar.gz")
      sha_file = tarball <> ".sha256"
      File.write!(tarball, "data")

      refute ZvexPrecompiled.cache_complete?(tarball, sha_file)
    end

    @tag :tmp_dir
    test "returns false when sha file exists but tarball is missing", %{tmp_dir: dir} do
      tarball = Path.join(dir, "t.tar.gz")
      sha_file = tarball <> ".sha256"
      File.write!(sha_file, "deadbeef")

      refute ZvexPrecompiled.cache_complete?(tarball, sha_file)
    end

    @tag :tmp_dir
    test "returns true when both tarball and sha file exist", %{tmp_dir: dir} do
      tarball = Path.join(dir, "t.tar.gz")
      sha_file = tarball <> ".sha256"
      File.write!(tarball, "data")
      File.write!(sha_file, "deadbeef")

      assert ZvexPrecompiled.cache_complete?(tarball, sha_file)
    end

    @tag :tmp_dir
    test "returns false when neither file exists", %{tmp_dir: dir} do
      tarball = Path.join(dir, "t.tar.gz")
      sha_file = tarball <> ".sha256"

      refute ZvexPrecompiled.cache_complete?(tarball, sha_file)
    end
  end

  describe "sentinel_valid?/2" do
    setup do
      priv_dir = Path.join(Mix.Project.app_path(), "priv")
      sentinel_path = Path.join(priv_dir, ".zvex_precompiled")

      shared_lib =
        case :os.type() do
          {:unix, :darwin} -> "libzvec_c_api.dylib"
          _ -> "libzvec_c_api.so"
        end

      shared_lib_path = Path.join([priv_dir, "lib", shared_lib])

      previous_sentinel =
        if File.exists?(sentinel_path), do: File.read!(sentinel_path)

      previous_shared_lib =
        if File.exists?(shared_lib_path), do: File.read!(shared_lib_path)

      File.mkdir_p!(Path.join(priv_dir, "lib"))
      File.rm(sentinel_path)

      on_exit(fn ->
        File.rm(sentinel_path)

        case previous_sentinel do
          nil -> :ok
          content -> File.write!(sentinel_path, content)
        end

        case previous_shared_lib do
          nil -> :ok
          content -> File.write!(shared_lib_path, content)
        end
      end)

      {:ok, priv_dir: priv_dir, sentinel_path: sentinel_path, shared_lib_path: shared_lib_path}
    end

    test "returns false when sentinel file does not exist", _ctx do
      refute ZvexPrecompiled.sentinel_valid?("0.1.0", "linux-x86_64-gnu")
    end

    test "returns false when manifest version mismatches", ctx do
      File.write!(ctx.sentinel_path, "99\n0.1.0\nlinux-x86_64-gnu\n")
      File.write!(ctx.shared_lib_path, "stub")

      refute ZvexPrecompiled.sentinel_valid?("0.1.0", "linux-x86_64-gnu")
    end

    test "returns false when zvec version mismatches", ctx do
      File.write!(ctx.sentinel_path, "1\n0.0.9\nlinux-x86_64-gnu\n")
      File.write!(ctx.shared_lib_path, "stub")

      refute ZvexPrecompiled.sentinel_valid?("0.1.0", "linux-x86_64-gnu")
    end

    test "returns false when target mismatches", ctx do
      File.write!(ctx.sentinel_path, "1\n0.1.0\nlinux-aarch64-gnu\n")
      File.write!(ctx.shared_lib_path, "stub")

      refute ZvexPrecompiled.sentinel_valid?("0.1.0", "linux-x86_64-gnu")
    end

    test "returns false when shared library file is missing", ctx do
      File.write!(ctx.sentinel_path, "1\n0.1.0\nlinux-x86_64-gnu\n")
      File.rm(ctx.shared_lib_path)

      refute ZvexPrecompiled.sentinel_valid?("0.1.0", "linux-x86_64-gnu")
    end

    test "returns true when everything matches", ctx do
      File.write!(ctx.sentinel_path, "1\n0.1.0\nlinux-x86_64-gnu\n")
      File.write!(ctx.shared_lib_path, "stub")

      assert ZvexPrecompiled.sentinel_valid?("0.1.0", "linux-x86_64-gnu")
    end
  end

  defp write_tarball!(path, entries) do
    path_charlist = String.to_charlist(path)
    {:ok, tar} = :erl_tar.open(path_charlist, [:write, :compressed])

    Enum.each(entries, fn {name, contents} ->
      :ok = :erl_tar.add(tar, {name, :erlang.iolist_to_binary(contents)}, [])
    end)

    :ok = :erl_tar.close(tar)
  end
end
