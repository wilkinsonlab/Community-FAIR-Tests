class FAIRTest
  def self.dabar_grant_identification_meta
    {
      testversion: HARVESTER_VERSION + ':' + 'Tst-0.0.2',
      testname: 'DABAR: Grant identified by funder name and award number in DataCite metadata',
      testid: 'dabar_grant_identification',
      description: 'Retrieves the DataCite metadata for a record (oai_datacite via the repository OAI-PMH
                    endpoint, e.g. from a signposted describedby link, and/or DataCite XML for a DataCite DOI)
                    and checks whether at least one datacite:fundingReference identifies a grant by giving BOTH
                    a non-empty funderName and a non-empty awardNumber. The awardTitle is reported when present
                    but is not required. A funding reference that gives only one of funder name and award number
                    does not identify the grant.',
      metric: 'https://ostrails.github.io/assessment-component-metadata-records/metric/FM_R1.2_M_Grant_id.ttl',
      indicators: 'https://ostrails.github.io/assessment-component-metadata-records/metric/FM_R1.2_M_Grant_id.ttl',
      type: 'http://edamontology.org/operation_2428',
      license: 'https://creativecommons.org/publicdomain/zero/1.0/',
      keywords: ['FAIR Assessment', 'FAIR Principles', 'funding', 'grant', 'DataCite', 'DABAR'],
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

  def self.dabar_grant_identification(guid:)
    FtrRuby::Output.clear_comments

    output = FtrRuby::Output.new(
      testedGUID: guid,
      meta: dabar_grant_identification_meta
    )
    output.comments << "INFO: TEST VERSION '#{dabar_grant_identification_meta[:testversion]}'\n"

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

    refs = []
    output.comments << "INFO: Looking for DataCite fundingReferences in the harvested metadata (e.g. an OAI-PMH oai_datacite record).\n"
    harvested = dabar_grant_refs_from_hash(metadata.hash)
    output.comments << "INFO: Found #{harvested.size} fundingReference(s) in the harvested metadata.\n"
    refs.concat(harvested)

    if metadata.guidtype == 'doi'
      output.comments << "INFO: Now testing #{guid} for registration agency\n"
      agency = FAIRChampionHarvester::DOI.resolve_doi_to_registration_agency(guid, output)
      if agency == 'DataCite'
        from_doi = dabar_grant_refs_from_doi(guid, output)
        if from_doi.nil?
          output.comments << "WARN: DataCite XML could not be retrieved or parsed for #{guid}.\n"
        else
          output.comments << "INFO: Found #{from_doi.size} fundingReference(s) in the DataCite XML for #{guid}.\n"
          refs.concat(from_doi)
        end
      else
        output.comments << "INFO: The DOI registration agency is #{agency || 'unknown'}, not DataCite; " \
                           "no DataCite XML is available from the DOI itself.\n"
      end
    end

    informative = refs.reject { |r| r[:funder].empty? && r[:award].empty? && r[:title].empty? }
    if informative.empty?
      output.score = 'indeterminate'
      output.comments << "INDETERMINATE: No DataCite funding information (funderName, awardNumber or awardTitle) " \
                         "could be found for #{guid}.\n"
      return output.createEvaluationResponse
    end

    informative.each do |r|
      parts = []
      parts << "funder '#{r[:funder]}'" unless r[:funder].empty?
      parts << "award number '#{r[:award]}'" unless r[:award].empty?
      parts << "award title '#{r[:title]}'" unless r[:title].empty?
      missing = []
      missing << 'funderName' if r[:funder].empty?
      missing << 'awardNumber' if r[:award].empty?
      note = missing.empty? ? 'identifies a grant' : "does not identify a grant (missing #{missing.join(' and ')})"
      output.comments << "INFO: fundingReference (#{r[:source]}) with #{parts.join(', ')} #{note}.\n"
    end

    identified = informative.select { |r| !r[:funder].empty? && !r[:award].empty? }
    if identified.any?
      output.score = 'pass'
      output.comments << "PASS: #{identified.size} of #{informative.size} fundingReference(s) identify a grant " \
                         "with both a funder name and an award number.\n"
    else
      output.score = 'fail'
      output.comments << "FAIL: Funding information was found, but no fundingReference gives both a funder name " \
                         "and an award number, so no grant can be identified.\n"
    end
    output.createEvaluationResponse
  end

  # ---------------------------------------------------------------------------
  # fundingReferences from metadata.hash. An OAI-PMH oai_datacite record is merged
  # there by XmlSimple (ForceArray off): {"fundingReferences"=>{"fundingReference"=>Hash|Array}};
  # DataCite JSON, if present, gives {"fundingReferences"=>[{...}]}.
  # ---------------------------------------------------------------------------
  def self.dabar_grant_refs_from_hash(hash)
    return [] unless hash.is_a?(Hash)

    block = hash['fundingReferences']
    entries = if block.is_a?(Hash) then dabar_grant_list(block['fundingReference'])
              elsif block.is_a?(Array) then block
              else []
              end
    entries.filter_map do |ref|
      next unless ref.is_a?(Hash)

      { funder: dabar_grant_text(ref['funderName']), award: dabar_grant_text(ref['awardNumber']),
        title: dabar_grant_text(ref['awardTitle']), source: 'harvested metadata' }
    end
  end

  # fundingReferences from DataCite XML, obtained by content negotiation on the DOI;
  # nil if the XML could not be retrieved or parsed
  def self.dabar_grant_refs_from_doi(doi, output)
    url = "https://doi.org/#{doi.downcase.strip}"
    output.comments << "INFO: Resolving #{url} as DataCite XML for funding references\n"
    _headers, body = FAIRChampionHarvester::Core.fetch(
      guid: url,
      headers: { 'Accept' => 'application/vnd.datacite.datacite+xml' }
    )
    return nil unless body

    doc = Nokogiri::XML(body) { |config| config.strict.nonet }
    doc.remove_namespaces!
    return nil unless doc.at_xpath('//resource')

    doc.xpath('//fundingReferences/fundingReference').map do |ref|
      { funder: ref.at_xpath('./funderName')&.text.to_s.strip, award: ref.at_xpath('./awardNumber')&.text.to_s.strip,
        title: ref.at_xpath('./awardTitle')&.text.to_s.strip, source: 'DataCite XML from DOI' }
    end
  rescue Nokogiri::XML::SyntaxError
    output.comments << "WARN: The DataCite response for #{doi} was not well-formed XML.\n"
    nil
  end

  def self.dabar_grant_list(x)
    return [] if x.nil?

    x.is_a?(Array) ? x : [x]
  end

  # XmlSimple gives a String for an element without attributes, or {"content"=>...}
  # when it has attributes (e.g. awardNumber awardURI="..."); first value if repeated
  def self.dabar_grant_text(node)
    node = node.first if node.is_a?(Array)
    (node.is_a?(Hash) ? node['content'] : node).to_s.strip
  end

  def self.dabar_grant_identification_api
    api = FtrRuby::OpenAPI.new(meta: dabar_grant_identification_meta)
    api.get_api
  end

  def self.dabar_grant_identification_about
    dcat = FtrRuby::DCAT_Record.new(meta: dabar_grant_identification_meta)
    dcat.get_dcat
  end
end
