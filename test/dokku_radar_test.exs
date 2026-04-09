defmodule DokkuRadarTest do
  use ExUnit.Case

  test "application starts successfully" do
    assert Enum.any?(
             Application.started_applications(),
             fn {app, _, _} -> app == :dokku_radar end
           )
  end
end
