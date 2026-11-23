class FAIRTest
  def self.erdera_vp_l2_metadata_meta
    {
      testversion: HARVESTER_VERSION + ':' + 'Tst-0.0.4',
      testname: 'ERDERA: Minimal VP Metadata for Level 2 Compliance',
      testid: 'erdera_vp_l2_metadata',
      description: "The ERDERA Project has strict requirements for minimal metadata to onboard their Virtual Platform.
                            For Level 2, you must first be Level 1 compliant (see https://w3id.org/fair-metrics/erdera/FM_R1-3_M_VP_L1).
                            In addition, you must declare yourself as a dcat Data Service, and have a landingPage at a minimimum.
                            The resource the GUID identifies must be typed dcat:DataService; any other resource fails.
                  ",
      metric: 'https://w3id.org/fair-metrics/erdera/FM_R1-3_M_VP_L2',
      indicators: 'https://fairsharing.org/FAIRsharing.87d197',
      type: 'http://edamontology.org/operation_2428',
      license: 'https://creativecommons.org/publicdomain/zero/1.0/',
      keywords: ['FAIR Assessment', 'FAIR Principles', 'FAIR', 'R1.3', 'identifier', 'metadata', 'ERDERA',
                 'virtual platform', 'data service'],
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

  def self.erdera_vp_l2_metadata(guid:)
    FtrRuby::Output.clear_comments

    output = FtrRuby::Output.new(
      testedGUID: guid,
      meta: erdera_vp_l2_metadata_meta
    )

    output.comments << "INFO: TEST VERSION '#{erdera_vp_l2_metadata_meta[:testversion]}'\n"

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
    # resolved to). L2 applies only to dcat:DataService, so any other resource fails.
    subjects = erdera_vp_l2_metadata_subjects(metadata, guid)
    described = subjects.select { |s| g.has_subject?(RDF::URI(s)) }
    if described.empty?
      output.score = 'indeterminate'
      output.comments << "INDETERMINATE: The harvested metadata does not describe #{subjects.join(' or ')}, " \
                         "so the resource's own metadata cannot be assessed.\n"
      return output.createEvaluationResponse
    end
    output.comments << "INFO: Assessing the metadata of #{described.join(', ')}\n"

    output.score = 'fail'
    FAIRTest.erderea_vp_l2_metadata_runtest(output: output, g: g, resources: described)
    output.createEvaluationResponse
  end

  # The resource the GUID identifies: the GUID itself and any URI it resolved to.
  def self.erdera_vp_l2_metadata_subjects(metadata, guid)
    ([guid] + metadata.finalURI.to_a.map(&:to_s)).map(&:strip).reject(&:empty?).uniq
  end

  def self.erderea_vp_l2_metadata_runtest(output:, g:, resources:)
    dcat = 'http://www.w3.org/ns/dcat#'
    services = resources.select { |r| g.has_statement?(RDF::Statement(RDF::URI(r), RDF.type, RDF::URI("#{dcat}DataService"))) }
    if services.empty?
      output.comments << "FAILURE: #{resources.join(', ')} is not typed as a dcat:DataService. " \
                         "Level 2 applies only to Data Services, so this resource does not meet it.\n"
      return
    end
    output.comments << "INFO: #{services.join(', ')} is a dcat:DataService\n"

    has = ->(r, p) { g.query({ subject: RDF::URI(r), predicate: RDF::URI("#{dcat}#{p}") }).any? }
    services.each do |r|
      output.comments << "INFO: Testing #{r} for dcat:endpointURL and dcat:endpointDescription\n"
      if has.call(r, 'endpointURL') && has.call(r, 'endpointDescription')
        output.score = 'pass'
        output.comments << "SUCCESS: found endpointURL and endpointDescription on #{r}\n"
        return
      end
      output.comments << "INFO: didn't find both endpointURL and endpointDescription on #{r}; testing for dcat:landingPage\n"
      if has.call(r, 'landingPage')
        output.score = 'pass'
        output.comments << "SUCCESS: found landingPage on #{r}\n"
        return
      end
    end
    output.comments << 'FAILURE: EJP DataServices must have both an endpointURL and an endpointDescription, ' \
                       "or a landingPage.\n"
  end

  def self.erdera_vp_l2_metadata_api
    api = FtrRuby::OpenAPI.new(meta: erdera_vp_l2_metadata_meta)
    api.get_api
  end

  def self.erdera_vp_l2_metadata_about
    # warn "META: #{erdera_vp_l2_metadata_meta.inspect}"
    dcat = FtrRuby::DCAT_Record.new(meta: erdera_vp_l2_metadata_meta)
    dcat.get_dcat
  end
end
