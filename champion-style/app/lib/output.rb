require 'cgi'
require 'securerandom'
require 'rdf/vocab'

include RDF

module FAIRChampion
  class Output
    include RDF
    extend Forwardable

    def_delegators FAIRChampion::Output, :triplify

    attr_accessor :score, :testedGUID, :testid, :uniqueid, :name, :description, :license, :dt, :metric, 
                  :version, :summary, :completeness, :comments, :guidance

    
    OPUTPUT_VERSION = "1.1.1"

    def initialize(testedGUID:, meta:)
      @score = 'indeterminate'
      @testedGUID = testedGUID
      @uniqueid = 'urn:fairtestoutput:' + SecureRandom.uuid
      @name = meta[:testname]
      @description = meta[:description]
      @license = meta[:license] || 'https://creativecommons.org/licenses/by/4.0/'
      @dt = Time.now.iso8601
      @metric = meta[:metric]
      @version = meta[:testversion]
      @summary = meta[:summary] || 'Summary:'
      @completeness = '100'
      @testid = meta[:testid]
      @comments = []
      @guidance = meta.fetch(:guidance, [])
    end

    def createEvaluationResponse
      g = RDF::Graph.new
      schema = RDF::Vocab::SCHEMA
      xsd = RDF::Vocab::XSD
      dct = RDF::Vocab::DC 
      prov = RDF::Vocab::PROV
      dcat = RDF::Vocab::DCAT
      dqv = RDF::Vocabulary.new('https://www.w3.org/TR/vocab-dqv/')
      ftr = RDF::Vocabulary.new('https://w3id.org/ftr#')
      sio = RDF::Vocabulary.new('http://semanticscience.org/resource/')
      cwmo = RDF::Vocabulary.new('http://purl.org/cwmo/#')
      
      add_newline_to_comments

      if summary =~ /^Summary$/
        summary = "Summary of test results: #{comments[-1]}"
        summary ||= "Summary of test results: #{comments[-2]}"
      end

      executionid = 'urn:ostrails:testexecutionactivity:' + SecureRandom.uuid

      # softwareid = 'urn:ostrails:fairtestsoftware:' + SecureRandom.uuid
      softwareid = "https://tests.ostrails.eu/tests/#{testid}"
      # tid = 'urn:ostrails:fairtestentity:' + SecureRandom.uuid
      # The entity is no longer an anonymous node, it is the GUID Of the tested input

      triplify(executionid, RDF.type, ftr.TestExecutionActivity, g)
      triplify(executionid, prov.wasAssociatedWith, softwareid, g)
      triplify(uniqueid, prov.wasGeneratedBy, executionid, g)

      triplify(uniqueid, RDF.type, ftr.TestResult, g)
      triplify(uniqueid, dct.identifier, uniqueid, g)
      triplify(uniqueid, dct.title, "#{name} OUTPUT", g)
      triplify(uniqueid, dct.description, "OUTPUT OF #{description}", g)
      triplify(uniqueid, dct.license, license, g)
      triplify(uniqueid, prov.value, score, g)
      triplify(uniqueid, ftr.summary, summary, g)
      triplify(uniqueid, RDF::Vocab::PROV.generatedAtTime, dt, g)
      triplify(uniqueid, ftr.log, comments.join, g)
      triplify(uniqueid, ftr.completion, completeness, g)


      triplify(uniqueid, ftr.outputFromTest, softwareid, g)      
      triplify(softwareid, RDF.type, ftr.Test, g)
      triplify(softwareid, RDF.type, schema.SoftwareApplication, g)
      triplify(softwareid, RDF.type, dcat.DataService, g)
      triplify(softwareid, dct.identifier,
               "https://tests.ostrails.eu/tests/#{testid}", g, xsd.string)
      triplify(softwareid, dct.title, "#{name}", g)
      triplify(softwareid, dct.description, description, g)
      triplify(softwareid, dcat.endpointDescription,
               "https://tests.ostrails.eu/tests/#{testid}", g) # returns yaml
      triplify(softwareid, dcat.endpointURL,
               "https://tests.ostrails.eu/tests/#{testid}", g) # POST to execute
      triplify(softwareid, "http://www.w3.org/ns/dcat#version", "#{version} OutputVersion:#{OPUTPUT_VERSION}" , g)  # dcat namespace in library has no version - dcat 2 not 3
      triplify(softwareid, dct.license, 'https://github.com/wilkinsonlab/FAIR-Core-Tests/blob/main/LICENSE', g)
      triplify(softwareid, sio["SIO_000233"], metric, g)  # implementation of 

      # deprecated after release 1.0
      # triplify(uniqueid, prov.wasDerivedFrom, tid, g)
      # triplify(executionid, prov.used, tid, g)
      # triplify(tid, RDF.type, prov.Entity, g)
      # triplify(tid, schema.identifier, testedGUID, g, xsd.string)
      # triplify(tid, schema.url, testedGUID, g) if testedGUID =~ %r{^https?://}
      begin
        triplify(uniqueid, ftr.assessmentTarget, testedGUID, g)
        triplify(executionid, prov.used, testedGUID, g)
        triplify(testedGUID, RDF.type, prov.Entity, g)
        triplify(testedGUID, dct.identifier, testedGUID, g)
      rescue
        triplify(uniqueid, ftr.assessmentTarget, "not a URI", g)
        triplify(executionid, prov.used, "not a URI", g)
        score = "fail"
      end

      unless score == "pass"
        guidance.each do |advice, label|
          adviceid = 'urn:ostrails:testexecutionactivity:advice:' + SecureRandom.uuid
          triplify(uniqueid, ftr.suggestion, adviceid, g)
          triplify(adviceid, RDF.type, ftr.GuidanceContext, g)
          triplify(adviceid, RDFS.label, label, g)
          triplify(adviceid, dct.description, label, g)
          triplify(adviceid, sio["SIO_000339"], RDF::URI.new(advice), g)
        end       
      end



      
#      g.dump(:jsonld)
      w = RDF::Writer.for(:jsonld)
      w.dump(g, nil, prefixes: {
        xsd: RDF::Vocab::XSD, 
        prov: RDF::Vocab::PROV,
        dct: RDF::Vocab::DC,
        dcat: RDF::Vocab::DCAT,
        ftr: ftr,
        sio: sio,
        schema: schema
      })
    end

    # can be called as FAIRChampion::Output.comments << "newcomment"
    def self.comments
      @comments
    end

    def comments
      @comments
    end

    def self.clear_comments
      @comments = []
    end

    def add_newline_to_comments
      cleancomments = []
      @comments.each do |c|
        c += "\n" unless c =~ /\n$/
        cleancomments << c
      end
      @comments = cleancomments
    end

    def self.triplify(s, p, o, repo, datatype = nil)
      begin
        # warn "S-P-O #{s.to_s} #{p.to_s} #{o.to_s}"
      rescue
        warn "input to #triplify seems totally invalid!"
        return false
      end
      s = s.strip if s.instance_of?(String)
      p = p.strip if p.instance_of?(String)
      o = o.strip if o.instance_of?(String)

      unless s.respond_to?('uri')

        if s.to_s =~ %r{^\w+:/?/?[^\s]+}
          s = RDF::URI.new(s.to_s)
        else
          raise "Subject #{s} must be a URI-compatible thingy"

        end
      end

      unless p.respond_to?('uri')

        if p.to_s =~ %r{^\w+:/?/?[^\s]+}
          p = RDF::URI.new(p.to_s)
        else
          abort "Predicate #{p} must be a URI-compatible thingy"
        end
      end

      unless o.respond_to?('uri?')
        o = if datatype
          warn "DATATYPE #{datatype}"
              RDF::Literal.new(o.to_s, datatype: datatype)
            elsif o.to_s =~ %r{\A\w+:/?/?\w[^\s]+}
              RDF::URI.new(o.to_s)
            elsif o.to_s =~ /^\d{4}-[01]\d-[0-3]\dT[0-2]\d:[0-5]\d/
              RDF::Literal.new(o.to_s, datatype: RDF::XSD.date)
            elsif o.to_s =~ /^[+-]?\d+\.\d+/ && o.to_s !~ /[^\+\-\d\.]/ # has to only be digits
              RDF::Literal.new(o.to_s, datatype: RDF::XSD.float)
            elsif o.to_s =~ /^[+-]?[0-9]+$/ && o.to_s !~ /[^\+\-\d\.]/ # has to only be digits
              RDF::Literal.new(o.to_s, datatype: RDF::XSD.int)
            else
              RDF::Literal.new(o.to_s, language: :en)
            end
      end

      triple = RDF::Statement(s, p, o)
      repo.insert(triple)

      true
    end

    def self.triplify_this(s, p, o, repo)
      triplify(s, p, o, repo)
    end
  end
end
