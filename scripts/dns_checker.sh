#!/bin/bash

# This script runs a DNS query using dig and outputs the results in valid JSON format.
# It accepts up to three arguments: <DNS server> <domain> <record type>. When only a domain is provided,
# the default record type ("A") and system nameserver are used.
# The script parses the dig output to extract the name, TTL, class, record type, and data fields.
# Finally, it outputs a JSON object containing the query time and an array of record objects.
# Requirments bind-utils

is_ip() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

setup_arguments() {
    if [ "$#" -eq 1 ]; then
        dns_server="$default_dns_server"
        name="$1"
        record_type="$default_record_type"
    elif [ "$#" -eq 2 ]; then
        if is_ip "$1"; then
            dns_server="$1"
            name="$2"
            record_type="$default_record_type"
        else
            dns_server="$default_dns_server"
            name="$1"
            record_type="$2"
        fi
    elif [ "$#" -eq 3 ]; then
        dns_server="$1"
        name="$2"
        record_type="$3"
    else
        echo "{\"Error\": \"Argument error. Usage: dns_checker.sh <server> <domain> <record_type>\"}"
        exit 1
    fi

    if [ -n "$dns_server" ]; then
        server_arg="@$dns_server"
    else
        server_arg=""
    fi
}

create_json_record() {
    records_json=""
    first=1
    record_id=1
    pars_record_output() {
        while IFS= read -r line; do
            if [ -n "$line" ]; then
                record_obj=$(echo "$line" | awk -v id="$record_id" '{
                    field1 = $1;
                    field2 = $2;
                    field3 = $3;
                    field4 = $4;
                    field5 = "";
                    for(i = 5; i <= NF; i++){
                        field5 = field5 $i (i == NF ? "" : " ");
                    }
                    if (field5 ~ /^".*"$/) {
                        field5 = substr(field5, 2, length(field5)-2)
                    }
                    printf("{\"id\": %d, \"name\": \"%s\", \"ttl\": \"%s\", \"class\": \"%s\", \"type\": \"%s\", \"data\": \"%s\"}", id, field1, field2, field3, field4, field5);
                }')
                if [ $first -eq 1 ]; then
                    records_json="$record_obj"
                    first=0
                else
                    records_json+=", $record_obj"
                fi
                record_id=$((record_id + 1))
            fi
        done <<< "$answer_output"
    }

    if echo "$answer_output" | grep -q "communications error"; then
        echo "{\"Error\": \"Communications error\"}"
        exit 1
    else
        pars_record_output
    fi
}

# default values
default_dns_server=""
default_record_type="A"

setup_arguments $1 $2 $3

answer_output=$(dig $server_arg "$name" "$record_type" +noall +answer)
query_stats=$(dig $server_arg "$name" "$record_type" +noall +stats)
query_time=$(echo "$query_stats" | grep "Query time:" | awk '{print $4}')
query_msg_size=$(echo "$query_stats" | grep "MSG SIZE" | awk '{print $5}')


create_json_record

json_output="{\"query_time\": \"${query_time}\",\"query_msg_size\": \"${query_msg_size}\", \"records\": [${records_json}]}"
echo "$json_output"
