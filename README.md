# sexcmd

SEXCMD workflow relies on sex-specific markers to determine the sex of the analyzed sample. Forked from SEXCMD repo by Seongmun Jeong

## Dependencies

* [samtools 1.9](https://github.com/samtools/samtools)
* [bwa 0.7.17](https://github.com/lh3/bwa/archive/0.7.17.tar.gz)
* [sexcmd 1.0](https://github.com//oicr-gsi/SEXCMD.git)
* [rstats 4.0](https://www.r-project.org/)
* [python 2.7](https://www.python.org/)


## Usage

### Cromwell
```
java -jar cromwell.jar run sexcmd.wdl --inputs inputs.json
```

### Inputs

#### Required workflow parameters:
Parameter|Value|Description
---|---|---
`inputFastq`|File|input fastq file
`sexcmdReport.sequencingType`|Int|1:Whole Exome Seq, 2:RNA-Seq, 3:Whole Genome Seq


#### Optional task parameters:
Parameter|Value|Default|Description
---|---|---|---
`sexcmdReport.referenceFasta`|String|"$HG38_SEXCMD_RES_ROOT/sex_marker_filtered.hg38.final.fasta"|Marker reference file, comes from a resource module
`sexcmdReport.outputFilePrefix`|String|"SEXCMD"|Prefix of the report file to be provisioned
`sexcmdReport.sexModelType`|String|"XY"|Sex determination system type : XY or ZW
`sexcmdReport.jobMemory`|Int|10|Memory (GB) allocated for this job
`sexcmdReport.timeout`|Int|4|Number of hours before task timeout
`sexcmdReport.modules`|String|"hg38-sexcmd-res/1.0 sexcmd/1.0"|Modules needed to run SEXCMD


### Outputs

Output | Type | Description
---|---|---
`reportFile`|File|Report generated by the tool


## Commands
This section lists command(s) run by WORKFLOW workflow
 
* Running SEXCMD workflow
 
The workflow accepts a single fastq file which may be any of R1 or R2 files for paired reads sequencing.
In a case when the workflow fails to find enough information to deduce the sex of the donor
it will still generate a report which would say that sex is UNDEFINED
 
### Generate report
 
```
 
   touch PREFIX.OUTPUT
   Rscript  SEXCMD.R 
           -m REFERENCE_FASTA
           -t SEQUENCING_TYPE
           -s SEX_MODEL
           -f INPUT_FASTQ
           -p OUTPUT_PREFIX
 
   python3 snippet:
 
   outputFile = "PREFIX.OUTPUT"
   reportString = "Sex_Determination\tRatio of X and Y counts is NA\tSex of this sample BASENAME_OF_FASTQ is UNDEFINED\n"
   numberOfLines = 0
 
   with open(outputFile, "r") as inp:
       numberOfLines = len(inp.readlines())
   inp.close()
 
   if numberOfLines == 0:
       """Write down the string"""
       with open(outputFile, "w") as m:
           m.writelines(reportString)
       m.close()
 
 
```
## Support

For support, please file an issue on the [Github project](https://github.com/oicr-gsi) or send an email to gsi@oicr.on.ca .

_Generated with generate-markdown-readme (https://github.com/oicr-gsi/gsi-wdl-tools/)_
