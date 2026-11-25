class FAIRTest
  def self.dabar_croatian_classification_subject_meta
    {
      testversion: HARVESTER_VERSION + ':' + 'Tst-0.0.2',
      testname: 'DABAR: Croatian classification of scientific and artistic areas (nvzz.hr) used in DataCite subjects',
      testid: 'dabar_croatian_classification_subject',
      description: 'Retrieves the DataCite metadata for a record (oai_datacite via the repository OAI-PMH
                    endpoint, and/or DataCite XML for a DataCite DOI) and checks whether at least one
                    datacite:subject declares subjectScheme="nvzz.hr" (the Croatian classification of
                    scientific and artistic areas, fields and branches) with a non-empty value. Ordinary
                    keywords without that scheme do not count.',
      metric: 'https://ostrails.github.io/assessment-component-metadata-records/metric/FM_R1.3_M_UseCCSAA.ttl',
      indicators: 'https://placeholder.org',
      type: 'http://edamontology.org/operation_2428',
      license: 'https://creativecommons.org/publicdomain/zero/1.0/',
      keywords: ['FAIR Assessment', 'FAIR Principles', 'DataCite', 'subject classification', 'nvzz.hr', 'DABAR'],
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

  CROATIAN_CLASSIFICATION_SCHEME = 'nvzz.hr'.freeze

  def self.dabar_croatian_classification_subject(guid:)
    FtrRuby::Output.clear_comments

    output = FtrRuby::Output.new(
      testedGUID: guid,
      meta: dabar_croatian_classification_subject_meta
    )
    output.comments << "INFO: TEST VERSION '#{dabar_croatian_classification_subject_meta[:testversion]}'\n"

    guid = guid.strip
    if guid.match(%r{\Ahttps?://(dx\.)?doi\.org/(.+)\z}i)
      output.comments << "INFO: incoming guid stripped to be a raw DOI'\n"
      guid = ::Regexp.last_match(2)
    end

    # the harvester also discovers the repository's OAI-PMH endpoint, and merges
    # its oai_datacite record (when offered) into metadata.hash
    metadata = FAIRChampionHarvester::Core.resolveit(guid)
    metadata.comments.each do |c|
      output.comments << c
    end

    if metadata.guidtype == 'unknown'
      output.score = 'indeterminate'
      output.comments << "INDETERMINATE: The identifier #{guid} did not match any known identification system.\n"
      return output.createEvaluationResponse
    end

    subjects = []

    output.comments << "INFO: Looking for DataCite subjects in the harvested metadata (e.g. an OAI-PMH oai_datacite record).\n"
    harvested = datacite_subjects_from_hash(metadata.hash)
    if harvested.empty?
      output.comments << "INFO: No DataCite subjects were found in the harvested metadata.\n"
    else
      output.comments << "INFO: Found #{harvested.size} DataCite subject(s) in the harvested metadata.\n"
      subjects.concat(harvested)
    end

    if metadata.guidtype == 'doi'
      output.comments << "INFO: Now testing #{guid} for registration agency\n"
      agency = FAIRChampionHarvester::DOI.resolve_doi_to_registration_agency(guid, output)
      if agency == 'DataCite'
        from_doi = datacite_subjects_from_doi(guid, output)
        if from_doi.nil?
          output.comments << "WARN: DataCite XML could not be retrieved or parsed for #{guid}.\n"
        else
          output.comments << "INFO: Found #{from_doi.size} subject(s) in the DataCite XML for #{guid}.\n"
          subjects.concat(from_doi)
        end
      else
        output.comments << "INFO: The DOI registration agency is #{agency || 'unknown'}, not DataCite; " \
                           "no DataCite XML is available from the DOI itself.\n"
      end
    end

    if subjects.empty?
      output.score = 'indeterminate'
      output.comments << "INDETERMINATE: No DataCite subject values could be retrieved for #{guid}, " \
                         "so use of the #{CROATIAN_CLASSIFICATION_SCHEME} classification cannot be assessed.\n"
      return output.createEvaluationResponse
    end

    classified = subjects.select do |s|
      s[:scheme].to_s.strip.casecmp?(CROATIAN_CLASSIFICATION_SCHEME) && !s[:value].to_s.strip.empty?
    end
    other_schemes = (subjects - classified).map { |s| s[:scheme].to_s.strip }.reject(&:empty?).uniq

    if classified.any?
      values = classified.map { |s| s[:lang] ? "#{s[:value].strip} (#{s[:lang]})" : s[:value].strip }.uniq
      output.comments << "INFO: #{CROATIAN_CLASSIFICATION_SCHEME} classification subject(s): #{values.join('; ')}.\n"
      output.score = 'pass'
      output.comments << "PASS: #{classified.size} of #{subjects.size} DataCite subject(s) use the " \
                         "#{CROATIAN_CLASSIFICATION_SCHEME} classification with a non-empty value.\n"
    else
      scheme_note = other_schemes.any? ? "subject schemes found: #{other_schemes.join(', ')}" : 'no subject declared a subjectScheme'
      output.comments << "INFO: None of the subjects use #{CROATIAN_CLASSIFICATION_SCHEME} (#{scheme_note}).\n"
      output.score = 'fail'
      output.comments << "FAIL: #{subjects.size} DataCite subject(s) were found, but none declares " \
                         "subjectScheme=\"#{CROATIAN_CLASSIFICATION_SCHEME}\" with a non-empty value.\n"
    end
    output.createEvaluationResponse
  end

  # ---------------------------------------------------------------------------
  # Subjects from metadata.hash. An OAI-PMH oai_datacite record is merged there
  # by XmlSimple (ForceArray off), giving {"subjects"=>{"subject"=>Hash|String|Array}};
  # DataCite JSON, if present, gives {"subjects"=>[{"subject"=>..., "subjectScheme"=>...}]}.
  # ---------------------------------------------------------------------------
  def self.datacite_subjects_from_hash(hash)
    return [] unless hash.is_a?(Hash)

    block = hash['subjects']
    entries = if block.is_a?(Hash)
                block['subject'].nil? ? [] : [block['subject']].flatten
              elsif block.is_a?(Array) then block
              else []
              end

    entries.filter_map do |s|
      case s
      when String
        { value: s, scheme: nil, lang: nil }
      when Hash
        value = s.key?('content') ? s['content'] : s['subject']
        { value: value.to_s, scheme: s['subjectScheme'], lang: s['lang'] || s['xml:lang'] }
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Subjects from DataCite XML, obtained by content negotiation on the DOI.
  # Returns nil if the XML could not be retrieved or parsed.
  # ---------------------------------------------------------------------------
  def self.datacite_subjects_from_doi(doi, output)
    doi = doi.downcase.strip
    url = "https://doi.org/#{doi}"
    output.comments << "INFO: Resolving #{url} as DataCite XML for subject classification\n"
    _headers, body = FAIRChampionHarvester::Core.fetch(
      guid: url,
      headers: { 'Accept' => 'application/vnd.datacite.datacite+xml' }
    )
    return nil unless body

    doc = Nokogiri::XML(body) { |config| config.strict.nonet }
    lang_of = ->(node) { node.attribute_with_ns('lang', 'http://www.w3.org/XML/1998/namespace')&.value }
    langs = doc.xpath("//*[local-name()='subjects']/*[local-name()='subject']").map { |n| lang_of.call(n) }
    doc.remove_namespaces!
    return nil unless doc.at_xpath('//resource')

    doc.xpath('//subjects/subject').each_with_index.map do |s, i|
      { value: s.text, scheme: s['subjectScheme'], lang: langs[i] }
    end
  rescue Nokogiri::XML::SyntaxError
    output.comments << "WARN: The DataCite response for #{doi} was not well-formed XML.\n"
    nil
  end

  def self.dabar_croatian_classification_subject_api
    api = FtrRuby::OpenAPI.new(meta: dabar_croatian_classification_subject_meta)
    api.get_api
  end

  def self.dabar_croatian_classification_subject_about
    dcat = FtrRuby::DCAT_Record.new(meta: dabar_croatian_classification_subject_meta)
    dcat.get_dcat
  end
end
