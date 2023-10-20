process CNVkitPaired {

 tag "$meta.lib"
    publishDir "${params.resultsdir}/${meta.id}/${meta.casename}/${meta.lib}/cnvkit", mode: "${params.publishDirMode}"

    input:
    tuple val(meta),path(Tbam),path(Tindex),path(Tbed)
    tuple val(meta2),path(Nbam),path(Nindex)
    path cnv_ref_access
    path genome
    path genome_fai
    path genome_dict

    output:
    tuple val(meta),path("${meta.lib}.cns"), emit: cnvkit_cns
    tuple val(meta),path("${meta.lib}.cnr"), emit: cnvkit_cnr
    tuple val(meta),path("${meta.lib}.pdf"), emit: cnvkit_pdf
    path "versions.yml"             , emit: versions

    stub:
     """
     touch "${meta.lib}.cns"
     touch "${meta.lib}.cnr"
     touch "${meta.lib}.pdf"

     """
    script:
     def prefix = task.ext.prefix ?: "${meta.lib}"
    """
    cnvkit.py batch -p ${task.cpus} --access ${cnv_ref_access} --fasta ${genome} --targets ${Tbed} ${Tbam} --output-dir . --normal ${Nbam}
    mv ${prefix}.final.cns ${prefix}.cns
    mv ${prefix}.final.cnr ${prefix}.cnr
    cnvkit.py scatter -s ${prefix}.cn{s,r} -o ${prefix}.pdf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        cnvkit: \$(cnvkit.py batch 2>&1  |grep -E '^CNVkit'|sed 's/CNVkit //')
    END_VERSIONS


    """
}
