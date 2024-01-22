#!/bin/bash

run_benchmark () {
	echo -------------------------------------------------------
	echo $file_number x $file_size MB files
	echo -------------------------------------------------------
	
	local output=$(./sysbench.sh -n $file_number -s $file_size)
	seqw=$(echo "$output" | grep -ioP "Sequential write: +(?)\d+(?:\.\d+)?" | grep -oP "\d+(?:\.\d+)?")
	seqr=$(echo "$output" | grep -ioP "Sequential read: +(?)\d+(?:\.\d+)?" | grep -oP "\d+(?:\.\d+)?")
	randw=$(echo "$output" | grep -ioP "Random write: +(?)\d+(?:\.\d+)?" | grep -oP "\d+(?:\.\d+)?")
	randr=$(echo "$output" | grep -ioP "Random read: +(?)\d+(?:\.\d+)?" | grep -oP "\d+(?:\.\d+)?")
	echo Seq write: $seqw MB/s
	echo Seq read: $seqr MB/s
	echo Rand write: $randw MB/s
	echo Rand read: $randr MB/s

}

send_data() {
	local metric=$1
	local result=$2

	"curl -H 'Content-Type: application/json' -d '{"metric":"'$metric'","value":"'$result'","tags":{"flavor":"'$flavor'", "image":"'$image'","test_type":"'$test_size'", "storage_type":"'$storage_type'"}}' $DB"
        #echo "curl -H 'Content-Type: application/json' -d '{"metric":"$metric","value":"$result","tags":{"flavor":"$flavor", "image":"$image","test_type":"$test_size", "storage_type":"$storage_type"}}' $DB"
}


benchmark_and_send_data () {
	file_number=$1
	file_size=$2
	test_size=$3
        storage_type=$4

	run_benchmark
	send_data "sequential_write" "$seqw"
	send_data "sequential_read" "$seqr"
	send_data "random_write" "$randw"
	send_data "random_read" "$randr"
}

# Get VM infor
server_UUID=$(curl  http://169.254.169.254/openstack/latest/meta_data.json -s  | grep -ioP .{8}-.{4}-.{4}-.{4}-.{12})
vm_info=$(openstack server show $server_UUID --os-cloud openstack)
#hypervisor=$(echo $vm_info | grep -ioP "\w*.nubes.rl.ac.uk" | head -1)
flavor=$(echo $vm_info | grep -ioP "flavor\s\|\s\S*" | cut -c 10-)
image=$(echo $vm_info | grep -ioP "image\s\|\s\S*" | cut -c 9-)

DB="http://172.16.101.186:4242/api/put"

benchmark_and_send_data "1000" "0.001" "kb" "local"
benchmark_and_send_data "1000" "1" "mb" "local"
benchmark_and_send_data "10" "1000" "gb" "local"
