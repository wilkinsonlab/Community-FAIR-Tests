require 'rest-client'
module FAIRChampion
  class Tests

    def self.register_test(test_uri:)
      warn "registering new test"
  #       curl -v -L -H "content-type: application/json" 
  # -d '{"clientUrl": "https://my.domain.org/path/to/DCAT/testdcat.ttl"}' 
  # https://tools.ostrails.eu/fdp-index-proxy/proxy 
      begin    
        response = RestClient::Request.execute({
                                      method: :post,
                                      url: "https://tools.ostrails.eu/fdp-index-proxy/proxy",
                                      headers: { 'Accept' => 'application/json', 'Content-Type' => "application/json" },
                                      payload: {"clientUrl": test_uri}.to_json
                                    }).body
      rescue StandardError => e
        warn "response is #{response.inspect} error #{e.inspect}"
      end
      response
    end
  end
end
