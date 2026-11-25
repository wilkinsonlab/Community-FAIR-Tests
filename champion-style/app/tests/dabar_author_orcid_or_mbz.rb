class FAIRTest
  def self.dabar_author_orcid_or_mbz_meta
    {
      testversion: HARVESTER_VERSION + ':' + 'Tst-0.0.2',
      testname: 'DABAR: Authors identified by ORCID or MBZ in DataCite metadata',
      testid: 'dabar_author_orcid_or_mbz',
      description: 'Retrieves the DataCite metadata for a record (oai_datacite via the repository OAI-PMH
                    endpoint, and/or DataCite XML for a DataCite DOI) and checks whether at least one
                    author (datacite:creator) carries a non-empty ORCID or MBZ (Croatian researcher
                    identification number) identifier, in either a nameIdentifier (nameIdentifierScheme)
                    or a creatorIdentifier (identifierType or scheme).',
      metric: 'https://ostrails.github.io/assessment-component-metadata-records/metric/FM_R1.2_M_ORCID_MBZ.ttl',
      indicators: 'https://placeholder.org',
      type: 'http://edamontology.org/operation_2428',
      license: 'https://creativecommons.org/publicdomain/zero/1.0/',
      keywords: ['FAIR Assessment', 'FAIR Principles', 'ORCID', 'MBZ', 'DataCite', 'DABAR'],
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

  ACCEPTED_PERSON_ID_SCHEMES = %w[ORCID MBZ].freeze

  def self.dabar_author_orcid_or_mbz(guid:)
    FtrRuby::Output.clear_comments

    output = FtrRuby::Output.new(
      testedGUID: guid,
      meta: dabar_author_orcid_or_mbz_meta
    )
    output.comments << "INFO: TEST VERSION '#{dabar_author_orcid_or_mbz_meta[:testversion]}'\n"

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

    creators = []

    output.comments << "INFO: Looking for DataCite creators in the harvested metadata (e.g. an OAI-PMH oai_datacite record).\n"
    harvested = datacite_creators_from_hash(metadata.hash)
    if harvested.empty?
      output.comments << "INFO: No DataCite creators were found in the harvested metadata.\n"
    else
      output.comments << "INFO: Found #{harvested.size} DataCite creator(s) in the harvested metadata.\n"
      creators.concat(harvested)
    end

    if metadata.guidtype == 'doi'
      output.comments << "INFO: Now testing #{guid} for registration agency\n"
      agency = FAIRChampionHarvester::DOI.resolve_doi_to_registration_agency(guid, output)
      if agency == 'DataCite'
        from_doi = datacite_creators_from_doi(guid, output)
        if from_doi.nil?
          output.comments << "WARN: DataCite XML could not be retrieved or parsed for #{guid}.\n"
        else
          output.comments << "INFO: Found #{from_doi.size} creator(s) in the DataCite XML for #{guid}.\n"
          creators.concat(from_doi)
        end
      else
        output.comments << "INFO: The DOI registration agency is #{agency || 'unknown'}, not DataCite; " \
                           "no DataCite XML is available from the DOI itself.\n"
      end
    end

    if creators.empty?
      output.score = 'indeterminate'
      output.comments << "INDETERMINATE: No DataCite metadata with identifiable authors (datacite:creator) " \
                         "could be retrieved for #{guid}.\n"
      return output.createEvaluationResponse
    end

    qualified = creators.select { |c| c[:ids].any? }
    creators.each do |c|
      if c[:ids].any?
        ids = c[:ids].map { |i| "#{i[:scheme]} #{i[:value]}" }.join(', ')
        output.comments << "INFO: Author '#{c[:name]}' (#{c[:source]}) has #{ids}.\n"
      else
        output.comments << "INFO: Author '#{c[:name]}' (#{c[:source]}) has no ORCID or MBZ identifier.\n"
      end
    end

    if qualified.any?
      output.score = 'pass'
      output.comments << "PASS: #{qualified.size} of #{creators.size} author(s) found in the DataCite metadata " \
                         "carry an ORCID or MBZ identifier.\n"
    else
      output.score = 'fail'
      output.comments << "FAIL: None of the #{creators.size} author(s) found in the DataCite metadata " \
                         "carry a non-empty ORCID or MBZ identifier.\n"
    end
    output.createEvaluationResponse
  end

  # ---------------------------------------------------------------------------
  # Creators from metadata.hash. An OAI-PMH oai_datacite record is merged there
  # by XmlSimple (ForceArray off), giving {"creators"=>{"creator"=>Hash|Array}};
  # DataCite JSON, if present, gives {"creators"=>[...]} with "nameIdentifiers".
  # ---------------------------------------------------------------------------
  def self.datacite_creators_from_hash(hash)
    return [] unless hash.is_a?(Hash)

    block = hash['creators']
    entries = if block.is_a?(Hash) then as_list(block['creator'])
              elsif block.is_a?(Array) then block
              else []
              end

    entries.filter_map do |creator|
      next unless creator.is_a?(Hash)

      name = text_of(creator['creatorName']) || creator['name'] ||
             [creator['givenName'], creator['familyName']].compact.join(' ')
      ids = []
      as_list(creator['nameIdentifier']).each do |ni|
        ids << person_id(ni.is_a?(Hash) ? ni['nameIdentifierScheme'] : nil, text_of(ni))
      end
      as_list(creator['creatorIdentifier']).each do |ci|
        scheme = ci.is_a?(Hash) ? (ci['identifierType'] || ci['scheme']) : nil
        ids << person_id(scheme, text_of(ci))
      end
      # DataCite JSON shape
      as_list(creator['nameIdentifiers']).each do |ni|
        next unless ni.is_a?(Hash)

        ids << person_id(ni['nameIdentifierScheme'], ni['nameIdentifier'])
      end
      { name: name.to_s.strip.empty? ? '(unnamed)' : name.to_s.strip, ids: ids.compact.uniq,
        source: 'harvested metadata' }
    end
  end

  # ---------------------------------------------------------------------------
  # Creators from DataCite XML, obtained by content negotiation on the DOI.
  # Returns nil if the XML could not be retrieved or parsed.
  # ---------------------------------------------------------------------------
  def self.datacite_creators_from_doi(doi, output)
    doi = doi.downcase.strip
    url = "https://doi.org/#{doi}"
    output.comments << "INFO: Resolving #{url} as DataCite XML for creator identifiers\n"
    _headers, body = FAIRChampionHarvester::Core.fetch(
      guid: url,
      headers: { 'Accept' => 'application/vnd.datacite.datacite+xml' }
    )
    return nil unless body

    doc = Nokogiri::XML(body) { |config| config.strict.nonet }
    doc.remove_namespaces!
    return nil unless doc.at_xpath('//resource')

    doc.xpath('//creators/creator').map do |creator|
      name = creator.at_xpath('./creatorName')&.text.to_s.strip
      ids = creator.xpath('./nameIdentifier').map do |ni|
        person_id(ni['nameIdentifierScheme'], ni.text)
      end
      ids += creator.xpath('./creatorIdentifier').map do |ci|
        person_id(ci['identifierType'] || ci['scheme'], ci.text)
      end
      { name: name.empty? ? '(unnamed)' : name, ids: ids.compact.uniq, source: 'DataCite XML from DOI' }
    end
  rescue Nokogiri::XML::SyntaxError
    output.comments << "WARN: The DataCite response for #{doi} was not well-formed XML.\n"
    nil
  end

  # {scheme:, value:} when the scheme is ORCID or MBZ and the value is non-empty, else nil
  def self.person_id(scheme, value)
    scheme = scheme.to_s.strip.upcase
    value = value.to_s.strip
    return nil if value.empty? || !ACCEPTED_PERSON_ID_SCHEMES.include?(scheme)

    { scheme: scheme, value: value }
  end

  def self.as_list(x)
    return [] if x.nil?

    x.is_a?(Array) ? x : [x]
  end

  # XmlSimple gives a plain String for an element without attributes, or
  # {"content"=>...} when the element has attributes
  def self.text_of(node)
    node.is_a?(Hash) ? node['content'] : node
  end

  def self.dabar_author_orcid_or_mbz_api
    api = FtrRuby::OpenAPI.new(meta: dabar_author_orcid_or_mbz_meta)
    api.get_api
  end

  def self.dabar_author_orcid_or_mbz_about
    dcat = FtrRuby::DCAT_Record.new(meta: dabar_author_orcid_or_mbz_meta)
    dcat.get_dcat
  end
end
