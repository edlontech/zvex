defmodule Zvex.Error.Unavailable do
  @moduledoc "Error class for unavailability-related errors."
  use Splode.ErrorClass, class: :unavailable

  defmodule PermissionDenied do
    @moduledoc "The caller lacks permission to perform the requested operation."
    use Splode.Error, fields: [:message], class: :unavailable

    def message(%{message: message}), do: message
  end

  defmodule ResourceExhausted do
    @moduledoc "A resource limit has been reached (e.g. storage, memory)."
    use Splode.Error, fields: [:message], class: :unavailable

    def message(%{message: message}), do: message
  end

  defmodule Unavailable do
    @moduledoc "The service or resource is temporarily unavailable."
    use Splode.Error, fields: [:message], class: :unavailable

    def message(%{message: message}), do: message
  end

  defmodule NotSupported do
    @moduledoc "The requested operation is not supported."
    use Splode.Error, fields: [:message], class: :unavailable

    def message(%{message: message}), do: message
  end
end
