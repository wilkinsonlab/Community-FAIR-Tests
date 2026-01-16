require_relative File.dirname(__FILE__) + '/../lib/harvester.rb'

class FAIRTest
  def self.community_open_access_publication_meta
    {
      testversion: HARVESTER_VERSION + ':' + 'Tst-0.0.1',
      testname: 'Resource is Open-Access output',
      testid: 'community_open_access_publication',
      description: 'Test a DOI against OpenAlex to determine if the resource output is open-access',
      metric: 'https://fairsharing.org/6449', # TODO: UPDATE TO DOI WHEN rEADY
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

  def self.community_open_access_publication(guid:)
    FAIRChampion::Output.clear_comments

    output = FAIRChampion::Output.new(
      testedGUID: guid,
      meta: community_open_access_publication_meta
    )

    output.comments << "INFO: TEST VERSION '#{community_open_access_publication_meta[:testversion]}'\n"

    meta = FAIRChampion::MetadataObject.new
    metadata = FAIRChampion::Harvester.openalex_doi(guid, meta) # this is where the magic happens!

    metadata.comments.each do |c|
      output.comments << c
    end
    warn "metadata guidtype #{metadata.guidtype}"
    if metadata.guidtype == 'unknown'
      output.score = 'indeterminate'
      output.comments << "INDETERMINATE: The identifier #{guid} did not match any known identification system.\n"
      return output.createEvaluationResponse
    end

    # json = metadata.hash.to_json
    # warn "\n\JSON\n",json,"\n\n\n"

    output.comments << "INFO: Searching OpenAlex record for open access flag\n"
    is_oa = metadata.hash.dig('open_access', 'is_oa')

    unless is_oa
      output.comments << "FAILURE: No data identifier was found in the metadata record.\n"
      output.score = 'fail'
      return output.createEvaluationResponse
    end

    output.comments << "SUCCESS: #{guid} is open access\n"
    output.score = 'pass'
    output.createEvaluationResponse
  end

  def self.community_open_access_publication_api
    api = OpenAPI.new(meta: community_open_access_publication_meta)
    api.get_api
  end

  def self.community_open_access_publication_about
    dcat = ChampionDCAT::DCAT_Record.new(meta: community_open_access_publication_meta)
    dcat.get_dcat
  end
end
