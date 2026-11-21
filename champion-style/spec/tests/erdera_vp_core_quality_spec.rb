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
end
