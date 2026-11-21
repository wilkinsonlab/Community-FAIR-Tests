class FAIRTest
  def self.erdera_vp_l2_metadata_meta
    {
      testversion: HARVESTER_VERSION + ':' + 'Tst-0.0.3',
      testname: 'ERDERA: Minimal VP Metadata for Level 2 Compliance',
      testid: 'erdera_vp_l2_metadata',
      description: "The ERDERA Project has strict requirements for minimal metadata to onboard their Virtual Platform.
                            For Level 2, you must first be Level 1 compliant (see https://w3id.org/fair-metrics/erdera/FM_R1-3_M_VP_L1).
                            In addition, you must declare yourself as a dcat Data Service, and have a landingPage at a minimimum.
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

    output.score = 'fail'
    FAIRTest.erderea_vp_l2_metadata_runtest(output: output, g: g)
    output.createEvaluationResponse
  end

  def self.erderea_vp_l2_metadata_runtest(output:, g:)
    prefixes = "PREFIX dcat: <http://www.w3.org/ns/dcat#>
	PREFIX dct: <http://purl.org/dc/terms/>
	"

    classes = %w[dcat:DataService]

    successflag = false
    classes.each do |classs|
      output.comments << "INFO:  Testing if it is a #{classs}.\n"
      classquery = SPARQL.parse("#{prefixes}
						select ?s where {
							?s a #{classs} .
		}")
      results = classquery.execute(g)
      if results.any?
        output.comments << "INFO: Found the EJP class #{classs} \n"
        successflag = true
      else
        output.comments << "WARN: this is not a #{classs}. Moving on\n"
      end
    end
    if successflag
      # it is at least a legal clas, now check for property
      output.comments << "INFO: Testing for the endpointURL and endpointDescription predicate \n"
      propertyquery = SPARQL.parse("#{prefixes}
			select ?url ?desc where {
				?s dcat:endpointURL ?url .
				?s dcat:endpointDescription ?desc .
		}")
      results = propertyquery.execute(g)
      if results.any?
        output.score = 'pass'
        output.comments << "SUCCESS: found endpointURL and endpointDescription\n"
      else
        output.comments << "INFO: didn't find endpointURL and endpointDescription predicate \n"
        output.comments << "INFO: Testing for the landingPage predicate \n"
        propertyquery = SPARQL.parse("#{prefixes}
			select ?lp where {
				?s dcat:landingPage ?lp .
			}")
        results = propertyquery.execute(g)
        if results.any?
          output.score = 'pass'
          output.comments << "SUCCESS: found landingPage\n"
        else
          output.comments << "FAILURE: EJP DataServices are recommended to have both a endpointURL and endpointDescription, or a landingPage.\n"
        end
      end
    else
      output.comments << "INFO: This test should not be run on this class type. You will pass. \n"
      output.score = 'pass'
    end
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
