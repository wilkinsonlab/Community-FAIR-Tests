class FAIRTest
  def self.dv_portugal_dv_controlled_vocabularies_meta
    {
      testversion: HARVESTER_VERSION + ':' + 'Tst-0.0.3',
      testname: 'Dataverse Portugal Uses Dataverse Controlled Vocabularies',
      testid: 'dv_portugal_dv_controlled_vocabularies',
      description: 'The PT Dataverse controlled vocabularies metric evaluates compliance with the minimum domain relevant requirements established by the PT Dataverse community. The FM_R1-3_M_PtDataContVoc metric expects the use of a controlled vocabulary for the keywords metadata field, including the reference to the Term (a key term that describes important aspects of the dataset), Term URI (a URI that points to the web presence of the keyword term), Controlled Vocabulary Name (the controlled vocabulary used for the keyword term) and Controlled Vocabulary URL (the URL where one can access information about the term’s controlled vocabulary).
The evaluation of this principle is relevant to the PT Dataverse community as it contributes to improving the quality of digital object descriptions, ensuring they are both understandable across different research communities and machine‑readable. This, in turn, facilitates data interoperability, integration, and consistent indexing across diverse systems.',
      metric: 'https://ostrails.github.io/assessment-component-metadata-records/metric/FM_R1-3_M_PtDataContVoc.ttl',
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

  def self.dv_portugal_dv_controlled_vocabularies(guid:)
    FtrRuby::Output.clear_comments

    output = FtrRuby::Output.new(
      testedGUID: guid,
      meta: dv_portugal_dv_controlled_vocabularies_meta
    )
    output.comments << "INFO: TEST VERSION '#{dv_portugal_dv_controlled_vocabularies_meta[:testversion]}'\n"

    guid = guid.strip
    if guid.match(%r{\Ahttps?://(dx\.)?doi\.org/(.+)\z}i)
      output.comments << "INFO: incoming guid stripped to be a raw DOI'\n"
      guid = ::Regexp.last_match(2)
    end

    output = FtrRuby::Output.new(
      testedGUID: guid,
      meta: dv_portugal_dv_controlled_vocabularies_meta
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

    # The controlled-vocabulary details for a Dataverse "Keyword" field (Term,
    # Term URI, Controlled Vocabulary Name, Controlled Vocabulary URL) are not
    # exposed in the DataCite XML or in the page's schema.org/JSON-LD block —
    # DataCite/JSON-LD only ever give a flat list of keyword strings. They ARE
    # rendered, however, in the "Metadata" tab of the Dataverse dataset landing
    # page itself, inside a `<tr id="metadata_keyword">` table row. The generic
    # harvester (FAIRChampionHarvester::Core.resolveit, called above) already
    # fetched that landing page HTML while resolving the DOI and stashed every
    # HTTP response body it encountered in `metadata.full_response` — so rather
    # than doing a second, Dataverse-specific HTTP fetch, we just look for that
    # markup in what the harvester already retrieved.
    output.comments << 'INFO: Now scanning the harvested landing page content for a Dataverse ' \
                        "'Keyword' controlled-vocabulary metadata block\n"
    keyword_entries = find_dataverse_keyword_entries(metadata, output)
    if keyword_entries.nil?
      output.score = 'indeterminate'
      output.comments << "INDETERMINATE: Could not find a Dataverse 'Keyword' metadata block " \
                          "(no '\#metadata_keyword' table row) anywhere in the harvested content for #{guid}. " \
                          "This test only applies to Dataverse dataset landing pages.\n"
      return output.createEvaluationResponse
    end
    if keyword_entries.empty?
      output.score = 'fail'
      output.comments << "FAIL: A Dataverse 'Keyword' metadata block was found, but it did not contain " \
                          "any keyword terms.\n"
      return output.createEvaluationResponse
    end

    # A keyword entry is considered to use a controlled vocabulary when it carries
    # both the vocabulary's name and the URL where that vocabulary can be looked
    # up. The "Term URI" sub-field (a URI for the specific term, e.g. a concept
    # page) is part of the Dataverse schema and is reported below when present,
    # but real-world PT Dataverse depositors very rarely populate it -- even the
    # community's own positive example dataset omits it -- so it is not treated
    # as a hard requirement for a pass here.
    keyword_entries.each do |entry|
      compliance = if entry[:vocab_name] && entry[:vocab_url]
                     'USES a controlled vocabulary'
                   else
                     'does NOT use a controlled vocabulary'
                   end
      term_uri_note = entry[:term_uri] ? ", term URI: #{entry[:term_uri]}" : ', no term URI given'
      output.comments << "INFO: Keyword '#{entry[:term]}' #{compliance} " \
                          "(vocabulary: #{entry[:vocab_name] || 'none'}, " \
                          "vocabulary URL: #{entry[:vocab_url] || 'none'}#{term_uri_note})\n"
    end

    compliant_terms = keyword_entries.select { |entry| entry[:vocab_name] && entry[:vocab_url] }
    if compliant_terms.any?
      output.score = 'pass'
      output.comments << "PASS: At least one keyword (#{compliant_terms.map { |e| e[:term] }.join(', ')}) " \
                          "references a controlled vocabulary by name and URL.\n"
    else
      output.score = 'fail'
      output.comments << "FAIL: None of the #{keyword_entries.size} keyword(s) found reference a controlled " \
                          "vocabulary (a Controlled Vocabulary Name and URL are both required).\n"
    end
    output.createEvaluationResponse
  end

  # Searches every response body the harvester collected while resolving the
  # GUID (metadata.full_response) for a Dataverse dataset landing page's
  # "Metadata" tab keyword table (`<tr id="metadata_keyword">`), and returns
  # the parsed keyword entries from the first one found.
  #
  # Returns:
  #   nil        - no `#metadata_keyword` block was found in any harvested body
  #   [] / [...] - the block was found; an array of keyword entry hashes
  #                (possibly empty, if the block existed but held no keywords)
  def self.find_dataverse_keyword_entries(metadata, output)
    metadata.full_response.each do |body|
      next unless body.is_a?(String)

      doc = Nokogiri::HTML(body)
      td = doc.at_css('#metadata_keyword td')
      next unless td

      output.comments << "INFO: Found a Dataverse 'Keyword' metadata block.\n"
      return parse_dataverse_keyword_cell(td)
    end
    nil
  end

  # Parses the <td> of a Dataverse `#metadata_keyword` table row into individual
  # keyword entries. Dataverse renders each keyword's compound sub-fields
  # (Term, Term URI, Controlled Vocabulary Name, Controlled Vocabulary URL) as
  # a single run of text/markup, and separates multiple keywords with <br>
  # tags, e.g.:
  #
  #   Trade Unions (ELSST) "<a href="...">https://thesauri.cessda.eu/elsst-3/en/</a>"
  #   <br>
  #   Employers' Organizations (ELSST) "<a href="...">https://thesauri.cessda.eu/elsst-3/en/</a>"
  #
  # Note: Dataverse's own HTML template double-escapes the quotes around the
  # href attribute (`href=""https://...""`), which breaks the `href` attribute
  # itself when parsed. The visible link TEXT is unaffected, though (Dataverse
  # renders the URL twice: once broken as the href, once correctly as the link
  # text), so this parses URLs from anchor text rather than the href attribute.
  def self.parse_dataverse_keyword_cell(cell)
    entries = []
    current_nodes = []
    cell.children.each do |node|
      if node.name == 'br'
        entries << current_nodes
        current_nodes = []
      else
        current_nodes << node
      end
    end
    entries << current_nodes

    entries.filter_map { |nodes| parse_dataverse_keyword_entry(nodes) }
  end

  # Parses one keyword's worth of nodes (everything between two <br> tags in
  # the keyword cell) into its Term / Term URI / Vocabulary Name / Vocabulary
  # URL components. Returns nil for empty entries (e.g. a trailing blank line).
  def self.parse_dataverse_keyword_entry(nodes)
    fragment = Nokogiri::HTML.fragment('')
    nodes.each { |node| fragment.add_child(node.dup) }
    full_text = fragment.text.strip
    return nil if full_text.empty?

    # The compound sub-fields are always rendered in this fixed order:
    # Term, then (optionally) a Term URI link, then (optionally) "(Vocabulary
    # Name)", then (optionally) a Vocabulary URL link. So: of up to two links
    # present, one before the "(...)" is the Term URI, and one after it (or
    # the only one, if there is no "(...)") is the Vocabulary URL.
    anchor_texts = fragment.css('a').map(&:text)
    vocab_match = full_text.match(/\(([^)]+)\)/)
    vocab_name = vocab_match && vocab_match[1].strip

    term_uri = nil
    vocab_url = nil
    if anchor_texts.size == 2
      term_uri, vocab_url = anchor_texts
    elsif anchor_texts.size == 1
      if vocab_match && full_text.index(anchor_texts.first).to_i < vocab_match.begin(0)
        term_uri = anchor_texts.first
      else
        vocab_url = anchor_texts.first
      end
    end

    term = full_text.split(/[("]/).first.to_s.strip

    { term: term, term_uri: term_uri, vocab_name: vocab_name, vocab_url: vocab_url }
  end

  def self.dv_portugal_dv_controlled_vocabularies_api
    api = FtrRuby::OpenAPI.new(meta: dv_portugal_dv_controlled_vocabularies_meta)
    api.get_api
  end

  def self.dv_portugal_dv_controlled_vocabularies_about
    # warn "META: #{dv_portugal_dv_controlled_vocabularies_meta.inspect}"
    dcat = FtrRuby::DCAT_Record.new(meta: dv_portugal_dv_controlled_vocabularies_meta)
    dcat.get_dcat
  end
end
