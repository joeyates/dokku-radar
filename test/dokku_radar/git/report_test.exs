defmodule DokkuRadar.Git.ReportTest do
  use ExUnit.Case, async: true

  alias DokkuRadar.Git.Report

  @multi_app_output """
  =====> blog-cms git information
         Git deploy branch:            master
         Git global deploy branch:     master
         Git keep git dir:             false
         Git last updated at:          1775125215
         Git rev-env-var:              GIT_REV
         Git sha:                      abc123def
  =====> my-api git information
         Git deploy branch:            main
         Git global deploy branch:     master
         Git keep git dir:             false
         Git last updated at:          1775200000
         Git rev-env-var:              GIT_REV
         Git sha:                      deadbeef
  """

  describe "parse/1" do
    test "returns a map of app names to unix timestamps" do
      assert Report.parse(@multi_app_output) == %{
               "blog-cms" => 1_775_125_215,
               "my-api" => 1_775_200_000
             }
    end

    test "returns an empty map for empty output" do
      assert Report.parse("") == %{}
    end

    test "skips apps with no timestamp line" do
      output = """
      =====> no-ts-app git information
             Git deploy branch:            master
      =====> has-ts-app git information
             Git last updated at:          1111111111
      """

      assert Report.parse(output) == %{"has-ts-app" => 1_111_111_111}
    end

    test "handles a single app" do
      output = """
      =====> solo-app git information
             Git last updated at:          9999999999
      """

      assert Report.parse(output) == %{"solo-app" => 9_999_999_999}
    end
  end
end
