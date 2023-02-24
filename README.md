
Very simple code to extract pQTL results, usage
 ```
 bash extract-pQTL.sh {somascan, olink, decode} probs_{somascan, olink, decode}.txt $YOUR_REGEION $outputDir
 or the same in parallel with error checking
 extract-pQTL_paral.sh {somascan, olink, decode} probs_{somascan, olink, decode}.txt $YOUR_REGEION $outputDir
 ```

YOUR\_REGION is a text format with each line the region interested "CHR POSstart POSend"

outputDir will be created automatically. The files are headers.txt (headers for all summary), ${probe\_name}.txt (summary of the probe)

The probs_\*.txt could be divided into smaller files for parallel.  



