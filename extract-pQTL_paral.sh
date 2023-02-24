#!/bin/bash -
#===============================================================================
#
#          FILE: extractProteomics.sh
#
#         USAGE: ./extract.sh
#
#   DESCRIPTION: 
#
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Zhili
#  ORGANIZATION: 
#       CREATED: 02/14/23 03:39:12
#      REVISION:  ---
#===============================================================================

set -o nounset                                  # Treat unset variables as an error

platform=$1
probList=$2

region=$3

outDir=$4

n_parallels=24

mkdir -p "$outDir"

inputSource=""
if [ $platform = "somascan" ]; then
    inputSource="gs://zz-red/Omics/Proteomics/Soma2/pQTL-compress/SomaScan_Batch2"
elif [ $platform = "olink" ]; then
    inputSource="gs://zz-red/Omics/Proteomics/Olink/pQTL-compress/Olink_Batch1"
else
    echo "the first parameter could only be: somasan or olink"
    exit 1
fi

export GCS_OAUTH_TOKEN=`gcloud auth print-access-token`
readarray -t traits < $probList

gsutil cat ${inputSource}_${traits[0]}.txt.gz | zcat | head -n 1 > $outDir/header

echo "Start to extract ${#traits[@]} probes"
template=$region
i=0

commandfile=$outDir"/commands"
rm $commandfile 2>>"dev/null"

force_rerun=1

for trait in "${traits[@]}"; do
    ((i=i+1))
    if [ $force_rerun -eq 1 ] || [ ! -f "$outDir/$trait.txt" ] || [ ! -s "$outDir/$trait.txt" ]; then
        echo "$i: $trait"
	echo  "tabix -D -R $template ${inputSource}_${trait}.txt.gz > $outDir/$trait.txt" >> $commandfile
    else
        echo "$i: $trait exists"
    fi
done

n_to_fetch=$((wc -l $commandfile 2>>"/dev/null"|| echo 0) | cut -f 1 -d" ")

if [ "$n_to_fetch" -gt 0 ] 
then
	echo "Starting to fetch data for $n_to_fetch proteins"
	parallel --progress -a $commandfile --jobs $n_parallels --joblog $outDir/joblog --retries 5
	failed_jobs=$?
	if [ $failed_jobs -gt 0 ] 
	then
		echo "Fetching data failed for $failed_jobs. Rerunning failed jobs once. In case of failures run parallel -a $commandfile --jobs $n_parallels --resume_failed --joblog $outDir/joblog"
		parallel --progress -a $commandfile --jobs $n_parallels --resume-failed --joblog $outDir/joblog
		failed_jobs=$?
	fi

	if [ $failed_jobs -gt 0 ]
	then
		echo "Sigh..... again $failed_jobs failed. Re-run as many times as necessaary: parallel -a $commandfile --jobs $n_parallels --resume_failed --joblog $outDir/joblog"
	else
		echo "combining results and creating tabix...."
		cat <(awk ' BEGIN{OFS="\t"} { print "#PHENO",$0}' $outDir/header) <(find $outDir/*.txt| while read f; do pheno=$(basename $f | sed 's/.txt//g'); awk -v pheno=$pheno ' BEGIN{FS=OFS="\t"} { print pheno,$0 }' $f; done | sort -g -k 2,2 -k 3,3)|bgzip > $outDir/all_data.gz
		tabix -s 2 -b 3 -e 3 $outDir/all_data.gz
	fi
else 
	echo "All results already fetched.... checking if all files have the same number of rows!"
	set +o nounset
	find $outDir/*.txt | while read f; do lines=$(wc -l $f | cut -f1 -d" ");  if [ -n "$prev" ] && [  $lines -ne $prev ]; then echo "All results don't have the same number of rows. Is this error??? This file differs from previous"$f; fi; prev=$lines;  done

fi




