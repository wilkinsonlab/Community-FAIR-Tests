# frozen_string_literal: false

require 'swagger/blocks'
require 'sinatra'
require 'sinatra/base'
require 'json'
require 'erb'
require 'require_all'
require 'jsonpath'
require 'dotenv/load' unless ENV['RACK_ENV'] == 'production'

require_rel './routes.rb'
require_rel '../models'
require_rel '../views'
require_rel '../tests'
require_rel '../lib'

if defined?(Rack::Timeout)
  use Rack::Timeout, service_timeout: 600 # 10 minutes; adjust as needed
  # Or via ENV: ENV['RACK_TIMEOUT_SERVICE_TIMEOUT'] = '600'
end

class JSON::Ext::Generator::State
  # monkey patch due to incompatibilities between linkeddata gem and json-ld
  def except(*keys)
    # Convert to real Hash, drop keys, then reconstruct (safe since to_h exists)
    to_h.except(*keys)
  end
end

class ApplicationController < Sinatra::Application
  include Swagger::Blocks

  set :bind, '0.0.0.0'
  before do
    response.headers['Access-Control-Allow-Origin'] = '*'
  end

  configure do
    set :public_folder, 'public'
    set :views, 'app/views'
    enable :cross_origin
  end

  options '*' do
    response.headers['Allow'] = 'GET, PUT, POST, DELETE, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Authorization, Content-Type, Accept, X-User-Email, X-Auth-Token'
    response.headers['Access-Control-Allow-Origin'] = '*'
    200
  end

  swagger_root do
    key :swagger, '2.0'
    info do
      key :version, '1.0.0'
      key :title, 'FAIR Core Tests'
      key :description, 'The core set of FAIR tests used by the FAIR Champion evaluation platform'
      key :termsOfService, 'https://example.org'
      contact do
        key :name, 'Mark D. Wilkinson'
      end
      license do
        key :name, 'MIT'
      end
    end
    key :schemes, ['http']
    key :host, ENV.fetch('HARVESTER', nil)
    key :basePath, '/tests/'
  end

  SWAGGERED_CLASSES = [ErrorModel, self].freeze

  set_routes(classes: SWAGGERED_CLASSES)
end
