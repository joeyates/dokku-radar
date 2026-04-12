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
end
