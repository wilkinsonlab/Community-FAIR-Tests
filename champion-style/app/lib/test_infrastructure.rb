module FAIRChampion
  class TestInfra
    # there is a need to map between a test and its registered Metric in FS.  This will return the label for the test
    # in principle, we cojuld return a more complex object, but all I need now is the label
    def self.get_tests_metrics(tests:)
      base_url = ENV['TEST_BASE_URL'] || 'http://localhost:8282' # Default to local server
      test_path = ENV['TEST_PATH'] || 'community-tests' # Default to local server
      labels = {}
      landingpages = {}
      tests.each do |testid|
        warn "getting dcat for #{testid}    #{base_url}/#{test_path}/#{testid}"
        dcat = RestClient::Request.execute({
                                             method: :get,
                                             url: "#{base_url}/#{test_path}/#{testid}",
                                             headers: { 'Accept' => 'application/json' }
                                           }).body
        parseddcat = JSON.parse(dcat)
        jpath = JsonPath.new('[0]["http://semanticscience.org/resource/SIO_000233"][0]["@id"]') # is implementation of
        metricurl = jpath.on(parseddcat).first

        begin
          g = RDF::Graph.load(metricurl, format: :turtle)
        rescue StandardError => e
          warn "DCAT Metric loading failed #{e.inspect}"
          g = RDF::Graph.new
        end

        title = g.query([nil, RDF::Vocab::DC.title, nil])&.first&.object&.to_s
        lp = g.query([nil, RDF::Vocab::DCAT.landingPage, nil])&.first&.object&.to_s

        labels[testid] = if title != ''
                           title
                         else
                           'Metric label not available'
                         end
        landingpages[testid] = if lp != ''
                                 lp
                               else
                                 ''
                               end
      end
      [labels, landingpages]
    end
  end
end
