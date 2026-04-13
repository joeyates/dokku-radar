defmodule DokkuRadar.Ps.ReportTest do
  use ExUnit.Case, async: true

  alias DokkuRadar.Ps.Report

  @ps_report_output """
  =====> blog-cms ps information
         Status web 1:                  running (CID: 37d851b84ba)
  =====> nextcloud ps information
         Status web 1:                  running (CID: 4a2b9c0d1e2)
         Status worker 1:               running (CID: 5b3c0d1e2f3)
         Status release 1:              exited (CID: 6c4d1e2f3a4)
  """

  describe "parse/1" do
    test "returns a list of process entries" do
      assert entries = Report.parse(@ps_report_output)
      assert length(entries) == 4
    end

    test "parses app from section header" do
      entries = Report.parse(@ps_report_output)
      apps = entries |> Enum.map(& &1.app) |> Enum.uniq() |> Enum.sort()
      assert apps == ["blog-cms", "nextcloud"]
    end

    test "parses process_type, process_index, state, and cid" do
      entries = Report.parse(@ps_report_output)
      entry = Enum.find(entries, &(&1.app == "blog-cms"))
      assert entry.process_type == "web"
      assert entry.process_index == 1
      assert entry.state == "running"
      assert entry.cid == "37d851b84ba"
    end

    test "parses multiple processes under one app" do
      entries = Report.parse(@ps_report_output)
      nextcloud = Enum.filter(entries, &(&1.app == "nextcloud"))
      assert length(nextcloud) == 3

      types = nextcloud |> Enum.map(& &1.process_type) |> Enum.sort()
      assert types == ["release", "web", "worker"]
    end

    test "parses exited state" do
      entries = Report.parse(@ps_report_output)
      release = Enum.find(entries, &(&1.process_type == "release"))
      assert release.state == "exited"
    end

    test "returns empty list for empty output" do
      assert Report.parse("") == []
    end
  end
end
