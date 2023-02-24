version 1.0
workflow sexcmd {
  input {
    File inputFastq
  }
  
  call sexcmdReport {
    input: inputFastq = inputFastq
  }  

  parameter_meta {
    inputFastq: "input fastq file"
  }

  meta {
    author: "Peter Ruzanov"
    email: "pruzanov@oicr.on.ca"
    description: "SEXCMD workflow relies on sex-specific markers to determine the sex of the analyzed sample. Forked from SEXCMD repo by Seongmun Jeong"
    dependencies: 
    [
      {
      name: "samtools/1.9",
      url: "https://github.com/samtools/samtools"
      },
      {
      name: "bwa/0.7.17",
      url: "https://github.com/lh3/bwa/archive/0.7.17.tar.gz"
      },
      {
      name: "sexcmd/1.0",
      url: "https://github.com//oicr-gsi/SEXCMD.git"
      },
      {
      name: "rstats/4.0",
      url: "https://www.r-project.org/"
      },
      {
      name: "python/2.7",
      url: "https://www.python.org/"
      }
    ]
    output_meta: {
       reportFile: "Report generated by the tool"
    }
  }
  output {
    File reportFile = sexcmdReport.reportFile 
    }
  }


task sexcmdReport {
  input {
    File inputFastq
    String referenceFasta = "$HG38_SEXCMD_RES_ROOT/sex_marker_filtered.hg38.final.fasta"
    Int sequencingType
    String outputFilePrefix = "SEXCMD"
    String sexModelType = "XY"
    Int jobMemory = 10
    Int timeout = 4  
    String modules = "hg38-sexcmd-res/1.0 sexcmd/1.0"
  }

  parameter_meta {
    inputFastq: "gzip-ed fastq file containing reads"
    referenceFasta: "Marker reference file, comes from a resource module"
    sequencingType: "1:Whole Exome Seq, 2:RNA-Seq, 3:Whole Genome Seq"
    outputFilePrefix: "Prefix of the report file to be provisioned"
    sexModelType: "Sex determination system type : XY or ZW"
    modules: "Modules needed to run SEXCMD"
    jobMemory: "Memory (GB) allocated for this job"
    timeout: "Number of hours before task timeout"
  }

  command <<<
  touch ~{outputFilePrefix}.OUTPUT
  Rscript  $SEXCMD_ROOT/SEXCMD.R \
          -m ~{referenceFasta} \
          -t ~{sequencingType} \
          -s ~{sexModelType} \
          -f ~{inputFastq} \
          -p ~{outputFilePrefix}

  python3 <<CODE
  outputFile = "~{outputFilePrefix}.OUTPUT"
  reportString = "Sex_Determination\tRatio of X and Y counts is NA\tSex of this sample ~{basename(inputFastq)} is UNDEFINED\n"
  numberOfLines = 0

  with open(outputFile, "r") as inp:
      numberOfLines = len(inp.readlines())
  inp.close()

  if numberOfLines == 0:
      """Write down the string"""
      with open(outputFile, "w") as m:
          m.writelines(reportString)
      m.close()

  CODE
  >>>

  runtime {
    modules: "~{modules}"
    memory:  "~{jobMemory} GB"
    timeout: "~{timeout}"
    continueOnReturnCode: [0, 1]
  }

  meta {
    output_meta: {
      reportFile: "Report File generated by SEXCMD"
    }
  }

  output {
    File reportFile = "~{outputFilePrefix}.OUTPUT"
  }

}

