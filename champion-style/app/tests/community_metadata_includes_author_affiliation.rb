require_relative File.dirname(__FILE__) + '/../lib/harvester.rb'

class FAIRTest
  def self.community_metadata_includes_author_affiliation_meta
    {
      testversion: HARVESTER_VERSION + ':' + 'Tst-0.0.1',
      testname: 'Metadata includes author affiliation',
      testid: 'community_metadata_includes_author_affiliation',
      description: 'Use Crossref and Datacite APIs to scan a metadata record for author affiliation. Also check landing page for citation_author_institution meta property',
      metric: 'https://w3id.org/fair-metrics/esrf/R1.2.AFF.ttl'.downcase, # TODO: UPDATE TO DOI WHEN rEADY
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
      basePath: ENV.fetch('TEST_PATH', '/tests')
    }
  end

  def self.community_metadata_includes_author_affiliation(guid:)
    FAIRChampion::Output.clear_comments

    output = FAIRChampion::Output.new(
      testedGUID: guid,
      meta: community_metadata_includes_author_affiliation_meta
    )

    output.comments << "INFO: TEST VERSION '#{community_metadata_includes_author_affiliation_meta[:testversion]}'\n"

    # meta = FAIRChampion::MetadataObject.new
    metadata = FAIRChampion::Harvester.resolveit(guid) # this is where the magic happens!

    metadata.comments.each do |c|
      output.comments << c
    end

    hash = metadata.hash
    graph = metadata.graph
    properties = FAIRChampion::Harvester.deep_dive_properties(hash)
    #  properties is [[:user, "bob42"],
    #   #     [:config, {theme: "dark", alerts: {email: true, push: false}}],
    #   #     [:theme, "dark"],

    if properties.any? { |k, _v| k.to_s == 'citation_author_institution' } # this is from landing page metadata
      output.score = 'pass'
      output.comments << "PASS: an author affiliation metadata facet was found in the landing page or link header metadata.\n"
      return output.createEvaluationResponse
    end

    # warn "metadata guidtype #{metadata.guidtype}"
    if metadata.guidtype == 'unknown'
      output.score = 'indeterminate'
      output.comments << "INDETERMINATE: The identifier #{guid} did not match any known identification system.\n"
      return output.createEvaluationResponse
    end
    unless metadata.guidtype == 'doi'
      output.score = 'indeterminate'
      output.comments << "INDETERMINATE: The identifier #{guid} was not a doi, so crossref and datacite could not be tested.\n"
      return output.createEvaluationResponse
    end

    output.comments << "INFO: Now testing #{guid} for affiliation information\n"

    output.comments << "INFO: Now testing #{guid} for registration agency\n"
    agency = FAIRChampion::Harvester.resolve_doi_to_registration_agency(guid, output)
    unless agency
      output.score = 'indeterminate'
      output.comments << "INDETERMINATE: The DOI was not a datacite or crossref DOI.\n"
      return output.createEvaluationResponse
    end

    if agency == 'Crossref'
      output.comments << "INFO: Agency is Crossref\n"
      output.comments << "INFO: Checking for affiliation block\n"
      fundingblock = FAIRChampion::Harvester.check_affiliation_information_from_crossref(guid, output)
      unless fundingblock
        output.score = 'fail'
        output.comments << "FAIL: No affiliation found in crossref metadata.\n"
        return output.createEvaluationResponse
      end

    elsif agency == 'DataCite'
      output.comments << "INFO: Agency is Datacite\n"
      output.comments << "INFO: Checking for affiliation block\n"
      fundingblock = FAIRChampion::Harvester.check_affiliation_information_from_datacite(guid, output)
      unless fundingblock
        output.score = 'fail'
        output.comments << "FAIL: No affiliation found in datacite metadata.\n"
        return output.createEvaluationResponse
      end
    else
      output.comments << "WARN: Something is wrong, and agency doesn't match datacite or crossref\n"
      output.score = 'indeterminate'
      output.comments << "INDETERMINATE: Oddly cannot identify agency from resolution, so can't test for affiliation\n"
      return output.createEvaluationResponse
    end

    output.score = 'pass'
    output.comments << "PASS: Affiliation block is found for at least one author\n"
    output.createEvaluationResponse
  end

  def self.community_metadata_includes_author_affiliation_api
    api = OpenAPI.new(meta: community_metadata_includes_author_affiliation_meta)
    api.get_api
  end

  def self.community_metadata_includes_author_affiliation_about
    dcat = ChampionDCAT::DCAT_Record.new(meta: community_metadata_includes_author_affiliation_meta)
    dcat.get_dcat
  end
end
