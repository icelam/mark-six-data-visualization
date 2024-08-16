#!/bin/bash

EXECUTION_START_TIME=$(date +"%s")

RAW_DIRECTORY=raw
OUTPUT_DIRECTORY=data
WAIT_SECONDS=5
MAXIMUM_RETRY_PER_REQUEST=5

START_YEAR=1993
CURRENT_DATE=$(date +"%Y%m%d")
CURRENT_YEAR=${CURRENT_DATE:0:4}
DATE_RANGES="0101-0331 0401-0630 0701-0930 1001-1231"

mkdir -p $RAW_DIRECTORY
mkdir -p $OUTPUT_DIRECTORY


for ((i=$START_YEAR; i<=$CURRENT_YEAR; i++))
do
  for quarter in $DATE_RANGES
  do
    dates=(${quarter//-/ })
    output_file="./$RAW_DIRECTORY/${i}${dates[0]}-${i}${dates[1]}.json";
    readable_date_range="${i}/${dates[0]:0:2}/${dates[0]:2:2} - ${i}/${dates[1]:0:2}/${dates[1]:2:2}"

    if [[ -f "$output_file" ]] && [[ "$i${dates[1]}" -lt $CURRENT_DATE ]]; then
      echo "Skip scraping data for $readable_date_range as file exists."
    elif [[ $CURRENT_DATE -ge "$i${dates[0]}" ]]; then
      echo "Scraping data for $readable_date_range."

      response=$(curl --location \
      --silent \
      --write-out "status_code:%{http_code}" \
      --request GET "https://bet2.hkjc.com/marksix/getJSON.aspx/?sd=${i}${dates[0]}&ed=${i}${dates[1]}&sb=0" \
      --output $output_file \
      --compressed \
      --retry $MAXIMUM_RETRY_PER_REQUEST \
      --retry-delay $WAIT_SECONDS)

      response_body=$(echo $response | sed -E "s/status_code\:[0-9]{3}$//")
      status_code=$(echo $response | tr -d "\n" | sed -E "s/.*status_code:([0-9]{3})$/\1/")

      if [[ "$status_code" -ge 300 || "$status_code" -lt 200 ]] ; then
        echo "Error encountered when scraping data for $readable_date_range. (Status Code: ${status_code})"
        echo "Process will exit. Please run this script again."

        EXIT_TIME=$(date +"%s")
        echo "Process terminated after $((EXIT_TIME-EXECUTION_START_TIME))s."
        exit 1;
      else
        echo "Scrape data for $readable_date_range success. (Status Code: ${status_code})"
      fi

      echo "Sleeping for ${WAIT_SECONDS} second(s)."
      sleep $WAIT_SECONDS
    fi
  done
done

jq -e '(([ ., inputs ] | add) | .[].no |= split("+"))
| .[].date |= (strptime("%d/%m/%Y") | mktime | strftime("%Y-%m-%d"))
| . |= sort_by(.date) | reverse' $RAW_DIRECTORY/* > $OUTPUT_DIRECTORY/all.json

if [[ "$?" -gt 0 ]] ; then
  echo "Cannot parse raw JSON, exiting..."
  exit 1
fi

jq -e '{
  total: . | length,
  stats_without_sno: (
    [.[].no[]] | map(tonumber) | sort | group_by(.) | map({ (.[0] | tostring): select(.) | length })
  ) | add,
  stats_with_sno: (
    [.[].no[],.[].sno] | map(tonumber) | sort | group_by(.) | map({ (.[0] | tostring): select(.) | length })
  ) | add,
  stats_sno_only: (
    [.[].sno] | map(tonumber) | sort | group_by(.) | map({ (.[0] | tostring): select(.) | length })
  ) | add
}' $OUTPUT_DIRECTORY/all.json > $OUTPUT_DIRECTORY/stats.json

if [[ "$?" -gt 0 ]] ; then
  echo "Failed to generate stats, exiting..."
  exit 1
fi

EXECUTION_END_TIME=$(date +"%s")
echo "Done in $((EXECUTION_END_TIME-EXECUTION_START_TIME))s."
