#!/bin/bash

# 1. Delete the incorrect 'cortex' index if it exists (fresh setup assumption)
docker run --rm --network=cti-net curlimages/curl -X DELETE 'http://es8-cti:9200/cortex' >/dev/null 2>&1

# 2. Create the specific versioned index 'cortex_6'
docker run --rm --network=cti-net curlimages/curl \
  -X PUT 'http://es8-cti:9200/cortex_6' \
  -H 'Content-Type: application/json' \
  -d '{"mappings":{"properties":{"name":{"type":"keyword"},"description":{"type":"text"},"dockerImage":{"type":"keyword"},"dockerVersion":{"type":"keyword"},"dataType":{"type":"keyword"},"tlp":{"type":"float"},"pap":{"type":"float"}}}}'

# 3. Create the alias 'cortex' pointing to 'cortex_6'
docker run --rm --network=cti-net curlimages/curl \
  -X POST 'http://es8-cti:9200/_aliases' \
  -H 'Content-Type: application/json' \
  -d '{"actions":[{"add":{"index":"cortex_6","alias":"cortex"}}]}'
