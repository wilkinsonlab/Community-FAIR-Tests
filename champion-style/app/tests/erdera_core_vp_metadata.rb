class FAIRTest
  def self.erdera_core_vp_metadata_meta
    {
      testversion: HARVESTER_VERSION + ':' + 'Tst-0.0.4',
      testname: 'ERDERA: Minimal VP Metadata for Level 1 Compliance',
      testid: 'erdera_core_vp_metadata',
      description: "The ERDERA Project has strict requirements for minimal metadata to onboard their Virtual Platform.
                            These include: Migration away from deprecated EJP purl properties to the w3id equivalents.
                            Properties, on the resource the GUID identifies: dcat:theme dcat:contactPoint dct:description
                            dcat:keyword dct:language dct:license
                            dct:publisher dct:title dcat:landingPage.
                        It does not test the substructure of the dct:publisher, but it must be a foaf:Agent with a foaf:name.",
      metric: 'https://w3id.org/fair-metrics/erdera/FM_R1-3_M_VP_L1',
      indicators: 'https://w3id.org/fair-metrics/erdera/FM_R1-3_M_VP_L1',
      type: 'http://edamontology.org/operation_2428',
      license: 'https://creativecommons.org/publicdomain/zero/1.0/',
      keywords: ['FAIR Assessment', 'FAIR Principles', 'FAIR', 'R1.3', 'identifier', 'metadata', 'ERDERA',
                 'virtual platform'],
      themes: ['http://edamontology.org/topic_4012'],
      organization: 'ERDERA Project',
      org_url: 'https://erdera.org/',
      responsible_developer: 'Mark D Wilkinson',
      email: 'mark.wilkinson@upm.es',
      response_description: 'The response is "pass", "fail" or "indeterminate"',
      schemas: { 'subject' => ['string', 'the GUID being tested'] },
      organizations: [{ 'name' => 'OSTrails Project', 'url' => 'https://ostrails.eu/' }],
      individuals: [{ 'name' => 'Mark D Wilkinson', 'email' => 'mark.wilkinson@upm.es' }],
      creator: 'https://orcid.org/0000-0001-6960-357X',
      protocol: ENV.fetch('TEST_PROTOCOL', 'https'),
      host: ENV.fetch('TEST_HOST', 'localhost'),
      basePath: ENV.fetch('TEST_PATH', '/community-tests')
    }
  end

  def self.erdera_core_vp_metadata(guid:)
    FtrRuby::Output.clear_comments

    output = FtrRuby::Output.new(
      testedGUID: guid,
      meta: erdera_core_vp_metadata_meta
    )

    output.comments << "INFO: TEST VERSION '#{erdera_core_vp_metadata_meta[:testversion]}'\n"

    # meta = FAIRChampion::MetadataObject.new
    metadata = FAIRChampionHarvester::Core.resolveit(guid) # this is where the magic happens!

    metadata.comments.each do |c|
      output.comments << c
    end
    warn "metadata guidtype #{metadata.guidtype}"
    if metadata.guidtype == 'unknown'
      output.score = 'indeterminate'
      output.comments << "INDETERMINATE: The identifier #{guid} did not match any known identification system.  Testing cannot continue\n"
      return output.createEvaluationResponse
    end

    output.comments << "INFO: Now testing #{guid} for deprecated predicates\n"

    g = metadata.graph
    prefixes = "PREFIX dcat: <http://www.w3.org/ns/dcat#>
    PREFIX dct: <http://purl.org/dc/terms/>
    PREFIX foaf: <http://xmlns.com/foaf/0.1/>
    "

    query = SPARQL.parse("#{prefixes}
    select DISTINCT ?p where {?s ?p ?o . FILTER(CONTAINS(STR(?p), 'purl.archive.org/ejp-rd/'))}")
    results = query.execute(g)
    if results.any?
      output.score = 'fail'
      output.comments << "FAILURE: FDP is still using the deprecated purl predicates\n"
      return output.createEvaluationResponse
    else
      output.comments << "INFO: Didn't see any deprecated predicates.\n"
    end

    # The resource assessed is the one the GUID identifies (the GUID itself, or any URI it
    # resolved to), as the Index assesses each registered resource on its own.
    subjects = erdera_core_vp_metadata_subjects(metadata, guid)
    described = subjects.select { |s| g.has_subject?(RDF::URI(s)) }
    if described.empty?
      output.score = 'indeterminate'
      output.comments << "INDETERMINATE: The harvested metadata does not describe #{subjects.join(' or ')}, " \
                         "so the resource's own metadata cannot be assessed.\n"
      return output.createEvaluationResponse
    end
    output.comments << "INFO: Assessing the metadata of #{described.join(', ')}\n"
    resources = described

    requiredpredicates = %w[dcat:theme dcat:contactPoint dct:description
                            dcat:keyword dct:language dct:license
                            dct:publisher dct:title dcat:contactPoint]

    _specialpredicates = %w[dct:isPartOf]

    # dcat:landingPage was never actually required by the SHACL profile partners were
    # given to build against - demanding it retroactively here would be unfair to
    # publishers who built in good faith against that profile. Recommended, not
    # mandatory, for L1 (Mark Wilkinson's decision, 2026-11-23). Still mandatory for L2
    # DataServices that have no dcat:endpointURL - see erdera_vp_l2_metadata.
    optionalpredicates = %w[foaf:logo dct:issued dct:modified dcat:landingPage]

    resources.each do |d|
      optionalpredicates.each do |p|
        output.comments << "INFO:  Testing #{d} for optional property #{p}.\n"
        query = SPARQL.parse("#{prefixes}
          SELECT ?o WHERE { <#{d}> #{p} ?o }")
        results = query.execute(g)
        if results.any?
          output.comments << "INFO: Found the EJP recommended metadata element #{p} on #{d}\n"
        else
          output.comments << "WARN: the recommended metadata element #{p} could not be found on #{d}\n"
          if p =~ /landingPage/
            output.comments << "WARN: If you are using the Reference FDP, or Sextans Suite, the #{p} " \
                               "property is labelled 'About Page' in the FDP metadata editing pages.\n"
          end
        end
      end
    end

    failflag = false

    resources.each do |d|
      requiredpredicates.uniq.each do |p|
        output.comments << "INFO:  Testing #{d} for mandatory property #{p}.\n"
        query = SPARQL.parse("#{prefixes}
          SELECT ?o WHERE { <#{d}> #{p} ?o }")
        results = query.execute(g)
        if results.any?
          output.comments << "INFO: Found the EJP mandatory metadata element #{p} on #{d}\n"
        else
          output.comments << "WARN: the mandatory metadata element #{p} could not be found on #{d}\n"
          failflag = true
        end
      end
    end
    if failflag
      output.score = 'fail'
      output.comments << "FAILURE: At least one required metadata element is missing\n"
    else
      output.score = 'pass'
      output.comments << "SUCCESS: Found all of the EJP reqired metadata elements\n"
    end
    output.createEvaluationResponse
  end

  # The resource the GUID identifies: the GUID itself and any URI it resolved to.
  def self.erdera_core_vp_metadata_subjects(metadata, guid)
    ([guid] + metadata.finalURI.to_a.map(&:to_s)).map(&:strip).reject(&:empty?).uniq
  end

  def self.erdera_core_vp_metadata_api
    api = FtrRuby::OpenAPI.new(meta: erdera_core_vp_metadata_meta)
    api.get_api
  end

  def self.erdera_core_vp_metadata_about
    # warn "META: #{erdera_core_vp_metadata_meta.inspect}"
    dcat = FtrRuby::DCAT_Record.new(meta: erdera_core_vp_metadata_meta)
    dcat.get_dcat
  end
end
