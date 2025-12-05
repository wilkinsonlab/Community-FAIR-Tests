module FAIRChampion
  class Harvester

    def self.resolve_doi(guid, meta)
      guid.downcase!
      type, url = Harvester.convertToURL(guid)
      meta.guidtype = type if meta.guidtype.nil?
      meta.comments << "INFO:  Found a DOI.\n"

      meta.comments << "INFO:  Attempting to resolve #{url} using HTTP Headers #{FAIRChampion::Utils::AcceptHeader}.\n"
      Harvester.resolve_url(guid: url, meta: meta, nolinkheaders: false) # specifically metadataguid: link, meta: meta, nolinkheaders: true
      meta.comments << "INFO:  Attempting to resolve #{url} using HTTP Headers {\"Accept\"=>\"*/*\"}.\n"
      Harvester.resolve_url(guid: url, meta: meta, nolinkheaders: false, headers: { 'Accept' => '*/*' }) # whatever is default

      # CrossRef and DataCite both "intercept" the normal redirect process, when a URI has a content-type
      # Accept header that they understand.  This prevents the owner of the data from providing their own
      # metadata of that type, when using the DOI as their GUID.  Here
      # we have let the redirect process go all the way to the final URL, and we then
      # treat that as a new GUID.
      finalURI = meta.finalURI.last
      if finalURI =~ %r{\w+://}
        meta.comments << "INFO:  DOI resolution captures content-negotiation before reaching final data owner.  Now re-attempting the full suite of content negotiation on final redirect URI #{finalURI}.\n"
        Harvester.resolve_uri(finalURI, meta)
      end

      meta
    end
  end
end
