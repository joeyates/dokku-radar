defmodule DokkuRadar.DockerClientTest do
  use ExUnit.Case, async: true

  alias DokkuRadar.DockerClient

  describe "list_containers/0" do
    test "returns containers on success" do
      Req.Test.stub(DockerClient, fn conn ->
        containers = [
          %{
            "Id" => "abc123",
            "Names" => ["/my-app.web.1"],
            "Image" => "my-app:latest",
            "State" => "running",
            "Status" => "Up 2 hours",
            "Labels" => %{"com.dokku.app-name" => "my-app"}
          }
        ]

        Req.Test.json(conn, containers)
      end)

      assert {:ok, [container]} = DockerClient.list_containers(plug: {Req.Test, DockerClient})

      assert container["Id"] == "abc123"
      assert container["State"] == "running"
    end

    test "returns error on non-200 response" do
      Req.Test.stub(DockerClient, fn conn ->
        conn
        |> Plug.Conn.put_status(500)
        |> Req.Test.json(%{"message" => "server error"})
      end)

      assert {:error, {500, _body}} =
               DockerClient.list_containers(plug: {Req.Test, DockerClient})
    end

    test "returns error on transport failure" do
      Req.Test.stub(DockerClient, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, %Req.TransportError{reason: :econnrefused}} =
               DockerClient.list_containers(plug: {Req.Test, DockerClient})
    end
  end

  describe "container_stats/1" do
    test "returns stats on success" do
      Req.Test.stub(DockerClient, fn conn ->
        stats = %{
          "read" => "2025-01-08T22:57:31.547920715Z",
          "memory_stats" => %{
            "usage" => 6_537_216,
            "limit" => 67_108_864
          },
          "cpu_stats" => %{
            "cpu_usage" => %{"total_usage" => 100_000},
            "system_cpu_usage" => 739_306_590_000_000,
            "online_cpus" => 4
          },
          "precpu_stats" => %{
            "cpu_usage" => %{"total_usage" => 90_000},
            "system_cpu_usage" => 739_306_580_000_000
          },
          "pids_stats" => %{"current" => 3}
        }

        Req.Test.json(conn, stats)
      end)

      assert {:ok, stats} =
               DockerClient.container_stats("abc123", plug: {Req.Test, DockerClient})

      assert stats["memory_stats"]["usage"] == 6_537_216
      assert stats["pids_stats"]["current"] == 3
    end

    test "returns error when container not found" do
      Req.Test.stub(DockerClient, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(%{"message" => "No such container: xyz"})
      end)

      assert {:error, {404, _body}} =
               DockerClient.container_stats("xyz", plug: {Req.Test, DockerClient})
    end
  end
end
