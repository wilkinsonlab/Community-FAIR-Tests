class FAIRTest
  def self.dabar_institutional_identification_meta
    {
      testversion: HARVESTER_VERSION + ':' + 'Tst-0.0.2',
      testname: 'DABAR: Creator affiliation identified by an organisation identifier in DataCite metadata',
      testid: 'dabar_institutional_identification',
      description: 'Retrieves the DataCite metadata for a record (oai_datacite via the repository OAI-PMH
                    endpoint, e.g. from a signposted describedby link, and/or DataCite XML for a DataCite DOI)
                    and checks whether at least one datacite:creator has, within its own creator element, an
                    affiliation with a non-empty affiliationIdentifier (e.g. an OIB or CroRIS ID). No particular
                    identifier scheme is required; affiliationIdentifierScheme is reported when given. An
                    affiliation given only as text does not identify the institution and does not count.',
      metric: 'https://ostrails.github.io/assessment-component-metadata-records/metric/FM_R1.2_M_Inst_id.ttl',
      indicators: 'https://ostrails.github.io/assessment-component-metadata-records/metric/FM_R1.2_M_Inst_id.ttl',
      type: 'http://edamontology.org/operation_2428',
      license: 'https://creativecommons.org/publicdomain/zero/1.0/',
      keywords: ['FAIR Assessment', 'FAIR Principles', 'affiliation', 'organisation identifier', 'DataCite', 'DABAR'],
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

  def self.dabar_institutional_identification(guid:)
    FtrRuby::Output.clear_comments

    output = FtrRuby::Output.new(
      testedGUID: guid,
      meta: dabar_institutional_identification_meta
    )
    output.comments << "INFO: TEST VERSION '#{dabar_institutional_identification_meta[:testversion]}'\n"

    guid = guid.strip
    if guid.match(%r{\Ahttps?://(dx\.)?doi\.org/(.+)\z}i)
      output.comments << "INFO: incoming guid stripped to be a raw DOI'\n"
      guid = ::Regexp.last_match(2)
    end

    # the harvester also discovers the repository's OAI-PMH endpoint (e.g. from a signposted
    # describedby link) and merges its oai_datacite record into metadata.hash
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
    harvested = dabar_inst_creators_from_hash(metadata.hash)
    output.comments << "INFO: Found #{harvested.size} DataCite creator(s) in the harvested metadata.\n"
    creators.concat(harvested)

    if metadata.guidtype == 'doi'
      output.comments << "INFO: Now testing #{guid} for registration agency\n"
      agency = FAIRChampionHarvester::DOI.resolve_doi_to_registration_agency(guid, output)
      if agency == 'DataCite'
        from_doi = dabar_inst_creators_from_doi(guid, output)
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
      output.comments << "INDETERMINATE: No DataCite metadata with identifiable creators could be retrieved for #{guid}.\n"
      return output.createEvaluationResponse
    end

    creators.each do |c|
      if c[:affiliations].empty?
        output.comments << "INFO: Creator '#{c[:name]}' (#{c[:source]}) has no affiliation.\n"
        next
      end
      c[:affiliations].each do |a|
        name = a[:name].empty? ? '(no affiliation name)' : "'#{a[:name]}'"
        if a[:id].empty?
          output.comments << "INFO: Creator '#{c[:name]}' (#{c[:source]}) has affiliation #{name} " \
                             "with no affiliationIdentifier.\n"
        else
          scheme = a[:scheme].empty? ? 'no affiliationIdentifierScheme given' : "scheme #{a[:scheme]}"
          output.comments << "INFO: Creator '#{c[:name]}' (#{c[:source]}) has affiliation #{name} " \
                             "identified by '#{a[:id]}' (#{scheme}).\n"
        end
      end
    end

    identified = creators.select { |c| c[:affiliations].any? { |a| !a[:id].empty? } }
    if identified.any?
      output.score = 'pass'
      output.comments << "PASS: #{identified.size} of #{creators.size} creator(s) have an affiliation identified " \
                         "by a non-empty affiliationIdentifier.\n"
    else
      output.score = 'fail'
      output.comments << "FAIL: None of the #{creators.size} creator(s) has an affiliation with a non-empty " \
                         "affiliationIdentifier. Affiliations given only as text do not identify the institution.\n"
    end
    output.createEvaluationResponse
  end

  # ---------------------------------------------------------------------------
  # Creators from metadata.hash. An OAI-PMH oai_datacite record is merged there by
  # XmlSimple (ForceArray off): {"creators"=>{"creator"=>Hash|Array}}, where each
  # affiliation is a String (text only) or {"affiliationIdentifier"=>..., "content"=>...}.
  # DataCite JSON, if present, gives {"creators"=>[{"name"=>..., "affiliation"=>[...]}]}.
  # ---------------------------------------------------------------------------
  def self.dabar_inst_creators_from_hash(hash)
    return [] unless hash.is_a?(Hash)

    block = hash['creators']
    entries = if block.is_a?(Hash) then dabar_inst_list(block['creator'])
              elsif block.is_a?(Array) then block
              else []
              end
    entries.filter_map do |creator|
      next unless creator.is_a?(Hash)

      name = dabar_inst_text(creator['creatorName'])
      name = creator['name'].to_s.strip if name.empty?
      name = [creator['givenName'], creator['familyName']].compact.join(' ').strip if name.empty?
      affiliations = dabar_inst_list(creator['affiliation']).map do |a|
        if a.is_a?(Hash)
          { name: (a['content'] || a['name']).to_s.strip, id: a['affiliationIdentifier'].to_s.strip,
            scheme: a['affiliationIdentifierScheme'].to_s.strip }
        else
          { name: a.to_s.strip, id: '', scheme: '' }
        end
      end
      { name: name.empty? ? '(unnamed)' : name, affiliations: affiliations, source: 'harvested metadata' }
    end
  end

  # creators from DataCite XML, obtained by content negotiation on the DOI;
  # nil if the XML could not be retrieved or parsed
  def self.dabar_inst_creators_from_doi(doi, output)
    url = "https://doi.org/#{doi.downcase.strip}"
    output.comments << "INFO: Resolving #{url} as DataCite XML for creator affiliations\n"
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
      affiliations = creator.xpath('./affiliation').map do |a|
        { name: a.text.to_s.strip, id: a['affiliationIdentifier'].to_s.strip,
          scheme: a['affiliationIdentifierScheme'].to_s.strip }
      end
      { name: name.empty? ? '(unnamed)' : name, affiliations: affiliations, source: 'DataCite XML from DOI' }
    end
  rescue Nokogiri::XML::SyntaxError
    output.comments << "WARN: The DataCite response for #{doi} was not well-formed XML.\n"
    nil
  end

  def self.dabar_inst_list(x)
    return [] if x.nil?

    x.is_a?(Array) ? x : [x]
  end

  def self.dabar_inst_text(node)
    (node.is_a?(Hash) ? node['content'] : node).to_s.strip
  end

  def self.dabar_institutional_identification_api
    api = FtrRuby::OpenAPI.new(meta: dabar_institutional_identification_meta)
    api.get_api
  end

  def self.dabar_institutional_identification_about
    dcat = FtrRuby::DCAT_Record.new(meta: dabar_institutional_identification_meta)
    dcat.get_dcat
  end
end
