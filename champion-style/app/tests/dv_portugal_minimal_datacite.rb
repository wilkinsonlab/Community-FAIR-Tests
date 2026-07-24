class FAIRTest
  def self.dv_portugal_minimal_datacite_meta
    {
      testversion: HARVESTER_VERSION + ':' + 'Tst-0.0.2',
      testname: 'Dataverse Portugal Minimal Datacite Provenance Metadata',
      testid: 'dv_portugal_minimal_datacite',
      description: 'The PT Dataverse data provenance test evaluates compliance with the minimum metadata requirements established by the PT Dataverse community. FM_R1-2_M_PtDataProv metric expects a repository DOI and evaluates the digital object for the presence of mandatory attributes required for a passing score.




Mandatory metadata are: creator, contributor, contributor role, date of collection, deposit date (draft creation), publication date, grant information.



The evaluation of this principle is relevant to the PT Dataverse community because will ensure the standardised collection of the provenance information about data creation or generation.',
      metric: 'https://ostrails.github.io/assessment-component-metadata-records/metric/FM_R1-2_M_PtDataProv.ttl',
      indicators: 'https://doi.org/10.25504/FAIRsharing.9ca8a1',
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

  def self.dv_portugal_minimal_datacite(guid:)
    FtrRuby::Output.clear_comments

    output = FtrRuby::Output.new(
      testedGUID: guid,
      meta: dv_portugal_minimal_datacite_meta
    )
    output.comments << "INFO: TEST VERSION '#{dv_portugal_minimal_datacite_meta[:testversion]}'\n"

    guid = guid.strip
    if guid.match(%r{https?://[^/]+/(.*)})
      output.comments << "INFO: incoming guid stripped to be a raw DOI'\n"
      guid = ::Regexp.last_match(1)
    end

    output = FtrRuby::Output.new(
      testedGUID: guid,
      meta: dv_portugal_minimal_datacite_meta
    )

    metadata = FAIRChampionHarvester::Core.resolveit(guid)

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

    output.comments << "INFO: Now testing #{guid} for registration agency\n"
    agency = FAIRChampionHarvester::DOI.resolve_doi_to_registration_agency(guid, output)
    unless agency
      output.score = 'indeterminate'
      output.comments << "INDETERMINATE: The DOI was not a datacite or crossref DOI.\n"
      return output.createEvaluationResponse
    end

    unless agency == 'DataCite'
      output.score = 'indeterminate'
      output.comments << "INDETERMINATE: The DOI registration agency is #{agency}, not DataCite, " \
                          "so minimal DataCite provenance metadata cannot be assessed.\n"
      return output.createEvaluationResponse
    end

    output.comments << "INFO: Now testing #{guid} for minimal provenance metadata " \
                        '(creator, contributor, contributor role, date of collection, ' \
                        "deposit date, publication date, grant information)\n"
    provenance = get_datacite_provenance_metadata(guid, output)
    unless provenance
      output.score = 'indeterminate'
      output.comments << "INDETERMINATE: Could not retrieve DataCite XML metadata for #{guid}.\n"
      return output.createEvaluationResponse
    end

    missing = provenance.reject { |_property, present| present }.keys
    if missing.empty?
      output.score = 'pass'
      output.comments << "PASS: All mandatory provenance metadata elements were found.\n"
    else
      output.score = 'fail'
      output.comments << "FAIL: Missing mandatory provenance metadata element(s): #{missing.join(', ')}.\n"
    end
    output.createEvaluationResponse
  end

  # Resolves the DOI itself via content negotiation for DataCite XML (rather than
  # going through the api.datacite.org REST API) and checks for the minimal
  # provenance elements required by the PT Dataverse community metadata profile.
  # Positive example: https://doi.org/10.57979/08PIRG
  def self.get_datacite_provenance_metadata(doi, output)
    doi = doi.downcase.gsub(%r{https?://[^/+]/}, '').strip
    url = "https://doi.org/#{doi}"
    output.comments << "INFO:  Resolving #{url} as DataCite XML for provenance metadata\n"
    _headers, body = FAIRChampionHarvester::Core.fetch(
      guid: url,
      headers: { 'Accept' => 'application/vnd.datacite.datacite+xml' }
    )
    return false unless body

    output.comments << "INFO:  parsing DataCite XML metadata\n"
    doc = Nokogiri::XML(body)
    doc.remove_namespaces!

    {
      'creator' => !doc.at_xpath('//creators/creator').nil?,
      'contributor' => !doc.at_xpath('//contributors/contributor').nil?,
      'contributor role' => !doc.at_xpath('//contributors/contributor[@contributorType]').nil?,
      'date of collection' => !doc.at_xpath("//dates/date[@dateType='Created']").nil?,
      'deposit date' => !doc.at_xpath("//dates/date[@dateType='Submitted']").nil?,
      'publication date' => !doc.at_xpath('//publicationYear')&.text&.strip.to_s.empty?,
      'grant information' => !doc.at_xpath('//fundingReferences/fundingReference').nil?
    }
  end

  def self.dv_portugal_minimal_datacite_api
    api = FtrRuby::OpenAPI.new(meta: dv_portugal_minimal_datacite_meta)
    api.get_api
  end

  def self.dv_portugal_minimal_datacite_about
    # warn "META: #{dv_portugal_minimal_datacite_meta.inspect}"
    dcat = FtrRuby::DCAT_Record.new(meta: dv_portugal_minimal_datacite_meta)
    dcat.get_dcat
  end
end
