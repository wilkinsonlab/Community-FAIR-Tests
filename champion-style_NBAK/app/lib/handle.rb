module FAIRChampion
  class Harvester

    def self.resolve_handle(guid, meta)
      type, url = Harvester.convertToURL(guid)
      meta.guidtype = type if meta.guidtype.nil?

      meta.comments << "INFO: Found a non-DOI Handle.\n"
      meta.comments << "INFO:  Attempting to resolve #{url} using HTTP Headers #{FAIRChampion::Utils::AcceptHeader}.\n"
      Harvester.resolve_uri(url, meta)
      #      meta.comments << "INFO:  Attempting to resolve http://hdl.handle.net/#{guid} using HTTP Headers #{{"Accept" => "*/*"}.to_s}.\n"
      #      FAIRChampion::Utils::resolve_url("http://hdl.handle.net/#{guid}", meta, false, {"Accept" => "*/*"})
      meta
    end
  end
end
