module RackTestHelper
  def json_response
    JSON.parse(last_response.body, symbolize_names: true)
  rescue JSON::ParserError
    last_response.body
  end
end