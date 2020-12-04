defmodule MQTTServerTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  require Logger

  @ca_cert_file File.cwd!() |> Path.join("test/support/ssl_mock/ca.crt")
  @server_cert_file File.cwd!() |> Path.join("test/support/ssl_mock/server.crt")
  @server_key_file File.cwd!() |> Path.join("test/support/ssl_mock/server.key")
  @device_cert_file File.cwd!() |> Path.join("test/support/ssl_mock/device001.crt")
  @device_key_file File.cwd!() |> Path.join("test/support/ssl_mock/device001.key")

  @ca_der @ca_cert_file |> File.read!() |> X509.Certificate.from_pem!() |> X509.Certificate.to_der()
  @server_der @server_cert_file |> File.read!() |> X509.Certificate.from_pem!() |> X509.Certificate.to_der()
  @device_der @device_cert_file |> File.read!() |> X509.Certificate.from_pem!() |> X509.Certificate.to_der()
  @device_key_der @device_key_file |> File.read!() |> X509.PrivateKey.from_pem!() |> X509.PrivateKey.to_der()


  @mqtt_config_with_no_security [
    enabled: true,
    clients: [],
    server: [
      enabled: true,
      listener: 1888
    ]
  ]

  @mqtt_config_with_security [
    enabled: true,
    clients: [],
    server: [
      enabled: true,
      listener: 1889,
      cafile: @ca_cert_file,
      certfile: @server_cert_file,
      keyfile: @server_key_file
    ]
  ]

  @mqtt_config_with_security_and_client_auth [
    enabled: true,
    clients: [],
    server: [
      enabled: true,
      listener: 1890,
      cafile: @ca_cert_file,
      certfile: @server_cert_file,
      keyfile: @server_key_file,
      require_certificate: true
    ]
  ]

  test "MQTT Server with no security" do   
    Application.put_env(:my_app, :mqtt, @mqtt_config_with_no_security)

    Mexquitto.start_link()

    Process.sleep(500)

    {:ok, _pid} =
      Tortoise.Connection.start_link(
        client_id: Test1,
        server: {Tortoise.Transport.Tcp, host: 'localhost', port: 1888},
        handler: {Tortoise.Handler.Logger, []},
        subscriptions: [{"foo/bar", 0}]
      )

    logs =
      capture_log(fn ->
        Process.sleep(500)
        Tortoise.publish(Test1, "foo/bar", "hello")
        Process.sleep(500)
      end)

    IO.puts(logs)
    # Server Logs
    assert logs =~ "New connection from 127.0.0.1 on port 1888"
    assert logs =~ "New client connected from 127.0.0.1 as Elixir.Test1 (p2, c1, k60)"
    assert logs =~ "foo/bar \"hello\""   
  end

  test "MQTT Server with security" do    
    Application.put_env(:my_app, :mqtt, @mqtt_config_with_security)

    Mexquitto.start_link()

    Process.sleep(500)

    logs =
      capture_log(fn ->
        Tortoise.Connection.start_link(
          client_id: Test2,
          server: {Tortoise.Transport.Tcp, host: 'localhost', port: 1889},
          handler: {Tortoise.Handler.Logger, []},
          subscriptions: [{"foo/bar", 0}]
        )
        Process.sleep(500)
      end)

    IO.puts(logs)

    # Server Logs 
    assert logs =~ "Client connection from 127.0.0.1 failed: error"
    refute logs =~ "New client connected from 127.0.0.1 as Elixir.Test2 (p2, c1, k60)"
    refute logs =~ "foo/bar \"hello\""

    Tortoise.Connection.start_link(
      client_id: Test3,
      server: {
        Tortoise.Transport.SSL,
        host: {127,0,0,1}, 
        port: 1889,
        cacerts: [@ca_der, @server_der] ++ :certifi.cacerts(),
        key: {:RSAPrivateKey, @device_key_der}, 
        cert: @device_der, 
        # partial_chain: &partial_chain/1,
        # cacertfile: File.cwd!() |> Path.join("test/support/ssl_mock/ca.crt") |> to_charlist(),
        # keyfile: File.cwd!() |> Path.join("test/support/ssl_mock/device001.key") |> to_charlist(), 
        # certfile: File.cwd!() |> Path.join("test/support/ssl_mock/device001.crt") |> to_charlist(), 
        # customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)],
        # versions: [:'tlsv1.2'],
        server_name_indication: '127.0.0.1',
        
        # log_level: :debug
        # verify: :verify_none
      },
      handler: {Tortoise.Handler.Logger, []},
      subscriptions: [{"foo/bar", 0}]
    )

    logs =
      capture_log(fn ->
        Process.sleep(500)
        Tortoise.publish(Test3, "foo/bar", "hello")
        Process.sleep(500)
      end)

    IO.puts(logs)
    # Server Logs
    assert logs =~ "New connection from 127.0.0.1 on port 1889"
    assert logs =~ "New client connected from 127.0.0.1 as Elixir.Test3 (p2, c1, k60)"
    assert logs =~ "foo/bar \"hello\""  
  end

  # test "MQTT Server with security with client auth" do    
  #   Application.put_env(:my_app, :mqtt, @mqtt_config_with_security_and_client_auth)

  #   Mexquitto.start_link()

  #   Process.sleep(500)

  #   logs =
  #     capture_log(fn ->
  #       spawn(fn ->
  #       Tortoise.Connection.start_link(
  #         client_id: Test4,
  #         server: {
  #           Tortoise.Transport.SSL,
  #           host: {127,0,0,1}, 
  #           port: 1890,
  #           verify: :verify_none
  #         },
  #         handler: {Tortoise.Handler.Logger, []},
  #         subscriptions: [{"foo/bar", 0}]
  #       ) end )
  #       Process.sleep(1000)
  #     end)

  #   IO.puts(logs)

  #   # Server Logs 
  #   assert logs =~ "New connection from 127.0.0.1 on port 1890"
  #   assert logs =~ "OpenSSL Error[0]:"
  #   assert logs =~ "tls_process_client_certificate:peer did not return a certificate"
  #   assert logs =~ "TLS :client: In state :connection received SERVER ALERT: Fatal - Certificate required"

  #   Tortoise.Connection.start_link(
  #     client_id: Test5,
  #     server: {
  #       Tortoise.Transport.SSL,
  #       host: {127,0,0,1}, 
  #       port: 1890,
  #       cacerts: [@ca_der, @server_der] ++ :certifi.cacerts(),
  #       key: {:RSAPrivateKey, @device_key_der}, 
  #       cert: @device_der,
  #       verify: :verify_none
  #     },
  #     handler: {Tortoise.Handler.Logger, []},
  #     subscriptions: [{"foo/bar", 0}]
  #   )

  #   logs =
  #     capture_log(fn ->
  #       Process.sleep(500)
  #       Tortoise.publish(Test5, "foo/bar", "hello")
  #       Process.sleep(500)
  #     end)

  #   IO.puts(logs)
  #   # Server Logs
  #   assert logs =~ "New connection from 127.0.0.1 on port 1890"
  #   assert logs =~ "New client connected from 127.0.0.1 as Elixir.Test5 (p2, c1, k60)"
  #   assert logs =~ "foo/bar \"hello\""  
  # end

  # defp partial_chain(server_certs) do
  #   # Note that the follwing certificates are in OTPCertificate format
  #   root_certs = [@ca_cert_file |> X509.Certificate.from_pem!()]

  #   Enum.reduce_while(
  #     root_certs,
  #     :unknown_ca,
  #     fn root_ca, unk_ca ->
  #       certificate_subject = X509.Certificate.extension(root_ca, :subject_key_identifier)

  #       case find_partial_chain(certificate_subject, server_certs) do
  #         {:trusted_ca, _} = result -> {:halt, result}
  #         :unknown_ca -> {:cont, unk_ca}
  #       end
  #     end
  #   )
  # end

  # defp find_partial_chain(_root_subject, []) do
  #   :unknown_ca
  # end

  # defp find_partial_chain(root_subject, [h | t]) do
  #   cert = X509.Certificate.from_der!(h)
  #   cert_subject = X509.Certificate.extension(cert, :subject_key_identifier)

  #   if cert_subject == root_subject do
  #     {:trusted_ca, h}
  #   else
  #     find_partial_chain(root_subject, t)
  #   end
  # end
end
