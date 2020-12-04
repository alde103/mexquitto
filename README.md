# Mexquitto

This is a small wrapper from mosquitto broker to test MQTT and TLS using [Tortoise](https://github.com/gausby/tortoise) as MQTT client.

## Installation

Clone project.
```
git clone https://github.com/alde103/mexquitto.git
cd mexquitto
```
Get dependencies.
```
mix deps.get
```
Install mosquitto package.
```
sudo apt-get update
sudo apt-get install mosquitto
```

## Usage

Mosquitto broker is configured using an `x.conf` ([mosquitto.conf](https://mosquitto.org/man/mosquitto-conf-5.html)) file, so `mexquitto` uses the application environment to configure and spawn the broker.

## Testing TLS with MQTT

Currently I have not been able to get it to work with [Tortoise](https://github.com/gausby/tortoise) (SSL) :(

It shows `bad_cert,hostname_check_failed`, however, I think the problem is not in the certificates because there is no error when using the mosquitto clients.
```
cd test/support/ssl_mock
mosquitto_sub -h 127.0.0.1 -V mqttv311 -p 1889 --cafile ca.crt --cert device001.crt --key device001.key -t sensors/+/altitude -d
```

Run test.

```
mix test
```

