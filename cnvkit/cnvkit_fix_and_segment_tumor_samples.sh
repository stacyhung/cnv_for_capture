#!/bin/bash

# This script reads in file (e.g. tumors.txt),
# and for each line (a sample id), applies the cnvkit "fix" function
# for the sample using <sample>.targetcoverage.cnn and <sample>.antitargetcoverage.cnn
# along with the pooled normal reference, Reference.cnn
#
# Output: A table of copy number ratios (.cnr)

# How to run this script: from the project folder, ./scripts/cnvkit_fix_samples.sh samples.txt

while IFS='' read -r line || [[ -n "$line" ]]; do
    echo "To apply cnvkit fix for sample: $line"
    /Users/shung/Downloads/cnvkit-0.9.1/cnvkit.py fix coverage/autobin/tumors/$line.targetcoverage.cnn coverage/autobin/tumors/$line.antitargetcoverage.cnn Reference.cnn -o $line.cnr
    /Users/shung/Downloads/cnvkit-0.9.1/cnvkit.py segment $line.cnr -o $line.cns
done < "$1"

