defmodule DokkuRadar.CLI.Setup do
  alias DokkuRemote.App

  @grafana_port 3000

  def run(%App{} = dokku_radar_app, admin_email, grafana_domain, private_key_path) do
    :ok = ensure_network_exists(dokku_radar_app.dokku_host, "monitoring")
    :ok = set_up_dokku_radar(dokku_radar_app, private_key_path)
    # TODO: set up prometheus
    grafana_app = %App{dokku_radar_app | dokku_app: "grafana"}
    :ok = set_up_grafana(grafana_app, admin_email, grafana_domain)
  end

  defp set_up_dokku_radar(%App{} = app, private_key_path) do
    :ok = ensure_app_exists(app)
    :ok = ensure_storage_directory(app)
    :ok = ensure_proxy_disabled(app)
    :ok = ensure_docker_sock_access(app)
    :ok = ensure_network_property(app, "attach-post-deploy", "monitoring")
    :ok = install_private_key(app, private_key_path)
  end

  defp set_up_grafana(%App{} = app, admin_email, grafana_domain) do
    :ok = ensure_app_exists(app)
    :ok = ensure_storage_directory(app)
    :ok = ensure_domain_set(app, grafana_domain)
    :ok = enable_letsencrypt(app, admin_email, @grafana_port)
    destination_path = "/var/lib/dokku/data/storage/#{app.dokku_app}"
    :ok = ensure_storage_mount(app, destination_path, "/var/lib/grafana")
    :ok = ensure_network_property(app, "attach-post-deploy", "monitoring")
    :ok = set_host_file_owner(app, destination_path, "472:472")
    :ok = ensure_image_deployed(app, "grafana/grafana:latest")
  end

  defp ensure_image_deployed(%App{} = app, image) do
    {:ok, deploy_source} = get_deploy_source(app)

    if deploy_source == "" do
      IO.puts(
        "No deploy source currently set for app #{inspect(app.dokku_app)}, deploying image #{inspect(image)}..."
      )

      deploy_from_image(app, image)
    else
      IO.puts(
        "App #{inspect(app.dokku_app)} already has a deploy source of #{inspect(deploy_source)}"
      )

      maybe_update_image(app, image)
    end
  end

  defp deploy_from_image(%App{} = app, image) do
    case DokkuRemote.Commands.Git.App.from_image(app, image) do
      :ok ->
        IO.puts("\t✅ Image deployed successfully")
        :ok

      {:error, output, exit} ->
        raise "Failed to deploy image, exit code #{exit}: #{output}"
    end
  end

  defp maybe_update_image(%App{} = app, desired_image) do
    {:ok, current_image} = DokkuRemote.Commands.Git.App.get_source_image(app)

    if current_image == desired_image do
      IO.puts("\t✅ App is already deployed with the desired image #{inspect(desired_image)}")
      :ok
    else
      IO.puts(
        "App is currently deployed with image #{inspect(current_image)}, " <>
          "but desired image is #{inspect(desired_image)}, redeploying..."
      )

      deploy_from_image(app, desired_image)
    end
  end

  defp get_deploy_source(%App{} = app) do
    case DokkuRemote.Commands.Apps.App.get_deploy_source(app) do
      {:ok, source} ->
        {:ok, source}

      {:error, output, exit} ->
        raise "Failed to get deploy source, exit code #{exit}: #{output}"
    end
  end

  defp ensure_network_exists(dokku_host, network) do
    IO.puts("Checking the Dokku network #{inspect(network)} exists...")
    {:ok, exists} = DokkuRemote.Commands.Network.exists?(dokku_host, network)

    if exists do
      IO.puts("\t✅ Network exists")
    else
      IO.puts("The Dokku network #{inspect(network)} does not exist, creating...")

      case DokkuRemote.Commands.Network.create(dokku_host, network) do
        :ok ->
          IO.puts("\t✅ Network created")

        {:error, output, exit} ->
          raise "Failed to create network, exit code #{exit}: #{output}"
      end
    end

    :ok
  end

  defp ensure_app_exists(%App{} = app) do
    IO.puts("Checking the Dokku app #{inspect(app.dokku_app)} exists...")
    exists = DokkuRemote.Commands.Apps.App.exists?(app)

    if exists do
      IO.puts("\t✅ App exists")
    else
      IO.puts("The Dokku app #{inspect(app.dokku_app)} does not exist, creating...")

      case DokkuRemote.Commands.Apps.App.create(app) do
        :ok ->
          IO.puts("\t✅ App created")

        {:error, output, exit} ->
          raise "Failed to create app, exit code #{exit}: #{output}"
      end
    end

    :ok
  end

  defp ensure_proxy_disabled(%App{} = app) do
    IO.puts("Checking the app's proxy is disabled...")

    case DokkuRemote.Commands.Proxy.App.enabled?(app) do
      {:ok, false} ->
        IO.puts("\t✅ Proxy is already disabled")

      {:ok, true} ->
        IO.puts("App proxy is currently enabled, disabling...")
        :ok = DokkuRemote.Commands.Proxy.App.disable(app)
        IO.puts("\t✅ Proxy disabled")

      {:error, output, exit} ->
        raise "Failed to check if proxy is enabled, exit code #{exit}: #{output}"
    end

    :ok
  end

  defp ensure_docker_sock_access(%App{} = app) do
    with :ok <- ensure_storage_mount(app, "/var/run/docker.sock", "/var/run/docker.sock"),
         {:ok, docker_gid} <- get_docker_gid(app),
         :ok <- ensure_docker_group_added(app, docker_gid) do
      IO.puts("\t✅ Docker socket access configured")
      :ok
    else
      {:error, output, exit} ->
        raise "Failed to configure Docker socket access, exit code #{exit}: #{output}"
    end
  end

  defp ensure_storage_directory(%App{} = app) do
    IO.puts("Ensuring the app has a storage directory...")

    DokkuRemote.Commands.Storage.App.ensure_directory(app)
    IO.puts("\t✅ Storage directory ensured")
    :ok
  end

  defp ensure_storage_mount(%App{} = app, host_dir, container_dir) do
    IO.puts(
      "Ensuring the app has a storage mount of " <>
        "host #{inspect(host_dir)} -> " <>
        "container #{inspect(container_dir)}..."
    )

    case DokkuRemote.Commands.Storage.App.mount_exists?(app, host_dir, container_dir) do
      {:ok, true} ->
        IO.puts("\t✅ Storage mount already exists")

      {:ok, false} ->
        IO.puts("App does not have the storage mount, adding...")
        :ok = DokkuRemote.Commands.Storage.App.mount(app, host_dir, container_dir)
        IO.puts("\t✅ Storage mount added")

      {:error, output, exit} ->
        raise "Failed to check if storage mount exists, exit code #{exit}: #{output}"
    end

    :ok
  end

  defp get_docker_gid(%App{} = app) do
    IO.puts("Getting the group ID that owns the Docker socket on the Dokku host...")

    case DokkuRemote.Root.Command.run(
           app.dokku_host,
           "stat --format '%g' /var/run/docker.sock"
         ) do
      {:ok, output} ->
        docker_gid = output |> String.trim() |> String.to_integer()
        {:ok, docker_gid}

      {:error, output, exit} ->
        {:error, "Failed to get Docker GID, exit code #{exit}: #{output}", exit}
    end
  end

  defp ensure_docker_group_added(%App{} = app, docker_gid) do
    IO.puts("Ensuring the Docker GID #{docker_gid} is added to the app's Docker options...")
    option = "--group-add #{docker_gid}"

    case DokkuRemote.Commands.DockerOptions.App.exists?(app, "deploy", option) do
      {:ok, true} ->
        IO.puts("\t✅ Docker GID is already in deploy options")
        :ok

      {:ok, false} ->
        IO.puts("Docker GID is not in deploy options, adding...")

        :ok = DokkuRemote.Commands.DockerOptions.App.add(app, "deploy", option)

        IO.puts("\t✅ Docker GID added to deploy options")
        :ok

      {:error, output, exit} ->
        {:error, "Failed to check current Docker options, exit code #{exit}: #{output}", exit}
    end
  end

  defp ensure_network_property(%App{} = app, property, value) do
    IO.puts(
      "Checking the Dokku network property #{inspect(property)} " <>
        "is set to #{inspect(value)} for app #{inspect(app.dokku_app)}..."
    )

    case DokkuRemote.Commands.Network.App.get(app, property) do
      {:ok, ^value} ->
        IO.puts("\t✅ Network property is already set correctly")
        :ok

      {:ok, ""} ->
        IO.puts("Network property #{inspect(property)} is not currently set, setting...")

        :ok =
          DokkuRemote.Commands.Network.App.set(app, property, value)

        IO.puts("\t✅ Network property updated")
        :ok

      {:ok, current_value} ->
        IO.puts(
          "Network property #{inspect(property)} is currently set to #{inspect(current_value)}, updating..."
        )

        :ok =
          DokkuRemote.Commands.Network.App.set(app, property, value)

        IO.puts("\t✅ Network property updated")
        :ok

      {:error, output, exit} ->
        raise "Failed to check or set network property, exit code #{exit}: #{output}"
    end
  end

  defp ensure_domain_set(%App{} = app, desired_domain) do
    IO.puts("Checking the app's domain is set to #{inspect(desired_domain)}...")
    {:ok, current_domain} = DokkuRemote.Commands.Domains.App.get(app)

    cond do
      current_domain == desired_domain ->
        IO.puts("\t✅ Domain is already set correctly")

      is_nil(current_domain) ->
        IO.puts("No domain currently set")
        IO.puts("Setting domain to #{inspect(desired_domain)}...")
        :ok = DokkuRemote.Commands.Domains.App.set(app, desired_domain)
        IO.puts("\t✅ Domain set to #{inspect(desired_domain)}")

      true ->
        raise "App already has a domain set to #{inspect(current_domain)}, " <>
                "expected #{inspect(desired_domain)}."
    end

    :ok
  end

  defp enable_letsencrypt(%App{} = app, admin_email, port) do
    :ok = ensure_port_mapping(app, port)

    # TODO
    IO.puts("Setting email for Let's Encrypt to #{inspect(admin_email)}...")
    :ok = DokkuRemote.Commands.Letsencrypt.App.set(app, "email", admin_email)
    IO.puts("\t✅ Email set to #{inspect(admin_email)}")

    IO.puts("Ensuring the production Let's Encrypt server is used...")
    # TODO
    :ok = DokkuRemote.Commands.Letsencrypt.App.unset(app, "server")
    IO.puts("\t✅ Let's Encrypt production server set")
    IO.puts("Attempting to obtain a certificate...")

    case DokkuRemote.Commands.Letsencrypt.App.enable(app) do
      {:error, output, exit} ->
        raise "Failed to obtain certificate, exit code #{exit}: #{output}"

      _ ->
        nil
    end

    IO.puts("\t✅ Obtained and installed Let's Encrypt certificate")

    :ok
  end

  defp ensure_port_mapping(%App{} = app, desired_port) do
    IO.puts("Checking the app's HTTP port mapping is set to 80:#{desired_port}...")

    case DokkuRemote.Commands.Ports.App.get_prococol_mapping(app, "http") do
      {:ok, 80, ^desired_port} ->
        IO.puts("\t✅ Port mapping is already set to 80:#{desired_port}")

      {:ok, 80, current_port} ->
        IO.puts("App already has an HTTP port mapping of 80:#{current_port}")
        IO.puts("Updating HTTP port mapping to 80:#{desired_port}...")

        :ok =
          DokkuRemote.Commands.Ports.App.set_protocol_mapping(app, "http", desired_port)

        IO.puts("\t✅ Port mapping set")

      {:ok, non_80, container_port} ->
        raise "App already has an HTTP port mapping that does not map to port 80 on the host, " <>
                "cannot continue. Current mapping: #{non_80}:#{container_port}"

      {:error, :not_set} ->
        IO.puts("No HTTP port mapping currently set")
        IO.puts("Setting HTTP port mapping to 80:#{desired_port}...")

        :ok =
          DokkuRemote.Commands.Ports.App.set_protocol_mapping(app, "http", desired_port)

        IO.puts("\t✅ Port mapping set")
    end

    :ok
  end

  defp install_private_key(%App{} = app, private_key_path) do
    destination_path = "/var/lib/dokku/data/storage/#{app.dokku_app}/.ssh"
    ensure_host_dir(app, destination_path)
    :ok = set_host_file_mode(app, destination_path, "700")
    :ok = set_host_file_owner(app, destination_path, "32767:32767")

    destination_pathname = Path.join(destination_path, "id_ed25519")
    :ok = copy_file_to_host(app, private_key_path, destination_pathname)
    :ok = set_host_file_mode(app, destination_pathname, "600")
    :ok = set_host_file_owner(app, destination_pathname, "32767:32767")

    :ok = ensure_storage_mount(app, destination_path, "/data/.ssh")
  end

  defp ensure_host_dir(%App{} = app, host_dir) do
    IO.puts("Ensuring the directory #{inspect(host_dir)} exists on the Dokku host...")

    case DokkuRemote.Root.Command.run(app.dokku_host, "mkdir -p #{host_dir}") do
      {:ok, _output} ->
        IO.puts("\t✅ Directory ensured")

      {:error, output, exit} ->
        raise "Failed to ensure directory exists, exit code #{exit}: #{output}"
    end

    :ok
  end

  defp copy_file_to_host(%App{} = app, local_path, remote_path) do
    IO.puts(
      "Copying file from #{inspect(local_path)} to #{inspect(remote_path)} on the Dokku host..."
    )

    case DokkuRemote.Root.Copy.to_host(app.dokku_host, local_path, remote_path) do
      :ok ->
        IO.puts("\t✅ File copied")

      {:error, output, exit} ->
        raise "Failed to copy file to host, exit code #{exit}: #{output}"
    end

    :ok
  end

  defp set_host_file_mode(%App{} = app, remote_path, mode) do
    IO.puts("Setting file mode of #{inspect(remote_path)} to #{mode} on the Dokku host...")

    case DokkuRemote.Root.Command.run(app.dokku_host, "chmod #{mode} #{remote_path}") do
      {:ok, _output} ->
        IO.puts("\t✅ File mode set")

      {:error, output, exit} ->
        raise "Failed to set file mode, exit code #{exit}: #{output}"
    end

    :ok
  end

  def set_host_file_owner(%App{} = app, remote_path, owner) do
    IO.puts("Setting file owner of #{inspect(remote_path)} to #{owner} on the Dokku host...")

    case DokkuRemote.Root.Command.run(app.dokku_host, "chown #{owner} #{remote_path}") do
      {:ok, _output} ->
        IO.puts("\t✅ File owner set")

      {:error, output, exit} ->
        raise "Failed to set file owner, exit code #{exit}: #{output}"
    end

    :ok
  end
end
