#!/bin/bash

# NOT FINISHED OR PLUGGED IN

buildId=73632
environment=uat-a

# Need to check how it works on CI
#-H "authorization: Bearer $AZURE_DEVOPS_EXT_PAT" \

# PAT token in env
httpResponse=$(curl -k -XGET \
-H "Authorization: Basic $(printf ":%s" "$AZURE_DEVOPS_EXT_PAT" | base64)" \
-H "Content-Type: application/json" \
"https://dev.azure.com/$organisation/$project/_apis/test/ResultDetailsByBuild?buildId=$buildId&shouldIncludeResults=false&groupBy=testRun" \
--silent --write-out "HTTPSTATUS:%{http_code}")

httpBody=$(echo $httpResponse | sed -e 's/HTTPSTATUS\:.*//g');

httpStatus=$(echo $httpResponse | tr -d '\n' | sed -e 's/.*HTTPSTATUS://');

if [ ! $httpStatus -eq 200 ]; then
    echo "##[error]Received HTTP: $httpStatus, expected HTTP: 200";
    exit 1;
fi

testRun=$(jq '.resultsForGroup[] | select(.groupByValue.name == "Cucumber Test Run")' <<< $httpBody);
retries=$(jq '.resultsForGroup[] | select(.groupByValue.name == "Cucumber Test Retries")' <<< $httpBody);
successCount=$(jq '.resultsCountByOutcome.Passed.count' <<< $testRun)
failedCount=$(jq '.resultsCountByOutcome.Failed.count' <<< $testRun)
failedRetryCount=$(jq '.resultsCountByOutcome.Failed.count' <<< $retries)

if [ $failedRetryCount -gt 0 ]; then
    status="Failed"
else
    status="Success"
fi

body=$(cat <<EOF
    {
        "@type": "MessageCard",
        "@context": "http://schema.org/extensions",
        "themeColor": "0076D7",
        "summary": "Test Results",
        "sections": [{
            "activityTitle": "Test Results",
            "activitySubtitle": "$environment",
            "activityImage": "https://adaptivecards.io/content/cats/3.png",
            "facts": [{
                "name": "Tests Passed",
                "value": "$successCount"
            }, 
            {
                "name": "Tests Failed Initial Run",
                "value": "$failedCount"
            }, 
            {
                "name": "Tests Failed After Retry",
                "value": "$failedRetryCount"
            }, 
            {
                "name": "Status",
                "value": "$status"
            }],
            "markdown": true
        }],
        "potentialAction": [
            {
                "@type": "OpenUri",
                "name": "View Results",
                "targets": [
                    {
                        "os": "default",
                        "uri": "https://dev.azure.com/$organisation/$project/_build/results?buildId=$buildId&view=results"
                    }
                ]
            }
        ]
    }
EOF
)

httpResponse=$(curl -k -H "Content-Type: application/json" \
-X POST -d "$body" \
"https://$organisation.webhook.office.com/webhookb2/blah" \
--silent --write-out "HTTPSTATUS:%{http_code}");

httpBody=$(echo $httpResponse | sed -e 's/HTTPSTATUS\:.*//g');

httpStatus=$(echo $httpResponse | tr -d '\n' | sed -e 's/.*HTTPSTATUS://');

if [ ! $httpStatus -eq 200 ]; then
    echo "##[error]Received HTTP: $httpStatus, expected HTTP: 200";
    exit 1;
fi

echo "message sent";


