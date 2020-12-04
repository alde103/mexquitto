defmodule Mexquitto do
  @moduledoc """
  A MQTT Server (mosquitto wrapper), which creates a `mqtt.conf` based on Application enviroment.
  """
  use GenServer
  require Logger

  @target Mix.target()

  defstruct erl_port: nil,
            server_params: nil,
            mqtt_conf_str: nil,
            mqtt_conf_path: nil

  def start_link() do
    GenServer.start_link(__MODULE__, mqtt_enabled?(), name: __MODULE__)
  end

  def init(false) do
    Logger.info("(#{__MODULE__}) MQTT Server is disabled...")
    {:ok, nil}
  end

  def init(true) do
    Logger.info("(#{__MODULE__}) Init. MQTT Server: #{get_mqtt_server_params() |> inspect()}")
    state = 
      %__MODULE__{
        server_params: get_mqtt_server_params(),
        mqtt_conf_path: mosquitto_conf_path(@target)
      }
    {:ok, state, {:continue, :spawn_mqtt_server}}
  end

  def handle_continue(:spawn_mqtt_server, %{mqtt_conf_path: path, server_params: params} = state) do
    executable_path = System.find_executable("mosquitto")

    params
    |> build_mqtt_conf()
    |> write_mqtt_conf_file(path)

    {:ok, erl_port} = 
      MuonTrap.Daemon.start_link(executable_path, 
        ["-c", path], 
        [
          stderr_to_stdout: true, 
          log_output: :debug,
          log_prefix: "(#{__MODULE__}) "
        ])

    {:noreply, %{state | erl_port: erl_port, mqtt_conf_str: build_mqtt_conf(params)}}
  end

  def write_mqtt_conf_file(term, dir) do
    case File.write(dir, term) do
      :ok ->
        Logger.info("(#{__MODULE__}) mqtt.conf file created")
        term

      {:error, reason} ->
        Logger.warn("(#{__MODULE__}) Error creating mqtt.conf file reason: #{inspect(reason)}")
        Process.sleep(1000)
        write_mqtt_conf_file(term, dir)
    end
  end

  def handle_info({_port, {:data, data}}, state) do
    Logger.debug("(#{__MODULE__}) data: #{inspect data}.")
    {:noreply, state}
  end

  def handle_info({_port, {:exit_status, code}}, state) do
    Logger.warn("(#{__MODULE__}) Error code: #{inspect code}.")
    Process.sleep(4000) #retrying delay
    {:stop, :restart, state}
  end

  def handle_info({:EXIT, _port, reason}, state) do
    Logger.debug("(#{__MODULE__}) Exit reason: #{inspect(reason)}")
    Process.sleep(4000) #retrying delay
    {:stop, :restart, state}
  end

  def handle_info(msg, state) do
    Logger.debug("(#{__MODULE__}) Unexpected msg: #{inspect(msg)}")
    {:noreply, state}
  end

  defp build_mqtt_conf(mqtt_params) do
    mqtt_params
    |> Keyword.delete(:enabled)
    |> Enum.reduce("", fn({key, data}, acc) -> acc <> "#{key} #{data}\n" end)
  end

  defp get_mqtt_params(), do: Application.get_env(:my_app, :mqtt, []) 
  defp get_mqtt_server_params(), do: get_mqtt_params() |> Keyword.get(:server, [])
  defp mqtt_enabled?(), do: get_mqtt_server_params() |> Keyword.get(:enabled, false)
  defp mosquitto_conf_path(:host), do: File.cwd!() |> Path.join("draft/mqtt.conf")
  defp mosquitto_conf_path(_target), do: "/root/mqtt.conf"
end
