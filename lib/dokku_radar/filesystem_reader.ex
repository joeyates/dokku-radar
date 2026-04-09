defmodule DokkuRadar.FilesystemReader do
  @behaviour DokkuRadar.FilesystemReader.Behaviour

  @dokku_root "/home/dokku"
  @dokku_data "/var/lib/dokku/data"

  @impl true
  def app_scale(app_name, opts \\ []) do
    data_dir = Keyword.get(opts, :data_dir, @dokku_data)
    scale_path = Path.join([data_dir, "ps", app_name, "scale"])

    case File.read(scale_path) do
      {:ok, content} -> {:ok, parse_scale(content)}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def cert_expiry(app_name, opts \\ []) do
    dokku_root = Keyword.get(opts, :dokku_root, @dokku_root)
    tls_dir = Path.join([dokku_root, app_name, "tls"])

    le_cert = Path.join(tls_dir, "server.letsencrypt.crt")
    generic_cert = Path.join(tls_dir, "server.crt")

    cert_path =
      cond do
        File.exists?(le_cert) -> le_cert
        File.exists?(generic_cert) -> generic_cert
        true -> nil
      end

    case cert_path do
      nil ->
        {:error, :no_cert}

      path ->
        with {:ok, pem_data} <- File.read(path) do
          extract_expiry(pem_data)
        end
    end
  end

  defp parse_scale(content) do
    content
    |> String.split("\n", trim: true)
    |> Map.new(fn line ->
      [process_type, count] = String.split(line, "=", parts: 2)
      {String.trim(process_type), count |> String.trim() |> String.to_integer()}
    end)
  end

  defp extract_expiry(pem_data) do
    [{_type, der, _}] = :public_key.pem_decode(pem_data)
    otp_cert = :public_key.pkix_decode_cert(der, :otp)
    {:Validity, _not_before, not_after} = otp_cert |> elem(1) |> elem(5)
    {:ok, asn1_time_to_datetime(not_after)}
  end

  defp asn1_time_to_datetime({:utcTime, charlist}) do
    time_str = to_string(charlist)

    <<yy::binary-size(2), mm::binary-size(2), dd::binary-size(2), hh::binary-size(2),
      min::binary-size(2), ss::binary-size(2)>> <> "Z" = time_str

    year = String.to_integer(yy)
    year = if year >= 50, do: 1900 + year, else: 2000 + year

    year
    |> Date.new!(String.to_integer(mm), String.to_integer(dd))
    |> DateTime.new!(
      hh
      |> String.to_integer()
      |> Time.new!(String.to_integer(min), String.to_integer(ss))
    )
  end

  defp asn1_time_to_datetime({:generalTime, charlist}) do
    time_str = to_string(charlist)

    <<yyyy::binary-size(4), mm::binary-size(2), dd::binary-size(2), hh::binary-size(2),
      min::binary-size(2), ss::binary-size(2)>> <> "Z" = time_str

    yyyy
    |> String.to_integer()
    |> Date.new!(
      String.to_integer(mm),
      String.to_integer(dd)
    )
    |> DateTime.new!(
      hh
      |> String.to_integer()
      |> Time.new!(String.to_integer(min), String.to_integer(ss))
    )
  end
end
