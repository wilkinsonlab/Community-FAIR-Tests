module FAIRChampion
  class Harvester

    def self.resolve_uri(guid, meta)
      type, url = Harvester.convertToURL(guid)
      meta.guidtype = type if meta.guidtype.nil?

      meta.comments << "INFO: Found a URI.\n"
      meta.comments << "INFO:  Attempting to resolve #{url} using HTTP Headers #{FAIRChampion::Utils::AcceptHeader}.\n"
      Harvester.resolve_url(guid: url, meta: meta, nolinkheaders: false)
      meta.comments << "INFO:  Attempting to resolve #{url} using HTTP Headers #{FAIRChampion::Utils::XML_FORMATS['xml'].join(',')}.\n"
      Harvester.resolve_url(guid: url, meta: meta, nolinkheaders: false, headers: { 'Accept' => "#{FAIRChampion::Utils::XML_FORMATS['xml'].join(',')}" })
      meta.comments << "INFO:  Attempting to resolve #{url} using HTTP Headers #{FAIRChampion::Utils::JSON_FORMATS['json'].join(',')}.\n"
      Harvester.resolve_url(guid: url, meta: meta, nolinkheaders: false, headers: { 'Accept' => "#{FAIRChampion::Utils::JSON_FORMATS['json'].join(',')}" })
      meta.comments << "INFO:  Attempting to resolve #{url} using HTTP Headers 'Accept: */*'.\n"
      Harvester.resolve_url(guid: url, meta: meta, nolinkheaders: false, headers: { 'Accept' => '*/*' })
      meta
    end
  end
end
