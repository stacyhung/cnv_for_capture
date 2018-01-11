#!/bin/bash

# This script is for the PMBCL exomes project, specifically dealing with copy number calling using cnvkit
# Date: January 9, 2018
# Author: Stacy Hung <shung@bccrc.ca>

cd /Volumes/shung/projects/PMBCL_exomes/cnvkit

# Step 1. Create BED files for targets and "antitargets"
cnvkit target baits.bed --annotate refFlat.txt --split -o targets.bed			# annotate target regions with gene names
cnvkit antitarget targets.bed -g access-5kb-mappable.hg19.bed -o antitargets.bed	# "access" file precomputed for UCSC hg19


# Step 2. Estimate reasonable on- and off-target bin sizes - if multiple bams, use the BAM with median size
# from our 116 bam files, the median file size is 6.8 GB (e.g. PA007.bam)
cnvkit autobin bam/PA007.bam -t baits.bed -g access-5kb-mappable.hg19.bed --annotate refFlat.txt

# the output of this command generates baits.targets.bed and baits.antitargets.bed 
# (that presumably has average bin size closer to the recommended bin size)
# Based on PA007.bam, recommended bin size: 690 bp (@145X) [on-target] and 170424 bp (@0.6X) [off-target]

# Step 3. Calculate target and antitarget coverage for all samples
# 3A. calculate coverage for tumor samples (for the "fix" step)
./scripts/get_cnvkit_coverage_for_bams.sh tumors.txt

# 3B. calculate coverage for normal samples (to be used to create a pooled normal)
./scripts/get_cnvkit_coverage_for_bams.sh normals.txt

# Step 4. Create a reference by pooling coverage files for normals (recommended)
# 	  The -f option allows use of a reference genome to calculate GC content 
# 	  and the repeat-masked proportion of each region
# http://cnvkit.readthedocs.io/en/latest/pipeline.html#how-it-works
cnvkit reference *coverage.cnn -f ucsc.hg19.fa -o Reference.cnn

# Step 5. "Fix" - combine the uncorrected target and antitarget coverage tables (.cnn) and
# 	  correct for biases in regional coverage and GC content, according to the given reference.
# 	  Output: table of copy number ratios (.cnr)
# For each tumor sample...
./scripts/cnvkit_fix_tumor_samples.sh tumors.txt


# ######################################################
# QC: Calculate spread of bin-level copy ratios from corresponding final
# 	segments using several statistics.  These statistics help quantify
# 	how "noisy" a sample is, and can help:
# 	(1) decide which samples to exclude from an analysis OR
# 	(2) to select normal samples for a reference copy numnber profile
# ######################################################

# for a single sample:
cnvkit metrics sample.cnr -s sample.cns

# or multiple samples can be processed together to produce a table:
cnvkit metrics *.cnr -s *.cns

# so that we can find noisy tumor samples in our pmbcl exome dataset:
./scripts/get_cnvkit_coverage_for_bams.sh tumors.txt # IN PROGRESS (for first 53 tumors)
./scripts/cnvkit_fix_tumor_samples.sh tumors.txt
cnvkit metrics cnvkit_fix/tumors/*cnr -s *.cns

# so that we can select the best normals to include in our pooled reference:
./scripts/cnvkit_fix_tumor_samples.sh normals.txt
cnvkit metrics cnvkit_fix/normals/*cnr -s *.cns

############### Example commands ############## 

# Quick start - run batch command (i.e. run cnvkit on 1 or more bam files):

# Note that the --access parameter is optional (bed file of sequencing-accessible regions) OR use those provided by cnvkit (in data directory)
 cnvkit.py batch *Tumor.bam --normal *Normal.bam \
     --targets my_baits.bed --fasta hg19.fasta \
     --access data/access-5kb-mappable.hg19.bed \
     --output-reference my_reference.cnn --output-dir example/

# Process each of the BAM files in parallel, as separate subprocesses:
cnvkit.py batch *.bam -r my_reference.cnn -p 8

# From baits and tumor/normal BAMs
cnvkit.py batch *Tumor.bam --normal *Normal.bam \
   	--targets my_baits.bed --annotate refFlat.txt \
        --fasta hg19.fasta --access data/access-5kb-mappable.hg19.bed \
        --output-reference my_reference.cnn --output-dir results/ \
        --diagram --scatter

# Reusing a reference for additional samples
cnvkit.py batch *Tumor.bam -r Reference.cnn -d results/

# Reusing targets and antitargets to build a new reference, but no analysis
cnvkit.py batch -n *Normal.bam --output-reference new_reference.cnn \
     -t my_targets.bed -a my_antitargets.bed --male-reference \
     -f hg19.fasta -g data/access-5kb-mappable.hg19.bed

