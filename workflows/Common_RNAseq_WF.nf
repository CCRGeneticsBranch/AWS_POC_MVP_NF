

//import modules
include {Cutadapt} from '../modules/cutadapt/cutadapt'
include {Fastqc} from '../modules/qc/qc'
include {Fastq_screen} from '../modules/qc/qc'
include {Multiqc} from '../modules/qc/qc'
include {Mixcr_VCJtools} from '../modules/misc/mixcr'
include {Allstepscomplete} from '../modules/misc/Allstepscomplete'

// import subworkflows

include {HLA_calls} from '../subworkflows/hla_calls'
include {Star_RSEM} from '../subworkflows/Star_RSEM'
include {Fusion_calling} from '../subworkflows/Fusion_calling'
include {Star_bam_processing} from '../subworkflows/Star_bam_processing'
include {RNAseq_GATK} from '../subworkflows/RNAseq_GATK'
include {QC_from_finalBAM} from '../subworkflows/QC_from_finalBAM'
//include {Annotation} from '../subworkflows/Annotation'
include {QC_from_Star_bam} from '../subworkflows/QC_from_Star_bam'


workflow Common_RNAseq_WF {
  

take: 
     samples_rnaseq_ch

main: 

Cutadapt(samples_rnaseq_ch)


//samples_rnaseq.view()


fastqc_input = Cutadapt.out.trim_reads.join(samples_rnaseq_ch, by:[0])


  Fastqc(fastqc_input)
  fastq_screen_config         = Channel.of(file(params.fastq_screen_config, checkIfExists:true))
  //fqs_human =   Channel.of(file(params.fqs_human, checkIfExists:true))
  //Fastq_screen_input = Cutadapt.out.trim_reads.combine(fastq_screen_config).combine(fqs_human)
  //Fastq_screen_input.view()
  //Fastq_screen(Fastq_screen_input)
   
  
 
  Star_RSEM(Cutadapt.out.trim_reads) 

  starfusion_db           = Channel.of(file(params.starfusion_db, checkIfExists:true))
  Starfusion_input = Star_RSEM.out.chimeric_junction.combine(starfusion_db)


  Fusion_calling (
         Cutadapt.out,
         Starfusion_input
     )

  PicardARG_input = Star_RSEM.out.genome_bam.combine(Star_RSEM.out.genome_bai,by:[0])
  
  
  Star_bam_processing(
      PicardARG_input,
      Star_RSEM.out.strandedness,
      Fastqc.out
  )

HLA_calls(Cutadapt.out) 


//Star_bam_processing.out.rnalib_custom_qc.view()
Star_bam_processing.out.rnalib_custom_qc.map { meta, file ->
    new_meta = [
        id: meta.id,
        case: meta.case,
        type: meta.type
    ]
    [ new_meta, file ]
  }.groupTuple()
   .map { meta, files -> [ meta, *files ] }
   .filter { tuple ->
    tuple.size() > 2
  }
   .set { combinedChannel }


//combinedChannel.view()


  QC_from_Star_bam(
      Star_bam_processing.out.picard_ARG,
      Star_bam_processing.out.picard_MD
  )

  RNAseq_GATK(Star_bam_processing.out.picard_MD)

  capture_ch = RNAseq_GATK.out.GATK_RNAseq_bam
    .map { tuple ->
        def meta = tuple[0]
        def bam = tuple[1]
        def bai = tuple[2]
        def target_file = ''
        
        if (meta.sc == 'access') {
            target_file = params.access_target
        } else if (meta.sc == 'polya_stranded') {
            target_file = params.polya_stranded_target
        } else if (meta.sc == 'polya') {
            target_file = params.polya_target
        } else if (meta.sc == 'ribozero') {
            target_file = params.ribozero_target
        } else if (meta.sc == 'SmartRNA') {
            target_file = params.smartrna_target
        }

        return [meta,target_file]
    }



  QC_from_finalBAM(
      RNAseq_GATK.out.GATK_RNAseq_bam,
      capture_ch
  )
  emit:
  Fastqc_out = Fastqc.out
  coverageplot = QC_from_finalBAM.out.coverageplot
  pileup = QC_from_finalBAM.out.hotspot_pileup
  snpeff_vcf = RNAseq_GATK.out.SnpEff_vcf
  chimeric_junction = Star_RSEM.out.chimeric_junction
  rsem_counts = Star_RSEM.out.rsem
  rnaseqc = QC_from_Star_bam.out.rnaseqc
  circos_plot = QC_from_Star_bam.out.circos
  fusion_calls = Fusion_calling.out.merge_fusion
  rnalib_custum_qc = Star_bam_processing.out.rnalib_custom_qc
  picard_rnaseqmetrics = Star_bam_processing.out.picard_rnaseqmetrics
  loh = QC_from_Star_bam.out.loh
}

/*
workflow Common_Annotation {

  Annotation(
      QC_from_finalBAM.out.hotspot_pileup,
      RNAseq_GATK.out.SnpEff_vcf
)
}


multiqc_input = Fastqc.out.join(QC_from_finalBAM.out.hotspot_pileup, by: [0])
                          .join(QC_from_finalBAM.out.coverageplot, by: [0])
                          .join(Star_rsem.out.chimeric_junction, by: [0])
                          .join(Star_rsem.out.rsem, by: [0]).join(QC_from_Star_bam.out.rnaseqc, by: [0])
                          .join(QC_from_Star_bam.out.circos, by: [0])
Multiqc(multiqc_input)

final_inputs = Fusion_calling.out.merge_fusion.join(Annotation.out.final_annotation,by:[0]).join(Multiqc.out,by:[0])

Allstepscomplete(final_inputs)

//}
*/



