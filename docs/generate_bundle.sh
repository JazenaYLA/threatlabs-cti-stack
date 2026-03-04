#!/bin/bash
# Script to regenerate docs/llm_context_bundle.md
BUNDLE="/tmp/llm_context_bundle.md"
echo "Generating context bundle to $BUNDLE..."
echo "# ThreatLabs CTI Project Context Bundle" > $BUNDLE
echo "" >> $BUNDLE
echo "## 1. Project Overview (README.md)" >> $BUNDLE
cat README.md >> $BUNDLE
echo "" >> $BUNDLE
echo "---" >> $BUNDLE
echo "## 2. Architecture & Decisions" >> $BUNDLE
cat docs/Architecture.md >> $BUNDLE
echo "" >> $BUNDLE
echo "---" >> $BUNDLE
echo "## 3. Troubleshooting & Challenges" >> $BUNDLE
cat docs/Troubleshooting.md >> $BUNDLE
echo "" >> $BUNDLE
echo "---" >> $BUNDLE
