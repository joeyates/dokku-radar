defmodule DokkuRadar.FilesystemReaderTest do
  use ExUnit.Case, async: true

  alias DokkuRadar.FilesystemReader

  setup do
    tmp_dir =
      Path.join(
        System.tmp_dir!(),
        "dokku_radar_test_#{:erlang.unique_integer([:positive])}"
      )

    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    %{tmp_dir: tmp_dir}
  end

  describe "app_scale/2" do
    test "parses scale file with multiple process types", %{tmp_dir: tmp_dir} do
      data_dir = Path.join(tmp_dir, "data")
      scale_dir = Path.join([data_dir, "ps", "my-app"])
      File.mkdir_p!(scale_dir)
      scale_dir |> Path.join("scale") |> File.write!("web=2\nworker=1\n")

      assert {:ok, %{"web" => 2, "worker" => 1}} =
               FilesystemReader.app_scale("my-app", data_dir: data_dir)
    end

    test "parses scale file with single process type", %{tmp_dir: tmp_dir} do
      data_dir = Path.join(tmp_dir, "data")
      scale_dir = Path.join([data_dir, "ps", "my-app"])
      File.mkdir_p!(scale_dir)
      scale_dir |> Path.join("scale") |> File.write!("web=1\n")

      assert {:ok, %{"web" => 1}} =
               FilesystemReader.app_scale("my-app", data_dir: data_dir)
    end

    test "returns error when scale file does not exist", %{tmp_dir: tmp_dir} do
      data_dir = Path.join(tmp_dir, "data")

      assert {:error, :enoent} =
               FilesystemReader.app_scale("missing-app", data_dir: data_dir)
    end
  end

  describe "cert_expiry/2" do
    test "reads expiry from server.letsencrypt.crt when present", %{tmp_dir: tmp_dir} do
      tls_dir = Path.join([tmp_dir, "my-app", "tls"])
      File.mkdir_p!(tls_dir)

      cert_path = Path.join(tls_dir, "server.letsencrypt.crt")
      generate_self_signed_cert(cert_path, 90)

      assert {:ok, %DateTime{} = expiry} =
               FilesystemReader.cert_expiry("my-app", dokku_root: tmp_dir)

      days_until_expiry = DateTime.diff(expiry, DateTime.utc_now(), :day)
      assert days_until_expiry >= 89
      assert days_until_expiry <= 91
    end

    test "falls back to server.crt when letsencrypt cert absent", %{tmp_dir: tmp_dir} do
      tls_dir = Path.join([tmp_dir, "my-app", "tls"])
      File.mkdir_p!(tls_dir)

      cert_path = Path.join(tls_dir, "server.crt")
      generate_self_signed_cert(cert_path, 30)

      assert {:ok, %DateTime{} = expiry} =
               FilesystemReader.cert_expiry("my-app", dokku_root: tmp_dir)

      days_until_expiry = DateTime.diff(expiry, DateTime.utc_now(), :day)
      assert days_until_expiry >= 29
      assert days_until_expiry <= 31
    end

    test "prefers letsencrypt cert over generic cert", %{tmp_dir: tmp_dir} do
      tls_dir = Path.join([tmp_dir, "my-app", "tls"])
      File.mkdir_p!(tls_dir)

      tls_dir |> Path.join("server.crt") |> generate_self_signed_cert(30)
      tls_dir |> Path.join("server.letsencrypt.crt") |> generate_self_signed_cert(90)

      assert {:ok, %DateTime{} = expiry} =
               FilesystemReader.cert_expiry("my-app", dokku_root: tmp_dir)

      days_until_expiry = DateTime.diff(expiry, DateTime.utc_now(), :day)
      assert days_until_expiry >= 89
    end

    test "returns error when no cert exists", %{tmp_dir: tmp_dir} do
      assert {:error, :no_cert} =
               FilesystemReader.cert_expiry("no-cert-app", dokku_root: tmp_dir)
    end
  end

  defp generate_self_signed_cert(path, days) do
    {_, 0} =
      System.cmd("openssl", [
        "req",
        "-x509",
        "-newkey",
        "rsa:2048",
        "-keyout",
        "/dev/null",
        "-out",
        path,
        "-days",
        to_string(days),
        "-nodes",
        "-subj",
        "/CN=test"
      ])
  end
end
