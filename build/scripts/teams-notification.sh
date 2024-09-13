#!/bin/bash

ORGANISATION=${1};
PROJECT=${2};
WEBHOOK_URL=${3};
BUILD_ID=${4};
ENVIRONMENT=${5};
IS_LOCAL=${6:-false};

# Parameters
echo "ORGANISATION: $ORGANISATION";
echo "PROJECT: $PROJECT";
echo "WEBHOOK_URL: $WEBHOOK_URL";
echo "BUILD_ID: $BUILD_ID";
echo "ENVIRONMENT: $ENVIRONMENT";
echo "IS_LOCAL: $IS_LOCAL";

# Environment Variable
echo "AZURE_DEVOPS_EXT_PAT: $AZURE_DEVOPS_EXT_PAT";


if [[ "${ORGANISATION}" == "" ]] || "${PROJECT}" == "" ]] || "${WEBHOOK_URL}" == "" ]] || [[ "${BUILD_ID}" == "" ]] || [[ "${ENVIRONMENT}" == "" ]]; then
  echo "Missing required parameter."
  exit 1
fi

if [ "$IS_LOCAL" = true ]; then
  AUTH="Authorization: Basic $(printf ":%s" "$AZURE_DEVOPS_EXT_PAT" | base64)";
else
  AUTH="Authorization: Bearer $AZURE_DEVOPS_EXT_PAT";
fi

for ((i = 0 ; i < 5 ; i++ )); 
do 
    HTTP_RESPONSE=$(curl -k -XGET \
        -H "$AUTH" \
        -H "Content-Type: application/json" \
        "https://dev.azure.com/$ORGANISATION/$PROJECT/_apis/test/ResultDetailsByBuild?buildId=$BUILD_ID&shouldIncludeResults=false&groupBy=testRun" \
        --silent --write-out "HTTP_STATUS:%{http_code}")

        HTTP_BODY=$(echo $HTTP_RESPONSE | sed -e 's/HTTP_STATUS\:.*//g');

        HTTP_STATUS=$(echo $HTTP_RESPONSE | tr -d '\n' | sed -e 's/.*HTTP_STATUS://');

        if ([ $HTTP_STATUS -ge 400 ] && [ $HTTP_STATUS -le 499 ]) || [ $HTTP_STATUS -eq 302 ]; then
            # non recoverable
            echo "##[error]Received HTTP: $HTTP_STATUS, expected HTTP: 200";
            echo "##[error]Failed to fetch test results";
            echo "##[error]$HTTP_BODY";
            exit 1;
        fi

        if [ $HTTP_STATUS -eq 200 ]; then
            break;
        fi

        i++;
        # test results can be delayed, attempting retry
        sleep 1;
done

TEST_RUN=$(jq '.resultsForGroup[] | select(.groupByValue.name == "Cucumber Test Run")' <<< $HTTP_BODY);
SUCCESS_COUNT=$(jq '.resultsCountByOutcome.Passed.count' <<< $TEST_RUN);
FAILED_COUNT=$(jq '.resultsCountByOutcome.Failed.count' <<< $TEST_RUN);
STARTED_DATETIME=$(jq '.groupByValue.startedDate' <<< $TEST_RUN);
STARTED_DATE=${STARTED_DATETIME%T*}
STARTED_DATE=${STARTED_DATE:1}

IS_NUMBER='^[0-9]+$'
if ! [[ $FAILED_COUNT =~ $IS_NUMBER ]] ; then
   FAILED_COUNT=0;
fi

if [ $FAILED_COUNT -gt 0 ]; then
    STATUS="Failed"
else
    STATUS="Success"
fi

if [ $STATUS = "Success" ]; then
    CARD_IMAGE="https://adaptivecards.io/content/cats/3.png";
    STATUS_COLOUR="Good";
else
    CARD_IMAGE="https://adaptivecards.io/content/cats/2.png";
    STATUS_COLOUR="Attention";
fi

BODY=$(cat <<EOF
    {
  "type": "message",
  "attachments": [
    {
      "contentType": "application/vnd.microsoft.card.adaptive",
      "contentURL": null,
      "content": {
        "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
        "version": "1.4",
        "type": "AdaptiveCard",
        "body": [
          {
            "type": "ColumnSet",
            "columns": [
              {
                "type": "Column",
                "width": 2,
                "items": [
                  {
                    "type": "TextBlock",
                    "text": "Execution Results",
                    "weight": "Bolder",
                    "size": "ExtraLarge",
                    "spacing": "None",
                    "wrap": true,
                    "style": "heading"
                  },
                  {
                    "type": "TextBlock",
                    "text": "Environment: $ENVIRONMENT",
                    "spacing": "None",
                    "wrap": true,
                    "size": "Medium",
                    "color": "Accent",
                    "isSubtle": false
                  },
                  {
                    "type": "TextBlock",
                    "text": "Status: $STATUS",
                    "spacing": "None",
                    "wrap": true,
                    "size": "Medium",
                    "color": "$STATUS_COLOUR",
                    "isSubtle": false
                  },
                  {
                    "type": "TextBlock",
                    "text": "Executed on: $STARTED_DATE",
                    "spacing": "None",
                    "wrap": true
                  }
                ]
              },
              {
                "type": "Column",
                "width": 1,
                "items": [
                  {
                    "type": "Image",
                    "url": "$CARD_IMAGE",
                    "altText": "Image of a cat"
                  }
                ]
              }
            ]
          },
          {
            "type": "TextBlock",
            "text": "Test Report",
            "weight": "Bolder",
            "wrap": true,
            "style": "heading"
          },
          {
            "type": "Container",
            "separator": true,
            "items": [
              {
                "type": "FactSet",
                "facts": [
                  {
                    "title": "Tests Passed",
                    "value": "$SUCCESS_COUNT"
                  },
                  {
                    "title": "Tests Failed",
                    "value": "$FAILED_COUNT"
                  }
                ],
                "spacing": "Small"
              }
            ],
            "spacing": "Small"
          },
          {
            "type": "TextBlock",
            "text": "[View Results](https://dev.azure.com/$ORGANISATION/$PROJECT/_build/results?buildId=$BUILD_ID&view=ms.vss-test-web.build-test-results-tab)",
            "weight": "Bolder",
            "spacing": "Medium",
            "wrap": true
          }
        ]
      }
    }
  ]
}
EOF
)

HTTP_RESPONSE=$(curl -k -H "Content-Type: application/json" \
-X POST -d "$BODY" \
"$WEBHOOK_URL" \
--silent --write-out "HTTP_STATUS:%{http_code}");

HTTP_BODY=$(echo $HTTP_RESPONSE | sed -e 's/HTTP_STATUS\:.*//g');

HTTP_STATUS=$(echo $HTTP_RESPONSE | tr -d '\n' | sed -e 's/.*HTTP_STATUS://');

# Response from Teams is unreiable, sometimes 202
if [ ! $HTTP_STATUS -eq 200 ] && [ ! $HTTP_STATUS -eq 202 ]; then
    # Message can still have failed even when HTTP 200
    echo "##[error publishing message to teams channel]Received HTTP: $HTTP_STATUS, expected HTTP: 200 or 202";
    exit 1;
fi
