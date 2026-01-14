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

    # this should only be called AFTER the general resolve above
    def self.resolve_doi_to_registration_agency(doi, meta)
      doi.downcase!
      doi.gsub!(%r{https?://[^/+]/}, '')
      doi.strip!
      url = "https://doi.org/doiRA/#{doi}"
      meta.comments << "INFO:  Finding DOI registration agency.\n"

      meta.comments << "INFO:  Attempting to resolve #{url} using HTTP Headers {\"Accept\"=>\"*/*\"}.\n"
      _headers, body = FAIRChampion::Harvester.fetch(guid: url, headers: FAIRChampion::Utils::AcceptDefaultHeader)
      if body
        meta.comments << "INFO:  parsing agency from response\n"
        json = JSON.parse(body)
        json.dig(0, 'RA')
      else
        meta.comments << "WARN:  doiRA did not return JSON.  Aborting.\n"
        false
      end
    end

    def self.get_funding_information_from_crossref(doi, meta)
      # https://api.crossref.org/works/10.1063/5.0095229
      doi.downcase!
      doi.gsub!(%r{https?://[^/+]/}, '')
      doi.strip!
      url = "https://api.crossref.org/works/#{doi}"
      meta.comments << "INFO:  Looking for funding information\n"
      _headers, body = FAIRChampion::Harvester.fetch(guid: url, headers: FAIRChampion::Utils::AcceptDefaultHeader)
      # warn "headers #{_headers} #{url}"
      # abort
      return nil unless body

      meta.comments << "INFO:  parsing funding info from response\n"
      json = JSON.parse(body)
      funding_refs = json.dig('message', 'funder')
      first_funding = funding_refs&.dig(0) # safe navigation + dig

      if first_funding
        meta.comments << "INFO:  funding info block found\n"
        first_funding
      else
        meta.comments << "WARN:  no funding information block found\n"
        false
      end
    end

    def self.get_funding_information_from_datacite(doi, meta)
      # https://api.datacite.org/dois/10.15151/ESRF-ES-2303075148
      doi.downcase!
      doi.gsub!(%r{https?://[^/+]/}, '')
      doi.strip!
      url = "https://api.datacite.org/dois/#{doi}"
      meta.comments << "INFO:  Looking for funding information\n"
      _headers, body = FAIRChampion::Harvester.fetch(guid: url, headers: FAIRChampion::Utils::AcceptDefaultHeader)
      return unless body

      # warn body

      meta.comments << "INFO:  parsing funding info from response\n"
      data = JSON.parse(body, symbolize_names: true)

      funding_refs = data.dig(:data, :attributes, :fundingReferences)
      first_funding = funding_refs&.dig(0) # safe navigation + dig

      if first_funding
        meta.comments << "INFO:  funding info block found\n"
        first_funding
      else
        meta.comments << "WARN:  no funding information block found\n"
        false
      end
    end
  end
end
