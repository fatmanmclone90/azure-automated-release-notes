#!/bin/bash

# file must be in working directory
if ! test -f ./results.xml; then
  echo "##[error]results.xml does not exist, exiting";
  exit 1;
fi

readarray -t results < <(xmlstarlet sel -t -m "testsuites/testsuite/*" -v "@name" -v "';'" -v "properties/property/@value" -v "';'" -v "failure/@type"  -n results.xml);

declare -a bodyItems=();
for result in "${results[@]}";
do
    IFS=';' read -ra props <<< "$result"
    
    # To Do: Add null checks
    title=${props[0]};
    id=${props[1]};
    failure=${props[2]};

    if [ ! -z "$failure" -a "$failure" != " " ]; then
        outcome="failed"
    else
        outcome="passed";
    fi

    body="{\"id\":$id,\"results\":{\"outcome\":\"$outcome\"}}";
    bodyItems+=($body);
done

if [ ${#bodyItems[@]} -eq 0 ]; then
    echo "##[debug]No tests found, exiting.";
    exit 0;
else
    patchBody=$(IFS=,; echo "${bodyItems[*]}");
    patchBody="[$patchBody]";
fi

echo "##[debug]Sending HTTP Request:"
jq <<< $patchBody

httpResponse=$(curl \
    -H "Authorization: Bearer $accessToken" \
    -H "Content-Type: application/json" \
    -XPATCH "https://dev.azure.com/<organization>/<project>/_apis/testplan/Plans/$testPlanId/Suites/$testSuiteId/TestPoint?api-version=7.1-preview.2" \
    -d $patchBody --silent --write-out "HTTPSTATUS:%{http_code}")

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
    echo "##[debug]Successfully updated Test Plan:";
    # assumes successful response will alwaye be JSON
    jq <<< $httpBody;

    exit 0;
fi

exit 1;





