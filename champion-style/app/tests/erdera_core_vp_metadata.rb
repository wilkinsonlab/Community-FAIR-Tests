class FAIRTest
  def self.erdera_core_vp_metadata_meta
    {
      testversion: HARVESTER_VERSION + ':' + 'Tst-0.0.2',
      testname: 'ERDERA: Minimal VP Metadata for Level 1 Compliance',
      testid: 'erdera_core_vp_metadata',
      description: "The ERDERA Project has strict requirements for minimal metadata to onboard their Virtual Platform.
                            These include: Migration away from deprecated EJP purl properties to the w3id equivalents.  Presence of the VPDiscoverable prpoperty. Properties: dcat:theme dcat:contactPoint dct:description
                            dcat:keyword dct:language dct:license
                            dct:publisher dct:title dcat:contactPoint dcat:landingPage.
                        It does not test the substructure of the dct:publisher, but it must be a foaf:Agent with a foaf:name.",
      metric: 'https://w3id.org/fair-metrics/erdera/FM_R1-3_M_VP_L1',
      indicators: 'https://fairsharing.org/FAIRsharing.87d197',
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
    PREFIX ejp: <https://w3id.org/ejp-rd/vocabulary#>
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

    # test discoverability
    output.comments << "INFO:  Testing for existence of a VPDiscoverable resource within the FDP record.\n"
    query = SPARQL.parse("#{prefixes}
      select ?s where {?s ejp:vpConnection ejp:VPDiscoverable }")
    results = query.execute(g)
    if results.any?
      # warn "one"
      output.comments << "INFO: Found the EJP VPDiscoverable property somewhere in the FDP.\n"
    else
      # warn "two"
      output.score = 'fail'
      output.comments << "FAILURE: Nothing in the FDP was flagged to be VPDiscoverable.\n"
      return output.createEvaluationResponse
    end

    discoverables = results.map { |r| r[:s].to_s }

    requiredpredicates = %w[dcat:theme dcat:contactPoint dct:description
                            dcat:keyword dct:language dct:license
                            dct:publisher dct:title dcat:contactPoint dcat:landingPage]

    _specialpredicates = %w[dct:isPartOf]

    optionalpredicates = %w[foaf:logo dct:issued dct:modified]

    discoverables.each do |d|
      optionalpredicates.each do |p|
        # warn "three"

        output.comments << "INFO:  Testing Discoverable #{d} for optional property #{p}.\n"
        query = SPARQL.parse("#{prefixes}
          SELECT ?o WHERE { <#{d}> #{p} ?o }")
        results = query.execute(g)
        output.comments << if results.any?
                             "INFO: Found the EJP recommended metadata element #{p} on the Discoverable entity #{d}'\n"
                           else
                             "WARN: the recommended metadata element #{p} could not be found on the Discoverable entity #{d}\n"
                           end
      end
    end

    failflag = false
    # warn "four"

    discoverables.each do |d|
      requiredpredicates.each do |p|
        output.comments << "INFO:  Testing Discoverable #{d} for mandatory property #{p}.\n"
        query = SPARQL.parse("#{prefixes}
          SELECT ?o WHERE { <#{d}> #{p} ?o }")
        results = query.execute(g)
        if results.any?
          # warn "five"
          output.comments << "INFO: Found the EJP mandatory metadata element #{p} on the Discoverable entity #{d}'\n"
        else
          # warn "six"
          output.comments << "WARN: the mandatory metadata element #{p} could not be found on the Discoverable entity #{d}\n"
          if p =~ /landingPage/
            output.comments << "WARN: If you are using the Reference FDP, or Sextans Suite, the #{p} property is labelled 'About Page' in the FDP metadata editing pages.\n"
          end
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
