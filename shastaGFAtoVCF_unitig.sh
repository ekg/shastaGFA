#!/bin/bash

input=$1
cov_min=$2
unitig_extend=$3
reference=$4
min_variant_size=$5
minimap2_threads=$6
base=$(basename $input .gfa)

# dependencies
#gimbricate=~/gimbricate/bin/gimbricate
#odgi=~/odgi/bin/odgi
#freebayes=~/freebayes/bin/freebayes
#bamslicebed=~/jvarkit/dist/bamslicebed.jar
#samtools=$(which samtools)
#minimap2=~/minimap2/minimap2
#paftools=~/minimap2/misc/paftools.js # needs k8 in path

gimbricate -g $input -c $cov_min | vg view -F - >$base.blunt.gfa
odgi build -g $base.blunt.gfa -s -o $base.og
odgi unitig -i $base.og -p $unitig_extend \
    | minimap2 -t $minimap2_threads -c --cs $reference /dev/stdin \
    | sort -k6,6 -k8,8n \
    | paftools.js call - >$base.paftools.vcf
<$base.paftools.vcf awk 'function abs(v) {return v < 0 ? -v : v} /^V/ && abs(length($7) - length($8)) >100 { x=abs(length($7) - length($8)); print $2, $3-x, $4+x }' | tr ' ' '\t' >$base.sv.bed
odgi unitig -i $base.og -p $unitig_extend -f \
    | minimap2 -t $minimap2_threads -c -a $reference /dev/stdin \
    | samtools view -b - >$base.unitigs.raw.bam
samtools sort $base.unitigs.raw.bam >$base.unitigs.bam
rm -f $base.unitigs.raw.bam
samtools index $base.unitigs.bam
java -jar ~/jvarkit/dist/bamslicebed.jar -B $base.sv.bed $base.unitigs.bam | samtools view -b - >$base.unitigs.sv.slice.raw.bam
samtools sort $base.unitigs.sv.slice.raw.bam >$base.unitigs.sv.slice.bam
rm -f $base.unitigs.sv.slice.raw.bam
samtools index $base.unitigs.sv.slice.bam
freebayes -C 1 -F 0 -f $reference $base.unitigs.sv.slice.bam >$base.freebayes.sv.vcf
