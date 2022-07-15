#!/bin/bash

EXECUTION_START_TIME=$(date +"%s")

RAW_DIRECTORY=raw
OUTPUT_DIRECTORY=data
WAIT_SECONDS=5
MAXIMUM_RETRY_PER_REQUEST=5

START_YEAR=1993
CURRENT_YEAR=$(date +"%Y")
DATE_RANGES="0101;0331 0401;0630 0701;0930 1001;1231"

mkdir -p $RAW_DIRECTORY
mkdir -p $OUTPUT_DIRECTORY

i=$START_YEAR
while [ $i -le $CURRENT_YEAR ]
do
  for quarter in $DATE_RANGES
  do
    dates=($(echo $quarter | sed 's/;/ /g'))
    output_file="./$RAW_DIRECTORY/${i}${dates[0]}-${i}${dates[1]}.json";
    readable_date_range="${i}/${dates[0]:0:2}/${dates[0]:2:2} - ${i}/${dates[1]:0:2}/${dates[1]:2:2}"

    if [ -f "$output_file" ] && [ $i -ne $CURRENT_YEAR ]; then
      echo "Skip scraping data for $readable_date_range as file exists."
    else
      echo "Scraping data for $readable_date_range."

      response=$(curl --location \
      --silent \
      --write-out "status_code:%{http_code}" \
      --request GET "https://bet.hkjc.com/marksix/getJSON.aspx/?sd=${i}${dates[0]}&ed=${i}${dates[1]}&sb=0" \
      --output $output_file \
      --compressed \
      --retry $MAXIMUM_RETRY_PER_REQUEST \
      --retry-delay $WAIT_SECONDS)

      response_body=$(echo $response | sed -E 's/status_code\:[0-9]{3}$//')
      status_code=$(echo $response | tr -d '\n' | sed -E 's/.*status_code:([0-9]{3})$/\1/')

      if [[ "$status_code" -ge 300 || "$status_code" -lt 200 ]] ; then
        echo "Error encountered when scraping data for $readable_date_range. (Status Code: ${status_code})"
        echo "Process will exit. Please run this script again."

        EXIT_TIME=$(date +"%s")
        echo "Process terminated after $((EXIT_TIME-EXECUTION_START_TIME))s."
        exit 1;
      else
        echo "Scrap data for $readable_date_range success. (Status Code: ${status_code})"
      fi

      echo "Sleeping for ${WAIT_SECONDS} second(s)."
      sleep $WAIT_SECONDS
    fi
  done

  i=$(( i + 1 ))
done

jq '{ data: [ inputs ] | add } | .data[].no |= split("+")' $RAW_DIRECTORY/* > $OUTPUT_DIRECTORY/all.json

jq '{ 
  total: .data | length, 
  stats_without_sno: (
    [.data[].no[]] | map(tonumber) | sort | group_by(.) | map({ (.[0] | tostring): select(.) | length })
  ) | add, 
  stats_with_sno: (
    [.data[].no[],.data[].sno] | map(tonumber) | sort | group_by(.) | map({ (.[0] | tostring): select(.) | length })
  ) | add,
  stats_sno_only: (
    [.data[].sno] | map(tonumber) | sort | group_by(.) | map({ (.[0] | tostring): select(.) | length })
  ) | add
}' $OUTPUT_DIRECTORY/all.json > $OUTPUT_DIRECTORY/stats.json

EXECUTION_END_TIME=$(date +"%s")
echo "Done in $((EXECUTION_END_TIME-EXECUTION_START_TIME))s."
