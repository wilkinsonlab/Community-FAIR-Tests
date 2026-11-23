require_relative '../spec_helper'
require 'yaml'

# Runs the labelled calibration corpus through the test's own scoring helpers, so
# the thresholds and word lists in app/tests/erdera_vp_core_quality.rb stay
# justified: every "junk" entry must fail, every "ok"/"good" entry must pass.
RSpec.describe 'erdera_vp_core_quality scoring' do
  corpus = YAML.load_file(File.expand_path('../fixtures/erdera_vp_core_calibration.yml', __dir__))

  def title_passes?(title)
    FAIRTest.erdera_vp_core_distinctive_words(title).size >= FAIRTest::ERDERA_VP_CORE_MIN_TITLE_WORDS
  end

  def description_passes?(text, title)
    FAIRTest.erdera_vp_core_new_words(text, [title]).size >= FAIRTest::ERDERA_VP_CORE_MIN_DESCRIPTION_WORDS
  end

  corpus['titles'].each do |label, titles|
    titles.each do |title|
      expectation = label == 'junk' ? 'fails' : 'passes'
      it "title #{expectation} (#{label}): #{title.inspect}" do
        expect(title_passes?(title)).to eq(label != 'junk')
      end
    end
  end

  corpus['descriptions'].each do |label, entries|
    entries.each do |entry|
      expectation = label == 'junk' ? 'fails' : 'passes'
      it "description #{expectation} (#{label}): #{entry['text'][0, 60].inspect}" do
        expect(description_passes?(entry['text'], entry['title'])).to eq(label != 'junk')
      end
    end
  end

  it 'compares a description against every title the record has' do
    expect(FAIRTest.erdera_vp_core_new_words('Registry of Duchenne patients in Spain',
                                             ['Duchenne registry', 'Neuromuscular registry of Spain']))
      .to eq([])
  end

  it 'splits hyphenated names and drops numbers and version tags' do
    expect(FAIRTest.erdera_vp_core_tokens('BBMRI-ERIC dataset_v2_final 2024')).to eq(%w[bbmri eric dataset final])
  end

  # Regression test: erdera_vp_core_literals is the only method the calibration corpus
  # above never exercises (it only drives the pure text-scoring helpers) - a hard syntax
  # error here (`predicates` accidentally split across two lines, raising NameError on
  # every call) still passed all 88 corpus examples and only surfaced live, as a bare 500
  # from erdera_vp_core_quality itself, confirmed 2026-11-23.
  it 'extracts literal values for the given subjects and predicates from a real graph' do
    graph = RDF::Graph.new
    subject = RDF::URI('https://example.org/dataset/1')
    graph << [subject, RDF::URI('http://purl.org/dc/terms/title'), RDF::Literal('A real dataset title')]
    graph << [subject, RDF::URI('http://purl.org/dc/terms/description'), RDF::Literal('Unrelated predicate')]

    result = FAIRTest.erdera_vp_core_literals(graph, [subject.to_s], FAIRTest::ERDERA_VP_CORE_TITLE_PREDICATES)

    expect(result).to eq([{ value: 'A real dataset title', lang: nil,
                             predicate: 'http://purl.org/dc/terms/title' }])
  end
end
