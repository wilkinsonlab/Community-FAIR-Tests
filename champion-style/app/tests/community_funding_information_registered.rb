require_relative File.dirname(__FILE__) + '/../lib/harvester.rb'

class FAIRTest
  def self.community_funding_information_registered_meta
    {
      testversion: HARVESTER_VERSION + ':' + 'Tst-0.0.1',
      testname: 'Funding information registered in DOI metadata',
      testid: 'community_funding_information_registered',
      description: 'Test a DOI to determine if funder information is available in the datacite or crossref metadata',
      metric: 'https://fairsharing.org/7496', # TODO: UPDATE TO DOI WHEN rEADY
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

  def self.community_funding_information_registered(guid:)
    FAIRChampion::Output.clear_comments

    output = FAIRChampion::Output.new(
      testedGUID: guid,
      meta: community_funding_information_registered_meta
    )

    output.comments << "INFO: TEST VERSION '#{community_funding_information_registered_meta[:testversion]}'\n"

    # meta = FAIRChampion::MetadataObject.new
    metadata = FAIRChampion::Harvester.resolveit(guid) # this is where the magic happens!

    metadata.comments.each do |c|
      output.comments << c
    end
    warn "metadata guidtype #{metadata.guidtype}"
    if metadata.guidtype == 'unknown'
      output.score = 'indeterminate'
      output.comments << "INDETERMINATE: The identifier #{guid} did not match any known identification system.\n"
      return output.createEvaluationResponse
    end
    unless metadata.guidtype == 'doi'
      output.score = 'indeterminate'
      output.comments << "INDETERMINATE: The identifier #{guid} was not a doi.\n"
      return output.createEvaluationResponse
    end

    output.comments << "INFO: Now testing #{guid} for funder information\n"

    output.comments << "INFO: Now testing #{guid} for registration agency\n"
    agency = FAIRChampion::Harvester.resolve_doi_to_registration_agency(guid, output)
    unless agency
      output.score = 'indeterminate'
      output.comments << "INDETERMINATE: The DOI was not a datacite or crossref DOI.\n"
      return output.createEvaluationResponse
    end

    if agency == 'Crossref'
      output.comments << "INFO: Agency is Crossref\n"
      output.comments << "INFO: Checking for funding block\n"
      fundingblock = FAIRChampion::Harvester.get_funding_information_from_crossref(guid, output)
      unless fundingblock
        output.score = 'fail'
        output.comments << "FAIL: No funder found in crossref metadata.\n"
        return output.createEvaluationResponse
      end
    elsif agency == 'DataCite'
      output.comments << "INFO: Agency is Datacite\n"
      output.comments << "INFO: Checking for funding block\n"
      fundingblock = FAIRChampion::Harvester.get_funding_information_from_datacite(guid, output)
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

  def self.community_funding_information_registered_api
    api = OpenAPI.new(meta: community_funding_information_registered_meta)
    api.get_api
  end

  def self.community_funding_information_registered_about
    dcat = ChampionDCAT::DCAT_Record.new(meta: community_funding_information_registered_meta)
    dcat.get_dcat
  end
end
