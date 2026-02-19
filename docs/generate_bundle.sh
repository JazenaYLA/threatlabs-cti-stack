#!/bin/bash

# Script to regenerate docs/llm_context_bundle.md

BUNDLE="docs/llm_context_bundle.md"

echo "# ThreatLabs CTI Project Context Bundle" > $BUNDLE
echo "" >> $BUNDLE

echo "## 1. The Narrative Arc: Pitfalls & Discoveries (Start Here)" >> $BUNDLE
cat docs/Narrative-Arc.md >> $BUNDLE
echo "" >> $BUNDLE
echo "---" >> $BUNDLE
echo "" >> $BUNDLE

echo "## 2. Project Overview (README.md)" >> $BUNDLE
cat README.md >> $BUNDLE
echo "" >> $BUNDLE
echo "---" >> $BUNDLE
echo "" >> $BUNDLE

echo "## 3. Project Timeline & Story" >> $BUNDLE
cat docs/Project-Timeline.md >> $BUNDLE
echo "" >> $BUNDLE
echo "---" >> $BUNDLE
echo "" >> $BUNDLE

echo "## 4. Architecture & Decisions" >> $BUNDLE
cat docs/Architecture.md >> $BUNDLE
echo "" >> $BUNDLE
echo "---" >> $BUNDLE
echo "" >> $BUNDLE

echo "## 5. Troubleshooting & Challenges" >> $BUNDLE
cat docs/Troubleshooting.md >> $BUNDLE
echo "" >> $BUNDLE
echo "---" >> $BUNDLE
echo "" >> $BUNDLE

echo "## 6. Global Changelog" >> $BUNDLE
cat docs/Changelog.md >> $BUNDLE
echo "" >> $BUNDLE
echo "---" >> $BUNDLE
echo "" >> $BUNDLE

echo "Bundle regenerated at $(date)"
