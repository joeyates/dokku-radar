defmodule DokkuRadar.Git.ReportTest do
  use ExUnit.Case, async: true

  import Mox

  alias DokkuRadar.Git.Report

  setup :verify_on_exit!

  describe "app_timestamps/0" do
    test "returns a map of app name to last_updated_at timestamp" do
      app_report = %DokkuRemote.Commands.Git.Report{
        app_name: "myapp",
        deploy_branch: "main",
        global_deploy_branch: "main",
        keep_git_dir: false,
        rev_env_var: "GIT_REV",
        sha: "abc123",
        source_image: "",
        last_updated_at: 1_700_000_000
      }

      expect(DokkuRemote.Commands.Git.Mock, :report, fn _host ->
        {:ok, %{"myapp" => app_report}}
      end)

      assert {:ok, %{"myapp" => 1_700_000_000}} = Report.app_timestamps()
    end

    test "returns error when report fails" do
      expect(DokkuRemote.Commands.Git.Mock, :report, fn _host ->
        {:error, "ssh: Connection refused", 255}
      end)

      assert {:error, "ssh: Connection refused", 255} = Report.app_timestamps()
    end
  end
end
