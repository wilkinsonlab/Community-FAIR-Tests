# fair_tests/community_panet_vocabulary_in_metadata.rb

class FAIRTest
  def self.community_panet_vocabulary_in_metadata_meta
    {
      testversion: HARVESTER_VERSION + ':' + 'Tst-0.0.3',
      testname: 'FAIR Test - I2 - Dataset - DOI metadata contains a link to a community ontology term - PaNET',
      testid: 'community_panet_vocabulary_in_metadata',
      description: ' This metric ensures that the research object provided by the supplied URL is associated with a DataCite DOI whose metadata contains a PaNET subject term. This means that the DataCite metadata for the research object’s DOI must define a subject from PaNET using schemeUri or subjectScheme, or using a schemeUri or valueUri under the PaNET namespace "https://w3id.org/PaN/". The supplied URL can be one of: a doi.org domain URL or a DOI target repository domain URL.',
      metric: 'https://w3id.org/fair-metrics/esrf/FM_I2_M_VOC-PANET_DOI_ESRF',
      indicators: 'https://doi.org/10.25504/FAIRsharing.96d4af',
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

  def self.community_panet_vocabulary_in_metadata(guid:)
    FtrRuby::Output.clear_comments
    output = FtrRuby::Output.new(
      testedGUID: guid,
      meta: community_panet_vocabulary_in_metadata_meta
    )
    output.comments << "INFO: TEST VERSION '#{community_panet_vocabulary_in_metadata_meta[:testversion]}'\n"

    guid = guid.strip
    if guid.match(%r{https?://[^/]+/(.*)})
      output.comments << "INFO: incoming guid stripped to be a raw DOI\n"
      guid = ::Regexp.last_match(1)
    end

    output = FtrRuby::Output.new(
      testedGUID: guid,
      meta: community_panet_vocabulary_in_metadata_meta
    )

    metadata = FAIRChampionHarvester::Core.resolveit(guid)
    metadata.comments.each { |c| output.comments << c }

    if metadata.guidtype == 'unknown'
      output.score = 'indeterminate'
      output.comments << "INDETERMINATE: The identifier #{guid} did not match any known identification system.\n"
      return output.createEvaluationResponse
    end

    unless metadata.guidtype == 'doi'
      output.score = 'indeterminate'
      output.comments << "INDETERMINATE: The identifier #{guid} was not a DOI.\n"
      return output.createEvaluationResponse
    end

    output.comments << "INFO: Checking registration agency for #{guid}\n"
    agency = FAIRChampionHarvester::DOI.resolve_doi_to_registration_agency(guid, output)
    unless agency == 'DataCite'
      output.score = 'indeterminate'
      output.comments << "INDETERMINATE: The DOI is not registered with DataCite (agency: #{agency || 'unknown'}).\n"
      return output.createEvaluationResponse
    end

    output.comments << "INFO: DOI is registered with DataCite. Checking for PaNET subject terms.\n"
    panet_subject = fetch_panet_subject_from_datacite(guid, output)

    if panet_subject
      output.score = 'pass'
      output.comments << "SUCCESS: DataCite metadata contains a PaNET subject term: '#{panet_subject['subject']}'\n"
    else
      output.score = 'fail'
      output.comments << "FAIL: No PaNET subject term found in DataCite metadata for #{guid}.\n"
    end

    output.createEvaluationResponse
  end

  def self.community_panet_vocabulary_in_metadata_api
    api = FtrRuby::OpenAPI.new(meta: community_panet_vocabulary_in_metadata_meta)
    api.get_api
  end

  def self.community_panet_vocabulary_in_metadata_about
    dcat = FtrRuby::DCAT_Record.new(meta: community_panet_vocabulary_in_metadata_meta)
    dcat.get_dcat
  end

  PANET_NAMESPACE = 'https://w3id.org/PaN/'.freeze

  # ---------------------------------------------------------------------------
  # Fetch DataCite metadata and return the first subject that identifies as
  # PaNET, or nil if none is found. A subject counts as PaNET if either:
  #   - schemeUri or subjectScheme contains the string "PaNET", or
  #   - schemeUri or valueUri contains the PaNET namespace
  #     "https://w3id.org/PaN/"
  # ---------------------------------------------------------------------------
  def self.fetch_panet_subject_from_datacite(doi, meta)
    url = "https://api.datacite.org/dois/#{doi.downcase.strip}"
    meta.comments << "INFO: Fetching DataCite metadata from #{url}\n"
    _headers, body = FAIRChampionHarvester::Core.fetch(
      guid: url,
      headers: FAIRChampionHarvester::Utils::AcceptDefaultHeader
    )
    unless body
      meta.comments << "WARN: No response body from DataCite API.\n"
      return nil
    end

    data = JSON.parse(body)
    subjects = data.dig('data', 'attributes', 'subjects') || []
    subjects.find { |s| panet_subject?(s) }
  rescue JSON::ParserError => e
    meta.comments << "WARN: JSON parse error from DataCite: #{e.message}\n"
    nil
  end

  def self.panet_subject?(subject)
    subject['schemeUri'].to_s.include?('PaNET') ||
      subject['subjectScheme'].to_s.include?('PaNET') ||
      subject['schemeUri'].to_s.include?(PANET_NAMESPACE) ||
      subject['valueUri'].to_s.include?(PANET_NAMESPACE)
  end
end
