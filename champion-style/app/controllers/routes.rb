require 'json' # ensure json stdlib is loaded
require 'yaml'
require 'erb'

def set_routes(classes: [])
  set :server_settings, timeout: 180
  set :public_folder, File.join(__dir__, '../public')
  set :port, 8282

  get '/' do
    content_type :json
    response.body = JSON.dump(Swagger::Blocks.build_root_json(classes))
  end

  # get '/community-tests' do
  #   redirect '/community-tests/'
  # end
  get %r{/community-tests/?} do
    ts = Dir["#{File.dirname(__FILE__)}/../tests/*.rb"]
    @tests = ts.map { |t| t.match(%r{.*/(\S+)\.rb$})[1] } # This is just the final field in the URL
    @labels = FAIRChampion::Harvester.get_tests_metrics(tests: @tests) # the local URL is built in this routine, and called
    halt erb :listtests, layout: :listtests_layout
  end

  # post '/community-tests/assess/test/:id' do
  #   fullpath = request.fullpath.to_s
  #   # not sure how this is going to respond, now...
  #   fullpath.gsub!(%r{^/community-tests}, '') # due to new API calls that must befin with "assess" instead of "tests"
  #   status 307
  #   headers['Location'] = fullpath
  #   ''
  # end

  post '/community-tests/assess/test/:id' do
    content_type :json
    id = params[:id]
    guid = ''
    if params['resource_identifier']
      guid = params['resource_identifier']
    else
      payload = JSON.parse(request.body.read)
      guid = payload['resource_identifier']
    end
    warn "now testing #{guid}"
    # begin
    @result = FAIRTest.send(id, guid: guid) # @result is a json STRING!

    if request.accept?('text/html') || request.accept?('application/xhtml+xml')
      content_type :html
      data = JSON.parse(@result)
      @test_execution = data['@graph'].find { |g| g['@type'] == 'ftr:TestExecutionActivity' }
      @test = data['@graph'].find { |g| g['@id'] == @test_execution['prov:wasAssociatedWith']['@id'] }
      @metric_implementation = @test['sio:SIO_000233'] # Extract SIO_000233
      @test_result = data['@graph'].find { |g| g['@type'] == 'ftr:TestResult' }
      @result_value = @test_result['prov:value']['@value'] # Extract pass/fail
      halt erb :testresult
    else
      # Assume JSON/LD — most permissive path
      content_type 'application/ld+json'
      halt @result
    end
    error 406
  end

  # ============================= GET ----
  # ============================= GET ----
  # ============================= GET ----
  # ============================= GET ----

  get '/community-tests/:id' do # returns DCAT
    warn "get '/community-tests/:id'"
    id = params[:id]
    idabout = "#{id}_about"
    begin
      warn "get #{idabout}"
      graph = FAIRTest.send(idabout)
    rescue StandardError
      halt 404, { 'error' => "Invalid test ID: #{params[:id]}" }.to_json
    end

    request.accept.each do |type|
      case type.to_s
      when 'text/turtle'
        content_type 'text/turtle'
        halt graph.dump(:turtle)
      when 'application/json'
        content_type :json
        halt graph.dump(:jsonld)
      when 'application/ld+json'
        content_type 'application/ld+json'
        halt graph.dump(:jsonld)
      else # for the FDP index send turtle by default
        content_type 'text/turtle'
        halt graph.dump(:turtle)
      end
    end
  end

  get '/community-tests/:id/api' do # return swagger
    content_type 'application/openapi+yaml'
    id = params[:id]
    idapi = id + '_api'
    begin
      @result = FAIRTest.send(idapi)
    rescue StandardError
      halt 404, { 'error' => "Invalid test ID: #{params[:id]}" }.to_json
    end
    @result
  end
end

# get '/community-tests/fdpindex_tests/' do
#   @testobjects = FAIRChampion::Index.retrieve_tests_from_index
#   @labels = FAIRChampion::Index.get_metrics_labels_for_tests(tests: @testobjects)
#   halt erb :listalltests, layout: :listtests_layout
# end

# get '/community-tests/new' do
#   halt erb :newtest, layout: :newtest_layout
# end

# post '/community-tests/new' do
#   test_uri = params['test_uri']
#   @result = FAIRChampion::Tests.register_test(test_uri: test_uri)
#   halt erb :newtest_output, layout: :newtest_layout
# end
