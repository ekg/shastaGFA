#!/bin/bash

input=$1 # input GFA
cov_min=$2 # default 2
unitig_extend=$3  # 25000
unitig_min_begin=$4 # 100
reference=$5 # hg38.fa
minimap2_threads=$6 # number of system cores for minimap2 to use

base=$(basename $input .gfa)

# dependencies
#gimbricate=~/gimbricate/bin/gimbricate
#vg=~/vg/bin/vg
#odgi=~/odgi/bin/odgi
#minimap2=~/minimap2/minimap2
#paftools=~/minimap2/misc/paftools.js # needs k8 in path

# recompute GFA overlaps and remove low-coverage nodes, then bluntify with vg
gimbricate -g $input -c $cov_min | vg view -F - >$base.blunt.gfa
# build and sort the graph in odgi format
odgi build -g $base.blunt.gfa -s -o $base.og
# extract unitigs from the graph and sort the resulting
odgi unitig -i $base.og -l $unitig_min_begin -p $unitig_extend -f \
    | paste - - - - \
    | perl -ne '@x=split m/\t/; unshift @x, length($x[1]); print join "\t",@x;' \
    | sort -nr \
    | cut -f2- | tr "\t" "\n" | pigz >$base.unitig.fq.gz
# map the unitigs back to the reference and extract variants from them
minimap2 -t $minimap2_threads -r 25000 -c --cs $reference $base.unitig.fq.gz \
    | sort -k6,6 -k8,8n \
    | paftools.js call - >$base.paftools.vcf
