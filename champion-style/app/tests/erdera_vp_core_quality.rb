class FAIRTest
  def self.erdera_vp_core_quality_meta
    {
      testversion: HARVESTER_VERSION + ':' + 'Tst-0.0.1',
      testname: 'ERDERA: Quality Control of Title and Description for Virtual Platform Onboarding',
      testid: 'erdera_vp_core_quality',
      description: "The ERDERA Project has strict requirements for minimal metadata to onboard their Virtual Platform.
                    Titles and descriptions are used for discovery, so this test checks that they contain words a
                    searcher could actually use. The title must contain at least 1 distinctive word, and the
                    description must contain at least 2 distinctive words that do not already appear in the title.
                    A distinctive word is any word that is not generic: English stopwords, record-type nouns
                    (dataset, catalog, registry...), placeholders (test, TBD, lorem ipsum...), words shared by every
                    ERDERA record (rare, disease, patients, research...) and promotional filler (comprehensive,
                    valuable, provides...). The full word lists are in the test source:
                    https://github.com/wilkinsonlab/Community-FAIR-Tests/blob/main/champion-style/app/tests/erdera_vp_core_quality.rb
                    Titles are read from dct:title, dc:title or schema:name, and descriptions from dct:description,
                    dc:description or schema:description. If there are several values (e.g. one per language), one
                    qualifying title and one qualifying description are enough.",
      metric: 'https://w3id.org/fair-metrics/erdera/FM_R1-3_M_VP_CORE',
      indicators: 'https://w3id.org/fair-metrics/erdera/FM_R1-3_M_VP_CORE',
      type: 'http://edamontology.org/operation_2428',
      license: 'https://creativecommons.org/publicdomain/zero/1.0/',
      keywords: ['FAIR Assessment', 'FAIR Principles', 'FAIR', 'R1.3', 'metadata', 'ERDERA',
                 'virtual platform', 'metadata quality', 'discovery'],
      themes: ['http://edamontology.org/topic_4012'],
      organization: 'ERDERA Project',
      org_url: 'https://erdera.org/',
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

  # Thresholds and word lists were calibrated against the labelled corpus in
  # spec/fixtures/erdera_vp_core_calibration.yml (see spec/tests/erdera_vp_core_quality_spec.rb).
  # Change them only together with that corpus.
  ERDERA_VP_CORE_MIN_TITLE_WORDS = 1        # distinctive words in a title
  ERDERA_VP_CORE_MIN_DESCRIPTION_WORDS = 2  # distinctive words in a description that are not in the title

  ERDERA_VP_CORE_STOPWORDS = %w[
    a an the this that these those is are was were be been being it its of in on at to for from by with and or
    but not no as into than then there here our your their my we you they he she i me us them which who whom
    whose what where when how all any each other some such can could may might will would should shall do does
    did has have had also about over under between across up out so very more most
  ].freeze
  # words every registration shares, so they say nothing about *which* resource this is
  ERDERA_VP_CORE_RECORD_TYPES = %w[
    dataset datasets data catalog catalogs catalogue catalogues resource resources metadata fdp fair point points
    service services distribution distributions repository repositories collection collections information
    record records registry registries biobank biobanks database databases platform portal
  ].freeze
  ERDERA_VP_CORE_PLACEHOLDERS = %w[
    test testing tests demo example examples untitled new copy final draft tbd todo tba none na description title
    name lorem ipsum dolor sit amet consectetur adipiscing elit sample
  ].freeze
  # generic in the ERDERA domain: everything registered there is about rare-disease research
  ERDERA_VP_CORE_DOMAIN_WORDS = %w[rare disease diseases patient patients research researchers clinical health
                                   medical].freeze
  # fluent filler typical of promotional or LLM-written text
  ERDERA_VP_CORE_FILLER = %w[
    provides provide providing offers offer contains contain containing includes include including comprehensive
    valuable useful high quality various wide range insights access available allows allow users search browse
    retrieve used use purposes purpose stakeholders clinicians advance improve outcomes field care way
    organisation organization collecting collected exposing
  ].freeze
  ERDERA_VP_CORE_GENERIC = (ERDERA_VP_CORE_STOPWORDS + ERDERA_VP_CORE_RECORD_TYPES + ERDERA_VP_CORE_PLACEHOLDERS +
                            ERDERA_VP_CORE_DOMAIN_WORDS + ERDERA_VP_CORE_FILLER).to_h { |w| [w, true] }.freeze

  ERDERA_VP_CORE_TITLE_PREDICATES = %w[
    http://purl.org/dc/terms/title
    http://purl.org/dc/elements/1.1/title
    http://schema.org/name
    https://schema.org/name
  ].freeze
  ERDERA_VP_CORE_DESCRIPTION_PREDICATES = %w[
    http://purl.org/dc/terms/description
    http://purl.org/dc/elements/1.1/description
    http://schema.org/description
    https://schema.org/description
  ].freeze

  def self.erdera_vp_core_quality(guid:)
    FtrRuby::Output.clear_comments

    output = FtrRuby::Output.new(
      testedGUID: guid,
      meta: erdera_vp_core_quality_meta
    )
    output.comments << "INFO: TEST VERSION '#{erdera_vp_core_quality_meta[:testversion]}'\n"

    guid = guid.strip
    metadata = FAIRChampionHarvester::Core.resolveit(guid)
    metadata.comments.each do |c|
      output.comments << c
    end

    if metadata.guidtype == 'unknown'
      output.score = 'indeterminate'
      output.comments << "INDETERMINATE: The identifier #{guid} did not match any known identification system. " \
                         "Testing cannot continue\n"
      return output.createEvaluationResponse
    end

    graph = metadata.graph
    if graph.nil? || graph.empty?
      output.score = 'indeterminate'
      output.comments << "INDETERMINATE: No linked-data metadata could be harvested for #{guid}, " \
                         "so its title and description cannot be assessed.\n"
      return output.createEvaluationResponse
    end

    subjects = erdera_vp_core_subjects(metadata, guid)
    output.comments << "INFO: Assessing the title and description of: #{subjects.join(', ')}\n"

    titles = erdera_vp_core_literals(graph, subjects, ERDERA_VP_CORE_TITLE_PREDICATES)
    descriptions = erdera_vp_core_literals(graph, subjects, ERDERA_VP_CORE_DESCRIPTION_PREDICATES)
    title_texts = titles.map { |t| t[:value] }

    good_title = false
    if titles.empty?
      output.comments << "WARN: No title (dct:title, dc:title or schema:name) was found.\n"
    else
      titles.each do |t|
        words = erdera_vp_core_distinctive_words(t[:value])
        ok = words.size >= ERDERA_VP_CORE_MIN_TITLE_WORDS
        good_title ||= ok
        output.comments << "#{ok ? 'INFO' : 'WARN'}: Title #{erdera_vp_core_describe(t)} has " \
                           "#{erdera_vp_core_word_note(words)} (at least #{ERDERA_VP_CORE_MIN_TITLE_WORDS} required).\n"
      end
    end

    good_description = false
    if descriptions.empty?
      output.comments << "WARN: No description (dct:description, dc:description or schema:description) was found.\n"
    else
      descriptions.each do |d|
        words = erdera_vp_core_new_words(d[:value], title_texts)
        ok = words.size >= ERDERA_VP_CORE_MIN_DESCRIPTION_WORDS
        good_description ||= ok
        output.comments << "#{ok ? 'INFO' : 'WARN'}: Description #{erdera_vp_core_describe(d, 60)} adds " \
                           "#{erdera_vp_core_word_note(words)} not already in the title " \
                           "(at least #{ERDERA_VP_CORE_MIN_DESCRIPTION_WORDS} required).\n"
      end
    end

    if good_title && good_description
      output.score = 'pass'
      output.comments << "PASS: The title and the description both contain enough distinctive words to support discovery.\n"
    else
      problems = []
      problems << "no title with at least #{ERDERA_VP_CORE_MIN_TITLE_WORDS} distinctive word" unless good_title
      unless good_description
        problems << "no description adding at least #{ERDERA_VP_CORE_MIN_DESCRIPTION_WORDS} distinctive words " \
                    'beyond the title'
      end
      output.score = 'fail'
      output.comments << "FAIL: The record does not meet the ERDERA metadata quality requirements: #{problems.join(' and ')}. " \
                         'Generic words (dataset, catalog, test, rare disease, comprehensive...) do not count, ' \
                         "because they do not help anyone find this resource.\n"
    end
    output.createEvaluationResponse
  end

  # The resource assessed is the one the GUID identifies: the GUID itself and any
  # URI it resolved to, as the Index assesses each registered resource on its own.
  def self.erdera_vp_core_subjects(metadata, guid)
    ([guid] + metadata.finalURI.to_a.map(&:to_s)).map(&:strip).reject(&:empty?).uniq
  end

  # @return [Array<Hash>] {value:, lang:, predicate:} for every literal object of
  #   one of +predicates+ on one of +subjects+
  def self.erdera_vp_core_literals(graph, subjects, predicates)
    subject_uris = subjects.map { |s| RDF::URI(s) }
    predicate_uris = pred
    icates.map { |p| RDF::URI(p) }
    found = []
    graph.each_statement do |st|
      next unless subject_uris.include?(st.subject) && predicate_uris.include?(st.predicate)
      next unless st.object.literal?

      found << { value: st.object.value.to_s, lang: st.object.language&.to_s, predicate: st.predicate.to_s }
    end
    found.uniq
  end

  # lowercase word tokens; hyphenated names are split ("BBMRI-ERIC" -> bbmri, eric),
  # and pure numbers and version tags (2024, v2) are dropped
  def self.erdera_vp_core_tokens(text)
    text.to_s.downcase.split(/[^\p{L}\p{N}']+/).map { |t| t.gsub(/\A'+|'+\z/, '') }
                                               .reject { |t| t.empty? || t.match?(/\A[\d_]+\z/) || t.match?(/\Av\d+\z/) }
  end

  # distinct words that are not generic, in order of first appearance
  def self.erdera_vp_core_distinctive_words(text)
    erdera_vp_core_tokens(text).reject { |t| t.length < 2 || ERDERA_VP_CORE_GENERIC[t] }.uniq
  end

  # distinctive words of +description+ that appear in none of +titles+
  def self.erdera_vp_core_new_words(description, titles)
    erdera_vp_core_distinctive_words(description) - titles.flat_map { |t| erdera_vp_core_distinctive_words(t) }
  end

  def self.erdera_vp_core_word_note(words)
    return '0 distinctive words' if words.empty?

    "#{words.size} distinctive word(s): #{words.join(', ')}"
  end

  def self.erdera_vp_core_describe(literal, max = 80)
    text = literal[:value].to_s.gsub(/[[:space:]]+/, ' ').strip
    text = "#{text[0, max]}..." if text.length > max
    lang = literal[:lang] ? "@#{literal[:lang]}" : ''
    "'#{text}'#{lang} (#{literal[:predicate].split(%r{[/#]}).last})"
  end

  def self.erdera_vp_core_quality_api
    api = FtrRuby::OpenAPI.new(meta: erdera_vp_core_quality_meta)
    api.get_api
  end

  def self.erdera_vp_core_quality_about
    dcat = FtrRuby::DCAT_Record.new(meta: erdera_vp_core_quality_meta)
    dcat.get_dcat
  end
end
