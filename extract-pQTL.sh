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

mkdir -p "$outDir"

inputSource=""
if [ $platform = "somascan" ]; then
    inputSource="gs://zz-red/Omics/Proteomics/Soma2/pQTL-compress/SomaScan_Batch2"
elif [ $platform = "olink" ]; then
    inputSource="gs://zz-red/Omics/Proteomics/Olink/pQTL-compress/Olink_Batch1"
elif [ $platform = "decode" ]; then
    inputSource="gs://zz-red/Omics/Proteomics/deCODE/pQTL/deCODE"
else
    echo "the first parameter could only be: somasan or olink"
    exit 1
fi

export GCS_OAUTH_TOKEN=`gcloud auth print-access-token`
readarray -t traits < $probList

gsutil cat ${inputSource}_${traits[0]}.txt.gz | zcat | head -n 1 > $outDir/headers

N=${#traits[@]}
echo "Start to extract $N probes"
template=$region
i=0
for trait in "${traits[@]}"; do
    ((i=i+1))
    if [ ! -f "$outDir/$trait.txt" ] || [ ! -s "$outDir/$trait.txt" ]; then
        echo "$i/$N: $trait"

        gsfile="${inputSource}_${trait}.txt.gz"
        gsutil -q stat $gsfile
        if [ $? -ne 0 ]; then
            echo "  error: $gsfile doesn't exist, skipped"
            continue
        fi

        gsutil -q stat "$gsfile.tbi"
        if [ $? -ne 0 ]; then
            echo "  error: $gsfile.tbi doesn't exist, skipped"
            continue
        fi

        while true; do
            tabix -R $template $gsfile > $outDir/$trait.txt
            if [ $? -eq 0 ]; then
                break
            else
                echo "  error: re-run..."
                export GCS_OAUTH_TOKEN=`gcloud auth print-access-token`
            fi
        done
    else
        echo "$i: $trait exists"
    fi
done

