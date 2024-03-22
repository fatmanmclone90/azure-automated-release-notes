#!/bin/bash

url="https://dev.azure.com/<organization>/<project>/_apis/testplan/Plans/$testPlanId/Suites/$testSuiteId/TestPoint?includePointDetails=false&api-version=7.1-preview.2";
echo "##[debug]HTTP Request URL: $url";

httpResponse=$(curl -D headers.txt \
  -H "Authorization: Bearer $accessToken" \
  -H "Content-Type: application/json" \
  -XGET $url \
  --silent --write-out "HTTPSTATUS:%{http_code}")

# To Do: Check for Continuation Token in headers and loop
# https://learn.microsoft.com/en-us/rest/api/azure/devops/testplan/test-point/get-points-list?view=azure-devops-rest-7.1

httpBody=$(echo $httpResponse | sed -e 's/HTTPSTATUS\:.*//g');

httpStatus=$(echo $httpResponse | tr -d '\n' | sed -e 's/.*HTTPSTATUS://');

if [ ! $httpStatus -eq 200 ]; then
  echo "##[error]Error [HTTP status: $httpStatus], expected HTTP 200";
  
  if [ ! -z "$httpBody" ]; then
    echo "##[debug]Http Response Body:";
    
    if jq -e . >/dev/null 2>&1 <<<"$httpBody"; then
      jq <<< $httpBody;
    else
      echo $httpBody;
    fi
    
    exit 1;
  fi
else
    echo "##[debug]Successfully fetched Test Points:";
    # assumes successful response will alwaye be JSON
    jq <<< $httpBody;
fi

exit 0;






