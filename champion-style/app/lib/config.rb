module FAIRChampion
  class Utils
    puts `pwd`
    puts File.dirname(__FILE__)
    config = ParseConfig.new(File.dirname(__FILE__) + '/config.conf')
    extruct_command = 'extruct'
    if config['extruct'] && config['extruct']['command'] && !config['extruct']['command'].empty?
      extruct_command = config['extruct']['command']
    end
    extruct_command.strip!
    # case @extruct_command
    # when /[&\|\;\`\$\s]/
    #   abort 'The Extruct command in the config file appears to be subject to command injection.  I will not continue'
    # when /echo/i
    #   abort 'The Extruct command in the config file appears to be subject to command injection.  I will not continue'
    # end
    FAIRChampion::Utils::ExtructCommand = extruct_command


    rdf_command = 'rdf'
    if config['rdf'] && config['rdf']['command'] && !config['rdf']['command'].empty?
      rdf_command = config['rdf']['command']
    end
    rdf_command.strip
    case rdf_command
    when /echo/i
      abort 'The RDF command in the config file appears to be subject to command injection.  I will not continue'
    when !(/rdf$/ =~ $_)
      abort "this software requires that Kelloggs Distiller tool is used. The distiller command must end in 'rdf'"
    end
    FAIRChampion::Utils::RDFCommand = rdf_command

    tika_command = 'http://localhost:9998/meta'
    if config['tika'] && config['tika']['command'] && !config['tika']['command'].empty?
      tika_command = config['tika']['command']
    end
    FAIRChampion::Utils::TikaCommand = tika_command

    FAIRChampion::Utils::AcceptHeader = { 'Accept' => 'text/turtle, application/ld+json, application/rdf+xml, text/xhtml+xml, application/n3, application/rdf+n3, application/turtle, application/x-turtle, text/n3, text/turtle, text/rdf+n3, text/rdf+turtle, application/n-triples' }

    FAIRChampion::Utils::TEXT_FORMATS = {
      'text' => ['text/plain']
    }

    FAIRChampion::Utils::RDF_FORMATS = {
      'jsonld' => ['application/ld+json', 'application/vnd.schemaorg.ld+json'], # NEW FOR DATACITE
      'turtle' => ['text/turtle', 'application/n3', 'application/rdf+n3',
                  'application/turtle', 'application/x-turtle', 'text/n3', 'text/turtle',
                  'text/rdf+n3', 'text/rdf+turtle'],
      # 'rdfa'    => ['text/xhtml+xml', 'application/xhtml+xml'],
      'rdfxml' => ['application/rdf+xml'],
      'triples' => ['application/n-triples', 'application/n-quads', 'application/trig']
    }

    FAIRChampion::Utils::XML_FORMATS = {
      'xml' => ['text/xhtml', 'text/xml']
    }

    FAIRChampion::Utils::HTML_FORMATS = {
      'html' => ['text/html', 'text/xhtml+xml', 'application/xhtml+xml']
    }

    FAIRChampion::Utils::JSON_FORMATS = {
      'json' => ['application/json']
    }

    FAIRChampion::Utils::DATA_PREDICATES = [
      'http://www.w3.org/ns/ldp#contains',
      'http://xmlns.com/foaf/0.1/primaryTopic',
      'http://purl.obolibrary.org/obo/IAO_0000136', # is about
      'http://purl.obolibrary.org/obo/IAO:0000136', # is about (not the valid URL...)
      'https://www.w3.org/ns/ldp#contains',
      'https://xmlns.com/foaf/0.1/primaryTopic',

      # 'http://schema.org/about', # removed for being too general
      'http://schema.org/mainEntity',
      'http://schema.org/codeRepository',
      'http://schema.org/distribution',
      'http://schema.org/contentUrl',
      # 'https://schema.org/about', #removed for being too general
      'https://schema.org/mainEntity',
      'https://schema.org/codeRepository',
      'https://schema.org/distribution',
      'https://schema.org/contentUrl',

      'http://www.w3.org/ns/dcat#distribution',
      'https://www.w3.org/ns/dcat#distribution',
      'http://www.w3.org/ns/dcat#dataset',
      'https://www.w3.org/ns/dcat#dataset',
      'http://www.w3.org/ns/dcat#downloadURL',
      'https://www.w3.org/ns/dcat#downloadURL',
      'http://www.w3.org/ns/dcat#accessURL',
      'https://www.w3.org/ns/dcat#accessURL',

      'http://semanticscience.org/resource/SIO_000332', # is about
      'http://semanticscience.org/resource/is-about', # is about
      'https://semanticscience.org/resource/SIO_000332', # is about
      'https://semanticscience.org/resource/is-about', # is about
      'https://purl.obolibrary.org/obo/IAO_0000136' # is about
    ]

    FAIRChampion::Utils::SELF_IDENTIFIER_PREDICATES = [
      'http://purl.org/dc/elements/1.1/identifier',
      'https://purl.org/dc/elements/1.1/identifier',
      'http://purl.org/dc/terms/identifier',
      'http://schema.org/identifier',
      'https://purl.org/dc/terms/identifier',
      'https://schema.org/identifier'
    ]

    FAIRChampion::Utils::GUID_TYPES = { 'inchi' => /^\w{14}-\w{10}-\w$/,
                          'doi' => %r{^10.\d{4,9}/[-._;()/:A-Z0-9]+$}i,
                          'handle1' => %r{^[^/]+/[^/]+$}i,
                          'handle2' => %r{^\d{4,5}/[-._;()/:A-Z0-9]+$}i, # legacy style  12345/AGB47A
                          'uri' => %r{^\w+:/?/?[^\s]+$} }




    class Config
      attr_accessor :fairsharing_key_location, 
      def initialize(fairsharing_key_location: "")
        @fairsharing_key_location = fairsharing_key_location
      end

      def fairsharing_key
        @fairsharing_key_location
      end
    end
  end
end