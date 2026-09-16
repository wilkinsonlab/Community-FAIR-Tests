class FAIRTest
  def self.community_funding_information_registered_meta
    {
      testversion: HARVESTER_VERSION + ':' + 'Tst-0.0.3',
      testname: 'Funding information registered in metadata',
      testid: 'community_funding_information_registered',
      description: 'Test a GUID to determine if funder information is available. For DOIs, checks the
                    datacite or crossref metadata. For any GUID, also checks the harvested metadata graph
                    (e.g. an embedded schema.org JSON-LD snippet on the landing page) for a schema:funding
                    property.',
      metric: 'https://w3id.org/fair-metrics/esrf/FM_R1-2_M_Fund_ESRF',
      indicators: 'https://placeholder.org',
      type: 'http://edamontology.org/operation_2428',
      license: 'https://creativecommons.org/publicdomain/zero/1.0/',
      keywords: ['FAIR Assessment', 'FAIR Principles'],
      themes: ['http://edamontology.org/topic_4012'],
      organization: 'OSTrails Project',
      org_url: 'https://ostrails.eu/',
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

  def self.community_funding_information_registered(guid:)
    FtrRuby::Output.clear_comments

    output = FtrRuby::Output.new(
      testedGUID: guid,
      meta: community_funding_information_registered_meta
    )
    output.comments << "INFO: TEST VERSION '#{community_funding_information_registered_meta[:testversion]}'\n"

    guid = guid.strip
    if guid.match(%r{\Ahttps?://(dx\.)?doi\.org/(.+)\z}i)
      output.comments << "INFO: incoming guid stripped to be a raw DOI'\n"
      guid = ::Regexp.last_match(2)
    end
    doi = guid if guid.match(FAIRChampionHarvester::Utils::GUID_TYPES['doi'])

    output = FtrRuby::Output.new(
      testedGUID: guid,
      meta: community_funding_information_registered_meta
    )

    # meta = FAIRChampion::MetadataObject.new
    metadata = FAIRChampionHarvester::Core.resolveit(guid) # this is where the magic happens!

    metadata.comments.each do |c|
      output.comments << c
    end
    warn "metadata guidtype #{metadata.guidtype}"
    if metadata.guidtype == 'unknown'
      output.score = 'indeterminate'
      output.comments << "INDETERMINATE: The identifier #{guid} did not match any known identification system.\n"
      return output.createEvaluationResponse
    end

    output.comments << "INFO: Now testing #{guid} for funder information in the harvested metadata graph\n"
    if schema_org_funding_found?(metadata.graph, output)
      output.score = 'pass'
      output.comments << "PASS: A schema:funding property was found in the harvested metadata.\n"
      return output.createEvaluationResponse
    end

    unless doi
      output.score = 'fail'
      output.comments << "FAIL: No funder info found, and #{guid} isn't a DOI, so datacite/crossref don't apply.\n"
      return output.createEvaluationResponse
    end

    output.comments << "INFO: Now testing #{doi} for registration agency\n"
    agency = FAIRChampionHarvester::DOI.resolve_doi_to_registration_agency(doi, output)
    unless agency
      output.score = 'indeterminate'
      output.comments << "INDETERMINATE: The DOI was not a datacite or crossref DOI.\n"
      return output.createEvaluationResponse
    end

    if agency == 'Crossref'
      output.comments << "INFO: Agency is Crossref\n"
      output.comments << "INFO: Checking for funding block\n"
      fundingblock = FAIRChampionHarvester::DOI.get_funding_information_from_crossref(doi, output)
      unless fundingblock
        output.score = 'fail'
        output.comments << "FAIL: No funder found in crossref metadata.\n"
        return output.createEvaluationResponse
      end
    elsif agency == 'DataCite'
      output.comments << "INFO: Agency is Datacite\n"
      output.comments << "INFO: Checking for funding block\n"
      fundingblock = FAIRChampionHarvester::DOI.get_funding_information_from_datacite(doi, output)
      unless fundingblock
        output.score = 'fail'
        output.comments << "FAIL: No funder found in datacite metadata.\n"
        return output.createEvaluationResponse
      end
    else
      output.comments << "WARN: Something is wrong, and agency doesn't match datacite or crossref\n"
      output.score = 'indeterminate'
      output.comments << "INDETERMINATE: Oddly cannot identify agency from resolution, so can't test for funding\n"
      return output.createEvaluationResponse
    end

    output.score = 'pass'
    output.comments << "PASS: Funding block is found\n"
    output.createEvaluationResponse
  end

  # ---------------------------------------------------------------------------
  # True if the harvested metadata graph contains a schema:funding triple,
  # under either the http or https form of the schema.org namespace.
  # ---------------------------------------------------------------------------
  def self.schema_org_funding_found?(graph, output)
    return false unless graph

    query = SPARQL.parse('
      PREFIX schema_http: <http://schema.org/>
      PREFIX schema_https: <https://schema.org/>
      SELECT ?s ?o WHERE {
        { ?s schema_http:funding ?o } UNION { ?s schema_https:funding ?o }
      }')
    results = query.execute(graph)
    if results.any?
      output.comments << "INFO: Found a schema:funding triple in the harvested metadata graph.\n"
      true
    else
      output.comments << "INFO: No schema:funding triple was found in the harvested metadata graph.\n"
      false
    end
  end

  def self.community_funding_information_registered_api
    api = FtrRuby::OpenAPI.new(meta: community_funding_information_registered_meta)
    api.get_api
  end

  def self.community_funding_information_registered_about
    # warn "META: #{community_funding_information_registered_meta.inspect}"
    dcat = FtrRuby::DCAT_Record.new(meta: community_funding_information_registered_meta)
    dcat.get_dcat
  end
end
