#!/bin/bash
# This script runs a DNS query using dig and outputs the results in valid JSON format.
# It accepts up to three arguments: [DNS server] [domain] [record type]. When only a domain is provided,
# the default record type ("A") and system nameserver are used.
# The script parses the dig output to extract the name, TTL, class, record type, and data fields.
# If the data field is enclosed in double quotes (as is common with TXT records), those quotes are removed.
# Finally, it outputs a JSON object containing the query time and an array of record objects.
# Requirments bind-utils

# default values
default_dns_server=""
default_record_type="A"

is_ip() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

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
    echo "Usage:"
    echo "  $0 <domain>"
    echo "  $0 <domain> <record_type>"
    echo "  $0 <dns_server> <domain> <record_type>"
    exit 1
fi

if [ -n "$dns_server" ]; then
    server_arg="@$dns_server"
else
    server_arg=""
fi

answer_output=$(dig $server_arg "$name" "$record_type" +noall +answer)
query_time=$(dig $server_arg "$name" "$record_type" +noall +stats | grep "Query time:" | awk '{print $4}')

records_json=""
first=1
record_id=1

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

json_output="{\"query_time\": \"${query_time}\", \"records\": [${records_json}]}"
echo "$json_output"
