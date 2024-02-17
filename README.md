# Run a Jack Server in a Container

Copyright (c) 2023-2024 JackTrip Labs, Inc.
See [MIT License](LICENSE)

This repository provides the source code for building a container image to run the
[Jack Audio Connection Kit](https://jackaudio.org/) server.

It uses Red Hat's [Universal Base Images](https://catalog.redhat.com/software/base-images),
in particular `ubi-init`, to run the `jackd` server as systemd service. The `jackd` server
is configued to use the `dummy` audio backend so that no audio interface is required. 

To build a container image using `podman`:

```bash
podman build -t jacktrip/jack .
```

To run a Jack container using `podman`:

```bash
podman run --name jack --shm-size=128M -d jacktrip/jack
```

`jackd` requires the ability to lock about 128MB of shared memory, and
will try to run realtime priority threads. Be sure that your memory
limits (`ulimit`) are set appropriately.

```
ulimit -l 128000000
ulimit -r 10
```

If using `docker`, you will need to run this as a privileged container:

```bash
docker run --name jack --shm-size=128M --privileged -d jacktrip/jack
```

By default, the servers will run using a sample rate of 48Khz and buffer
size of 128. You can override these using the following environment
variables:

* __SAMPLE_RATE__: use this to set the sample rate for the `jackd` server.
Note that all clients connecting to the server must use the same setting.
The default is 48000.

* __BUFFER_SIZE__: use this to set the buffer size, also known as frames
per period, for the `jackd` server. The default is 128.

* __JACK_OPTS__: use this to override all of the options passed to the
`jackd` server. __SAMPLE_RATE__ and __BUFFER_SIZE__ will be ignored
if this is defined.
