require 'sparql/client'
require 'sparql'
require 'json/ld'
require 'json/ld/preloaded'
require 'rdf/trig'
require 'rdf/raptor'
require 'fileutils' # For directory creation
require 'digest' # For hashing URLs to filenames

module FAIRChampion
  class Index
    # Cache directory and expiry time (in seconds, e.g., 24 hours)
    CACHE_DIR = File.join(Dir.pwd, 'cache', 'rdf_repositories')
    CACHE_EXPIRY = 240 * 60 * 60 # 24 hours in seconds

    def self.retrieve_tests_from_index(indexendpoint: 'https://tools.ostrails.eu/repositories/fdpindex-fdp')
      sparql = SPARQL::Client.new(indexendpoint)

      fdpindexquery = <<EOQUERY
      PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
      PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
      PREFIX dqv: <http://www.w3.org/ns/dqv#>
      PREFIX dct: <http://purl.org/dc/terms/>
      PREFIX dcat: <http://www.w3.org/ns/dcat#>
      PREFIX sio: <http://semanticscience.org/resource/>
      PREFIX dpv: <http://www.w3.org/ns/dpv#>
      PREFIX ftr: <https://w3id.org/ftr#>
      SELECT distinct ?sub ?identifier ?title ?description ?endpoint ?openapi ?dimension ?objects ?domain ?benchmark_or_metric WHERE {
        ?sub a <https://w3id.org/ftr#Test> ;
            dct:title ?title ;
            dct:description ?description ;
            dct:identifier ?identifier .
            OPTIONAL {?sub dpv:isApplicableFor ?objects }
            OPTIONAL {?sub ftr:applicationArea ?domain  }
            OPTIONAL {?sub sio:SIO_000233 ?benchmark_or_metric  }  # implementation of#{'            '}
            OPTIONAL {?sub dcat:endpointDescription ?openapi }
            OPTIONAL {?sub dcat:endpointURL ?endpoint }
            OPTIONAL {?sub dqv:inDimension ?dimension }
      }#{' '}
EOQUERY

      alltests = []

      begin
        # Execute the query
        results = sparql.query(fdpindexquery)

        # Process the results
        results.each_solution do |solution|
          test_object = {
            subj: solution[:sub]&.to_s,
            identifier: solution[:identifier]&.to_s,
            title: solution[:title]&.to_s,
            description: solution[:description]&.to_s,
            endpoint: solution[:endpoint]&.to_s,
            openapi: solution[:openapi]&.to_s,
            dimension: solution[:dimension]&.to_s,
            objects: solution[:objects]&.to_s,
            domain: solution[:domain]&.to_s,
            benchmark_or_metric: solution[:benchmark_or_metric]&.to_s
          }
          alltests << test_object
        end
      rescue StandardError => e
        puts "Error executing SPARQL query: #{e.message}"
      end

      alltests
    end

    def self.get_metrics_labels_for_tests(tests:)
      labels = {}
      cache = {} # In-memory cache for this request

      # Ensure cache directory exists
      FileUtils.mkdir_p(CACHE_DIR)

      tests.each do |test|
        metric = test[:benchmark_or_metric] # Assume required
        warn "Processing metric: #{metric}"

        # Generate a safe filename for the metric URL
        cache_key = Digest::SHA256.hexdigest(metric)
        cache_file = File.join(CACHE_DIR, "#{cache_key}.bin")

        # Check in-memory cache first
        if cache[metric]
          repository = cache[metric]
        else
          # Try to load from disk cache
          repository = load_from_cache(cache_file)
          if repository
            warn "Loaded #{metric} from cache"
          else
            # Cache miss: fetch from URL
            warn "Fetching RDF for #{metric}"
            repository = RDF::Repository.new
            headers = { 'Accept' => 'application/ld+json' }
            begin
              RDF::Reader.open(metric, headers: headers) do |reader|
                repository << reader
              end
              # Save to disk cache with timestamp
              save_to_cache(cache_file, repository)
              warn "Cached #{metric} to disk"
            rescue StandardError => e
              warn "Error fetching RDF for #{metric}: #{e.message}"
              labels[metric] = "Unable to resolve #{metric} to RDF metadata"
              next
            end
          end
          cache[metric] = repository # Store in memory for this request
        end

        # SPARQL query to get label
        fdpindexquery = <<-METRICLABEL
          PREFIX dct: <http://purl.org/dc/terms/>
          PREFIX schema: <http://schema.org/>
          SELECT DISTINCT ?label WHERE {
            { ?sub dct:title ?label }
            UNION
            { ?sub schema:name ?label }
          }
        METRICLABEL

        # Parse and execute the SPARQL query
        fdpindexquery = SPARQL.parse(fdpindexquery)
        results = fdpindexquery.execute(repository)

        # Assign the label (first result or fallback)
        labels[metric] = if results&.first&.[](:label)&.to_s&.length&.positive?
                           results.first[:label].to_s
                         else
                           'Unnamed Metric'
                         end
      end

      labels
    end

    # Load RDF::Repository from disk cache if not expired
    def self.load_from_cache(cache_file)
      return nil unless File.exist?(cache_file)

      # Read timestamp and serialized data
      File.open(cache_file, 'rb') do |file|
        timestamp = Marshal.load(file)
        if Time.now - timestamp < CACHE_EXPIRY
          return Marshal.load(file) # Return cached RDF::Repository
        end
      end
      nil # Cache expired or invalid
    rescue StandardError => e
      warn "Error loading cache from #{cache_file}: #{e.message}"
      nil
    end

    # Save RDF::Repository to disk cache with timestamp
    def self.save_to_cache(cache_file, repository)
      File.open(cache_file, 'wb') do |file|
        Marshal.dump(Time.now, file) # Store timestamp
        Marshal.dump(repository, file) # Store repository
      end
    rescue StandardError => e
      warn "Error saving cache to #{cache_file}: #{e.message}"
    end
  end
end
