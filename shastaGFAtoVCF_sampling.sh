#!/bin/bash

input=$1
cov_min=$2
sim_read_count=$3
sim_read_length=$4
reference=$5
base=$(basename $input .gfa)

gimbricate -g $input -c $cov_min | vg view -Fv - | vg sort - >$base.vg
vg index -x $base.xg $base.vg
vg sim -n $sim_read_count -l $sim_read_length -x $base.xg | awk '{ print ">"NR; print $0; }' \
    | pv -c | pv -lc | fasta_to_fastq.pl /dev/stdin | pigz >$base.sim.fq.gz
minimap2 -t 4 -ca -x asm20 -r 10000 $reference $base.sim.fq.gz >$base.sim.sam
samtools view -b $base.sim.sam >$base.sim.raw.bam
samtools sort $base.sim.raw.bam >$base.sim.bam
samtools index $base.sim.bam
rm -f $base.sim.sam $base.sim.raw.bam
freebayes -f $reference $base.sim.bam >$base.sim.vcf
bgzip $base.sim.vcf.gz
tabix -p vcf $base.sim.vcf.gz
