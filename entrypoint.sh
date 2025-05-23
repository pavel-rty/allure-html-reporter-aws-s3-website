#! /usr/bin/env bash

          cat > index-template.html <<EOF

<!DOCTYPE html>
<html>
<head>
 <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
 <title>Test Results</title>
 <style type="text/css">
  BODY { font-family : monospace, sans-serif;  color: black;}
  P { font-family : monospace, sans-serif; color: black; margin:0px; padding: 0px;}
  A:visited { text-decoration : none; margin : 0px; padding : 0px;}
  A:link    { text-decoration : none; margin : 0px; padding : 0px;}
  A:hover   { text-decoration: underline; background-color : yellow; margin : 0px; padding : 0px;}
  A:active  { margin : 0px; padding : 0px;}
  .VERSION { font-size: small; font-family : arial, sans-serif; }
  .NORM  { color: black;  }
  .FIFO  { color: purple; }
  .CHAR  { color: yellow; }
  .DIR   { color: blue;   }
  .BLOCK { color: yellow; }
  .LINK  { color: aqua;   }
  .SOCK  { color: fuchsia;}
  .EXEC  { color: green;  }
 </style>
</head>
<body>
	<h1>Test Results</h1><p>
	<a href=".">.</a><br>

EOF
          
          

unset JAVA_HOME

mkdir -p ./${INPUT_ALLURE_HISTORY}

if [[ ${INPUT_REPORT_URL} != '' ]]; then
    S3_WEBSITE_URL="${INPUT_REPORT_URL}"
fi
#echo "executor.json"
echo '{"name":"GitHub Actions","type":"github","reportName":"Allure Report with history",' > executor.json
echo "\"url\":\"${GITHUB_PAGES_WEBSITE_URL}\"," >> executor.json # ???
echo "\"reportUrl\":\"${GITHUB_PAGES_WEBSITE_URL}/${DEST_DIR}/${INPUT_GITHUB_RUN_NUM}/\"," >> executor.json
echo "\"buildUrl\":\"https://github.com/${INPUT_GITHUB_REPO}/actions/runs/${INPUT_GITHUB_RUN_ID}\"," >> executor.json
echo "\"buildName\":\"GitHub Actions Run #${INPUT_GITHUB_RUN_ID}\",\"buildOrder\":\"${INPUT_GITHUB_RUN_NUM}\"}" >> executor.json
#cat executor.json
mv ./executor.json ./${INPUT_ALLURE_RESULTS}

#environment.properties
echo "URL=${S3_WEBSITE_URL}" >> ./${INPUT_ALLURE_RESULTS}/environment.properties


ls -l ${INPUT_ALLURE_RESULTS}
cat ./${INPUT_ALLURE_RESULTS}/history/history-trend.json && echo
rm -rf ./${INPUT_ALLURE_RESULTS}/history
mkdir -p ./${INPUT_ALLURE_RESULTS}/history
# INPUT_LATEST_DEST looks like "Desktop Chrome"
# convert INPUT_LATEST_DEST to URL safe string, lowercase, replace spaces with dashes
# example: "Desktop Chrome" -> "desktop-chrome"
LATEST_URL=$(echo ${INPUT_LATEST_DEST} | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g')
echo "downloading latest history from s3 (${INPUT_LATEST_DEST}): ${LATEST_URL}"
sh -c "aws s3 cp s3://${AWS_S3_BUCKET}/${LATEST_URL}/history ./${INPUT_ALLURE_RESULTS}/history \
              --no-progress \
              --recursive"

cat ./${INPUT_ALLURE_RESULTS}/history/history-trend.json && echo

echo "generating report from ${INPUT_ALLURE_RESULTS} to ${INPUT_ALLURE_REPORT} ..."
ls -l ${INPUT_ALLURE_RESULTS}
allure generate --clean ${INPUT_ALLURE_RESULTS} -o ${INPUT_ALLURE_REPORT}
cat ./${INPUT_ALLURE_REPORT}/history/history-trend.json && echo
echo "listing report directory ..."
ls -l ${INPUT_ALLURE_REPORT}

echo "copy allure-report to ${INPUT_ALLURE_HISTORY}/${INPUT_GITHUB_RUN_NUM}"
cp -r ./${INPUT_ALLURE_REPORT}/. ./${INPUT_ALLURE_HISTORY}/${INPUT_GITHUB_RUN_NUM}
# echo "copy allure-report history to /${INPUT_ALLURE_HISTORY}/last-history"
# cp -r ./${INPUT_ALLURE_REPORT}/history/. ./${INPUT_ALLURE_HISTORY}/last-history

# #echo "index.html"
# echo "<!DOCTYPE html><meta charset=\"utf-8\"><meta http-equiv=\"refresh\" content=\"0; URL=${S3_WEBSITE_URL}/${INPUT_GITHUB_RUN_NUM}/\">" > ./${INPUT_ALLURE_HISTORY}/index.html # path
# echo "<meta http-equiv=\"Pragma\" content=\"no-cache\"><meta http-equiv=\"Expires\" content=\"0\">" >> ./${INPUT_ALLURE_HISTORY}/index.html
# cat ./${INPUT_ALLURE_HISTORY}/index.html

#cat index-template.html > ./${INPUT_ALLURE_HISTORY}/index.html

#echo "├── <a href="./${INPUT_GITHUB_RUN_NUM}/index.html">Latest Test Results - RUN ID: ${INPUT_GITHUB_RUN_NUM}</a><br>" >> ./${INPUT_ALLURE_HISTORY}/index.html;
#sh -c "aws s3 ls s3://${AWS_S3_BUCKET}" |  grep "PRE" | sed 's/PRE //' | sed 's/.$//' | sort -nr | while read line;
#    do
#        echo "├── <a href="./"${line}"/">RUN ID: "${line}"</a><br>" >> ./${INPUT_ALLURE_HISTORY}/index.html; 
#    done;
#echo "</html>" >> ./${INPUT_ALLURE_HISTORY}/index.html;
# cat ./${INPUT_ALLURE_HISTORY}/index.html


echo "copy allure-results to ${INPUT_ALLURE_HISTORY}/${INPUT_GITHUB_RUN_NUM}"
# delete the history folder from results before copying to history otherwise it will overwrite the history
rm -rf ./${INPUT_ALLURE_RESULTS}/history
cp -R ./${INPUT_ALLURE_RESULTS}/. ./${INPUT_ALLURE_HISTORY}/${INPUT_GITHUB_RUN_NUM}

set -e

if [ -z "$AWS_S3_BUCKET" ]; then
  echo "AWS_S3_BUCKET is not set. Quitting."
  exit 1
fi

if [ -z "$AWS_ACCESS_KEY_ID" ]; then
  echo "AWS_ACCESS_KEY_ID is not set. Quitting."
  exit 1
fi

if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
  echo "AWS_SECRET_ACCESS_KEY is not set. Quitting."
  exit 1
fi

# Default to us-east-1 if AWS_REGION not set.
if [ -z "$AWS_REGION" ]; then
  AWS_REGION="us-east-1"
fi

# Override default AWS endpoint if user sets AWS_S3_ENDPOINT.
if [ -n "$AWS_S3_ENDPOINT" ]; then
  ENDPOINT_APPEND="--endpoint-url $AWS_S3_ENDPOINT"
fi

# Create a dedicated profile for this action to avoid conflicts
# with past/future actions.
# https://github.com/jakejarvis/s3-sync-action/issues/1
aws configure --profile s3-sync-action <<-EOF > /dev/null 2>&1
${AWS_ACCESS_KEY_ID}
${AWS_SECRET_ACCESS_KEY}
${AWS_REGION}
text
EOF

# Sync using our dedicated profile and suppress verbose messages.
# All other flags are optional via the `args:` directive.
sh -c "aws s3 sync ${SOURCE_DIR:-.} s3://${AWS_S3_BUCKET}/${DEST_DIR} \
              --profile s3-sync-action \
              --no-progress \
              ${ENDPOINT_APPEND} $*"

# Sync to the latest folder

sh -c "aws s3 sync ${SOURCE_DIR:-.}/${INPUT_GITHUB_RUN_NUM} s3://${AWS_S3_BUCKET}/${LATEST_URL} \
              --profile s3-sync-action \
              --no-progress \
              ${ENDPOINT_APPEND} $*"

sh -c "aws s3 sync ${SOURCE_DIR:-.}/${INPUT_GITHUB_RUN_NUM} s3://${AWS_S3_BUCKET}/${DEST_DIR} \
	      --profile s3-sync-action \
	      --no-progress \
	      ${ENDPOINT_APPEND} $*"


# Delete history
COUNT=$( sh -c "aws s3 ls s3://${AWS_S3_BUCKET}" | sort -n | grep "PRE" | wc -l )
echo "count folders in allure-history: ${COUNT}"
echo "keep reports count ${INPUT_KEEP_REPORTS}"
INPUT_KEEP_REPORTS=$((INPUT_KEEP_REPORTS+1))
echo "if ${COUNT} > ${INPUT_KEEP_REPORTS}"
if (( COUNT > INPUT_KEEP_REPORTS )); then
  NUMBER_OF_FOLDERS_TO_DELETE=$((${COUNT}-${INPUT_KEEP_REPORTS}))
  echo "remove old reports"
  echo "number of folders to delete ${NUMBER_OF_FOLDERS_TO_DELETE}"
  sh -c "aws s3 ls s3://${AWS_S3_BUCKET}" |  grep "PRE" | sed 's/PRE //' | sed 's/.$//' | head -n ${NUMBER_OF_FOLDERS_TO_DELETE} | sort -n | while read -r line;
    do
      sh -c "aws s3 rm s3://${AWS_S3_BUCKET}/${line}/ --recursive";
      echo "deleted prefix folder : ${line}";
    done;
fi

# Clear out credentials after we're done.
# We need to re-run `aws configure` with bogus input instead of
# deleting ~/.aws in case there are other credentials living there.
# https://forums.aws.amazon.com/thread.jspa?threadID=148833
aws configure --profile s3-sync-action <<-EOF > /dev/null 2>&1
null
null
null
text
EOF
