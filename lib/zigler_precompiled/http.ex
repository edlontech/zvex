defmodule ZiglerPrecompiled.HTTP do
  @moduledoc false

  def http_options do
    ssl_opts =
      [
        verify: :verify_peer,
        depth: 4,
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ]
      ]
      |> maybe_add_cacerts()

    proxy_opts = proxy_config()

    [{:ssl, ssl_opts} | proxy_opts]
  end

  defp maybe_add_cacerts(ssl_opts) do
    cond do
      path = System.get_env("HEX_CACERTS_PATH") ->
        Keyword.put(ssl_opts, :cacertfile, String.to_charlist(path))

      Code.ensure_loaded?(CAStore) ->
        Keyword.put(ssl_opts, :cacertfile, String.to_charlist(CAStore.file_path()))

      true ->
        ssl_opts
    end
  end

  defp proxy_config do
    http_proxy = System.get_env("HTTP_PROXY") || System.get_env("http_proxy")
    https_proxy = System.get_env("HTTPS_PROXY") || System.get_env("https_proxy")

    opts = []
    opts = if http_proxy, do: [{:proxy, proxy_uri(http_proxy)} | opts], else: opts
    opts = if https_proxy, do: [{:https_proxy, proxy_uri(https_proxy)} | opts], else: opts
    opts
  end

  defp proxy_uri(proxy) do
    case :uri_string.parse(proxy) do
      %{host: host, port: port} when is_binary(host) and is_integer(port) ->
        {{String.to_charlist(host), port}, []}

      %{host: host} when is_binary(host) ->
        {{String.to_charlist(host), 80}, []}

      _ ->
        raise "invalid proxy URI: #{inspect(proxy)}"
    end
  end
end
