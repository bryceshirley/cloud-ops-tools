# Meerkat Benchmarking
This is the Meerkat benchmarking tool, which uses Ansible to spin up VMs in Openstack, run a benchmark on them and shut those VMs down.

Currently Meerkat has the following benchmarks available:
- HEPScore, a CPU benchmark
- Sysbench, a storage benchmark

## Running Meerkat
Meerkat requires Openstack credentials to create or delete VMs. These can be obtained by creating an application credential and putting it in the clouds.yaml file in ~/.config/openstack.

Meerkat can be run from this directory with the command:

`./run_meerkat.sh -k <KEYPAIR_NAME>`

Where:
- `<KEYPAIR_NAME>` is the name of the Openstack keypair that will be used to by Meerkat to access VMs.

To select which benchmark to run:
You must change the groups called in 'staging-openstack.yaml'

You must also set some variables in the `vars` folder for the benchmark you want to run:
- `db_ip`
    - The URL of a VictoriaMetrics instance for benchmarks to send their results to
- `db_port`
    - The port of your VictoriaMetrics instance to send to (default 8428)

