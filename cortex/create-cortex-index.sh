#!/bin/bash
docker run --rm --network=cti-net curlimages/curl \
  -X PUT 'http://es8-cti:9200/cortex' \
  -H 'Content-Type: application/json' \
  -d '{"mappings":{"properties":{"name":{"type":"keyword"},"description":{"type":"text"},"dockerImage":{"type":"keyword"},"dockerVersion":{"type":"keyword"},"dataType":{"type":"keyword"},"tlp":{"type":"float"},"pap":{"type":"float"}}}}'
