defmodule DokkuRadarTest do
  use ExUnit.Case

  test "application starts successfully" do
    assert Enum.any?(
             Application.started_applications(),
             fn {app, _, _} -> app == :dokku_radar end
           )
  end

  test "supervisor has Bandit child serving the Router" do
    children = Supervisor.which_children(DokkuRadar.Supervisor)

    assert Enum.any?(children, fn
             {{Bandit, _ref}, _pid, _type, [Bandit]} -> true
             _ -> false
           end)
  end
end
