defmodule DokkuRadar.GitReportTest do
  use ExUnit.Case, async: true

  import Mox

  alias DokkuRadar.GitReport

  setup :verify_on_exit!

  @git_report_output """
  =====> blog-cms git information
         Git deploy branch:            master
         Git global deploy branch:     master
         Git keep git dir:             false
         Git last updated at:          1775125215
         Git rev-env-var:              GIT_REV
         Git sha:                      abc123def
  """

  describe "report/1" do
    test "returns the unix timestamp of the last deploy" do
      expect(DokkuRadar.DokkuCli.Mock, :call, fn "git:report", ["blog-cms"] ->
        {:ok, @git_report_output}
      end)

      assert {:ok, 1_775_125_215} = GitReport.report("blog-cms")
    end

    test "returns {:error, :no_timestamp} when timestamp line is absent" do
      output = """
      =====> blog-cms git information
             Git deploy branch:            master
      """

      expect(DokkuRadar.DokkuCli.Mock, :call, fn "git:report", ["blog-cms"] ->
        {:ok, output}
      end)

      assert {:error, :no_timestamp} = GitReport.report("blog-cms")
    end

    test "returns {:error, reason} on CLI failure" do
      expect(DokkuRadar.DokkuCli.Mock, :call, fn "git:report", ["blog-cms"] ->
        {:error, "ssh: connect to host bad port 22: Connection refused", 255}
      end)

      assert {:error, _reason} = GitReport.report("blog-cms")
    end
  end
end
