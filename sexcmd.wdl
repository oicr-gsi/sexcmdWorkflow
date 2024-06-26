version 1.0
workflow sexcmd {
  input {
    File inputFastq
    File inputBam
    String outputFileNamePrefix
  }
  
  call makeStats {
    input: inputBam = inputBam
  }

  call sexcmdReport {
    input: inputFastq = inputFastq
  }

  call estimateAccuracy {
    input: 
      sexcmdReport = sexcmdReport.reportFile,
      bamStatFile  = makeStats.statsFile,
      outputFileNamePrefix = outputFileNamePrefix
  }

  parameter_meta {
    inputFastq: "input fastq file"
    inputBam: "Input alignments in .bam format for the same fastq file"
    outputFileNamePrefix: "Output file prefix"
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
    reportFile: {
        description: "Report generated by the tool",
        vidarr_label: "reportFile"
    }
}
  }
  output {
    File reportFile = estimateAccuracy.reportFile 
    }
  }

# ===================================================================================================================================
# 1. This step runs samtools stats on a bam file with genome-aligned reads from the same fastq file used as an input for sexcmdReport
# ===================================================================================================================================
task makeStats {
  input {
    File inputBam
    Int jobMemory = 6
    Int timeout = 4
    String modules = "samtools/1.14"
    String outputPrefix = "STATREPORT"
  }

  parameter_meta {
    inputBam: "alignment file, such as STAR, BwaMem or other genome-aligned reads"
    modules: "Modules needed to run SEXCMD"
    jobMemory: "Memory (GB) allocated for this job"
    timeout: "Number of hours before task timeout"
    outputPrefix: "Custamizable output file name prefix"
  }

  command <<<
    set -euo pipefail
    samtools stats ~{inputBam} | grep ^SN > "~{outputPrefix}.stats"
  >>>

  runtime {
    modules: "~{modules}"
    memory:  "~{jobMemory} GB"
    timeout: "~{timeout}"
  }

  meta {
    output_meta: {
      statsFile: "Stats generated with samtools stats"
    }
  }

  output {
    File statsFile = "~{outputPrefix}.stats"
  }
} 


# =========================================================================================================================
# 2. Run SEXCMD scripts to generate report. SEXSMD will check alignments for overlap with sex-defining loci and predict sex
# =========================================================================================================================
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


# ===================================================================================================
# 3. Finally, we will use coefficients derived from a linear regression analysis to estimate accuracy
# ===================================================================================================

task estimateAccuracy {
input {
    File sexcmdReport
    File bamStatFile
    String outputFileNamePrefix
    Int minLength = 80
    Int jobMemory = 4
    Int timeout = 4
  }

  parameter_meta {
    sexcmdReport: "Report file generated with SEXCMD, we will append to it"
    bamStatFile: "This is .stats file top few lines (stat with SN) which we use to estimate accuracy of SEXCMD predictions"
    outputFileNamePrefix: "Prefix of the report file to be provisioned"
    minLength: "Hard threshold for minimum length, if average read length is less we have low accuracy (<60%)"
    jobMemory: "Memory (GB) allocated for this job"
    timeout: "Number of hours before task timeout"    
  }

  command <<<
  touch ~{outputFileNamePrefix}.report

  python3 <<CODE
  coefficients = {"unmapped ratio": {"intercept": 0.9346, "slope": -0.3658},
                  "insert size standard deviation:": {"intercept": 0.9068, "slope": -0.0001}}

  def convert_value(value: str):
      try:
          return int(value)
      except ValueError:
          return float(value)
      print(f'Unable to convert [{value}], recording as-is')
      return value

  metrics = {}
  with open("~{bamStatFile}", "r") as samstats:
          data_lines = [line.strip() for line in samstats if line.startswith('SN')]
          for line in data_lines:
              fields = line.split("\t")
              if len(fields) >= 3:
                  metrics[fields[1]] = convert_value(fields[2])

  if "reads unmapped:" in metrics.keys() and "sequences:" in metrics.keys() and metrics["sequences:"] > 0:
      metrics["unmapped ratio"] = round(metrics["reads unmapped:"]/metrics["sequences:"], 3)

  accuracy = 1.0
  if "average length:" in metrics.keys() and metrics["average length:"] <= ~{minLength}:
      accuracy = 0
  else:
      for c in coefficients.keys():
          if c in metrics.keys():
              estimated = coefficients[c]["intercept"] + metrics[c]*coefficients[c]["slope"]
              if estimated < accuracy:
                  accuracy = round(estimated, 3)

  with open("~{sexcmdReport}", "r") as sexinfo:
      infolines = [line for line in sexinfo]

  if not infolines[-1].strip().endswith("UNDEFINED"):
      if accuracy > 0:
          infolines.append(f'Estimated Accuracy is ~ {accuracy*100}%\n')
      else:
          infolines.append("Estimated Accuracy is < 60%\n")

  with open("~{outputFileNamePrefix}.report", "w") as out:
      out.writelines(infolines)
  CODE
  >>>

  runtime {
    memory:  "~{jobMemory} GB"
    timeout: "~{timeout}"
  }

  meta {
    output_meta: {
      reportFile: "Report File generated by SEXCMD"
    }
  }

  output {
    File reportFile = "~{outputFileNamePrefix}.report"
  }
}
