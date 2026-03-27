require 'triple_easy'

module ChampionDCAT
  class DCAT_Record
    attr_accessor :identifier, :testname, :description, :keywords, :creator,
                  :indicators, :end_desc, :end_url, :dctype, :testid, :supportedby,
                  :license, :themes, :testversion, :implementations, :isapplicablefor, :applicationarea,
                  :organizations, :individuals, :protocol, :host, :basePath, :metric, :landingpage

    require_rel './output.rb'
    include TripleEasy # get the :"triplify" function
    # triplify(s, p, o, repo, datatype: nil, context: nil, language: 'en')

    def initialize(meta:)
      indics = [meta[:indicators]] unless meta[:indicators].is_a? Array
      @indicators = indics
      @testid = meta[:testid]
      @testname = meta[:testname]
      @metric = meta[:metric]
      @description = meta[:description]
      @keywords = meta[:keywords]
      @keywords = [@keywords] unless @keywords.is_a? Array
      @creator = meta[:creator]
      @end_desc = meta[:end_desc]
      @end_url = meta[:end_url]
      @dctype = meta[:dctype] || 'http://edamontology.org/operation_2428'
      @supportedby = meta[:supportedby] || ['https://tools.ostrails.eu/champion']
      @applicationarea = meta[:applicationarea] || ['http://www.fairsharing.org/ontology/subject/SRAO_0000401']
      @isapplicablefor = meta[:isapplicablefor] || ['https://schema.org/Dataset']
      @landingpage = meta[:landingPage] || @end_url
      @license = meta[:license]
      @themes = meta[:themes]
      @themes = [@themes] unless @themes.is_a? Array
      @testversion = meta[:testversion]
      @organizations = meta[:organizations]
      @individuals = meta[:individuals]
      @protocol = meta[:protocol]
      @host = meta[:host]
      @basePath = meta[:basePath]
      cleanhost = @host.gsub('/', '')
      cleanpath = @basePath.gsub('/', '') # TODO: this needs to check only leading and trailing!  NOt internal...
      endpointpath = 'assess/test'
      @end_url = "#{protocol}://#{cleanhost}/#{cleanpath}/#{endpointpath}/#{testid}"
      @end_desc = "#{protocol}://#{cleanhost}/#{cleanpath}/#{testid}/api"
      @identifier = "#{protocol}://#{cleanhost}/#{cleanpath}/#{testid}"
    end

    def get_dcat
      schema = RDF::Vocab::SCHEMA
      dcterms = RDF::Vocab::DC
      vcard = RDF::Vocab::VCARD
      xsd = RDF::Vocab::XSD

      dcat = RDF::Vocab::DCAT
      sio = RDF::Vocabulary.new('http://semanticscience.org/resource/')
      ftr = RDF::Vocabulary.new('https://w3id.org/ftr#')
      dqv = RDF::Vocabulary.new('http://www.w3.org/ns/dqv#')
      vcard = RDF::Vocabulary.new('http://www.w3.org/2006/vcard/ns#')
      dpv = RDF::Vocabulary.new('https://w3id.org/dpv#')

      g = RDF::Graph.new
      #      me = "#{identifier}/about"   # at the hackathon we decided that the test id would return the metadata
      # so now there is no need for /about
      me = "#{identifier}"

      triplify(me, RDF.type, dcat.DataService, g)
      triplify(me, RDF.type, ftr.Test, g)

      # triplify tests and rejects anything that is empty or nil  --> SAFE
      # Test Unique Identifier	dcterms:identifier	Literal
      triplify(me, dcterms.identifier, identifier.to_s, g, datatype: xsd.string)

      # Title/Name of the test	dcterms:title	Literal
      triplify(me, dcterms.title, testname, g)

      # Description	dcterms:description	Literal
      # descriptions.each do |d|
      #   triplify(me, dcterms.description, d, g)
      # end
      triplify(me, dcterms.description, description, g)

      # Keywords	dcat:keyword	Literal
      keywords.each do |kw|
        triplify(me, dcat.keyword, kw, g)
      end

      # Test creator	dcterms:creator	dcat:Agent (URI)
      triplify(me, dcterms.creator, creator, g)

      # Dimension	ftr:indicator
      indicators.each do |ind|
        triplify(me, dqv.inDimension, ind, g)
      end

      # API description	dcat:endpointDescription	rdfs:Resource
      triplify(me, dcat.endpointDescription, end_desc, g)

      # API URL	dcat:endpointURL	rdfs:Resource
      triplify(me, dcat.endpointURL, end_url, g)

      # API URL	dcat:landingPage	rdfs:Resource
      triplify(me, dcat.landingPage, landingpage, g)

      # Source of the test	codemeta:hasSourceCode/schema:codeRepository/ doap:repository	schema:SoftwareSourceCode/URL
      # TODO
      # FAIRChampion::Output.triplify(me, dcat.endpointDescription, end_desc, g)

      # Functional Descriptor/Operation	dcterms:type	xsd:anyURI
      triplify(me, dcterms.type, dctype, g)

      # License	dcterms:license	xsd:anyURI
      triplify(me, dcterms.license, license, g)

      # Semantic Annotation	dcat:theme	xsd:anyURI
      themes.each do |theme|
        triplify(me, dcat.theme, theme, g)
      end

      # Version	dcat:version	rdfs:Literal
      triplify(me, RDF::Vocab::DCAT.to_s + 'version', testversion, g)

      # # Version notes	adms:versionNotes	rdfs:Literal
      # FAIRChampion::Output.triplify(me, dcat.version, version, g)

      triplify(me, sio['SIO_000233'], metric, g) # is implementation of
      triplify(metric, RDF.type, dqv.Metric, g) # is implementation of

      # Responsible	dcat:contactPoint	dcat:Kind (includes Individual/Organization)
      individuals.each do |i|
        # i = {name: "Mark WAilkkinson", "email": "asmlkfj;askjf@a;lksdjfas"}
        guid = SecureRandom.uuid
        cp = "urn:fairchampion:testmetadata:individual#{guid}"
        triplify(me, dcat.contactPoint, cp, g)
        triplify(cp, RDF.type, vcard.Individual, g)
        triplify(cp, vcard.fn, i['name'], g) if i['name']
        next unless i['email']

        email = i['email'].to_s
        email = "mailto:#{email}" unless email =~ /mailto:/
        triplify(cp, vcard.hasEmail, RDF::URI.new(email), g)
      end

      organizations.each do |o|
        # i = {name: "CBGP", "url": "https://dbdsf.orhf"}
        guid = SecureRandom.uuid
        cp = "urn:fairchampion:testmetadata:org:#{guid}"
        triplify(me, dcat.contactPoint, cp, g)
        triplify(cp, RDF.type, vcard.Organization, g)
        triplify(cp, vcard['organization-name'], o['name'], g)
        triplify(cp, vcard.url, RDF::URI.new(o['url'].to_s), g)
      end

      supportedby.each do |tool|
        triplify(me, ftr.supportedBy, tool, g)
        triplify(tool, RDF.type, schema.SoftwareApplication, g)
      end

      applicationarea.each do |domain|
        triplify(me, ftr.applicationArea, domain, g)
      end
      isapplicablefor.each do |digitalo|
        triplify(me, dpv.isApplicableFor, digitalo, g)
      end

      g
    end
  end
end
