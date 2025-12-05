module FAIRChampion
  class Harvester
    def self.do_extruct(meta, uri)
      meta.comments << "INFO:  Using 'extruct' to try to extract metadata from return value (message body) of #{uri}.\n"
      warn 'begin open3'
      # binding.pry
      stdout, stderr, status = Open3.capture3(FAIRChampion::Utils::ExtructCommand + ' ' + uri)
      warn ''
      # sleep 5
      warn "open3 status: #{status} #{stdout}"
      result = stderr # absurd that the output comes over stderr!  LOL!
      # stdin.close
      # stdout.close
      # stderr.close

      # result = %x{#{FAIRChampion::Utils::ExtructCommand} #{uri} 2>&1}
      # $stderr.puts "\n\n\n\n\n\n\n#{result.class}\n\n#{result.to_s}\n\n#{@extruct_command} #{uri} 2>&1\n\n"
      # need to do some error checking here!
      if result.to_s.match(/(Failed\sto\sextract.*?)\n/)
        meta.comments << "WARN: extruct threw an error #{::Regexp.last_match(1)} when attempting to parse return value (message body) of #{uri}.\n"
        meta.comments << "WARN: extruct error was #{::Regexp.last_match(1)}\n" if result.to_s.match(/(ValueError:.*?)\n/)
      elsif result.to_s.match(/^\s+?\{/) or result.to_s.match(/^\s+\[/) # this is JSON
        begin
          json = JSON.parse result
        rescue StandardError
          warn "json parsing failed!  This is bad!\n"
          meta.comments << "INFO: the extruct tool found non-parseable data at #{uri}.  Aborting attempt to read it\n"
          return
        end
        # $stderr.puts "\n\n\n\nFOUND JSON\n\n\n"
        # $stderr.puts "\n\n\n\nFOUND JSON-LD\n#{json["json-ld"]} content\n\n\n"
        meta.comments << "INFO: the extruct tool found parseable data at #{uri}\n"

        Harvester.parse_rdf(meta, json['json-ld'].to_json, 'application/ld+json') if json['json-ld'].any? # RDF
        meta.merge_hash(json['microdata'].first) if json['microdata'].any?
        meta.merge_hash(json['microformat'].first) if json['microformat'].any?
        meta.merge_hash(json['opengraph'].first) if json['opengraph'].any?
        Harvester.parse_rdf(meta, json['rdfa'].to_json, 'application/ld+json') if json['rdfa'].any? # RDF

        meta.merge_hash(json.first) if json.first.is_a? Hash
      else
        meta.comments << "WARN: the extruct tool failed to find parseable data at #{uri}\n"
      end
    end
  end
end
