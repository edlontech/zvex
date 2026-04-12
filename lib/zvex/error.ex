defmodule Zvex.Error do
  @moduledoc """
  Splode error hierarchy for Zvex.

  Maps zvec C error codes to structured Elixir errors organized
  into classes: invalid, not_found, conflict, unavailable, internal, unknown.
  """
  use Splode,
    error_classes: [
      invalid: Zvex.Error.Invalid,
      not_found: Zvex.Error.NotFound,
      conflict: Zvex.Error.Conflict,
      unavailable: Zvex.Error.Unavailable,
      internal: Zvex.Error.Internal,
      unknown: Zvex.Error.Unknown
    ],
    unknown_error: Zvex.Error.Unknown.Unknown

  @error_code_map %{
    invalid_argument: Zvex.Error.Invalid.Argument,
    failed_precondition: Zvex.Error.Invalid.FailedPrecondition,
    not_found: Zvex.Error.NotFound.NotFound,
    already_exists: Zvex.Error.Conflict.AlreadyExists,
    permission_denied: Zvex.Error.Unavailable.PermissionDenied,
    resource_exhausted: Zvex.Error.Unavailable.ResourceExhausted,
    unavailable: Zvex.Error.Unavailable.Unavailable,
    not_supported: Zvex.Error.Unavailable.NotSupported,
    internal_error: Zvex.Error.Internal.InternalError,
    unknown: Zvex.Error.Unknown.Unknown
  }

  @doc """
  Translates a NIF return value into a Splode error or passthrough.

  Accepts:
  - `:ok` -> `:ok`
  - `{:ok, value}` -> `{:ok, value}`
  - `{:error, {code_atom, message_binary}}` -> `{:error, %SplodeError{}}`
  """
  def from_native(:ok), do: :ok
  def from_native({:ok, value}), do: {:ok, value}

  def from_native({:error, {code, message}}) when is_atom(code) and is_binary(message) do
    error_module = Map.get(@error_code_map, code, Zvex.Error.Unknown.Unknown)
    {:error, error_module.exception(message: message)}
  end
end
