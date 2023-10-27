
class PennLib::SummonEngine < BentoSearch::SummonEngine

  META_CHARS = '-|!\(\){}\[\]^~*?\\:' # '&' does not seem to be affected

  # Override default base url value to use HTTPS because it is 2023
  def self.default_configuration
    {
      :base_url => "https://api.summon.serialssolutions.com/2.0.0/search",
      :highlighting => true,
      :use_summon_openurl => false
    }
  end

  def search_implementation(args)
    mitigate(args)
    results = super(args)
    results.each do |item|
      item.link = 'https://proxy.library.upenn.edu/login?url=' + item.link
    end
    return results
  end

  # The stock summon_engine does escape '+', but as of 20200930 it appears that
  # no matter how deeply you try to escape meta-characters, a trailing '+' still
  # results in a 500 error from the summon API. For now, we're reporting this to
  # Summon, and in the meantime assuming (likely incorrectly, but until
  # evidence proves otherwise) that this is the only case in which escaping is
  # not working correctly. This should be able to be removed once the upstream
  # issue is addressed, but should also be harmless to leave in place.
  def mitigate(args)
    query = args[:query]
    query.gsub!(/(^|[[:space:]])\+-[#{META_CHARS}]*([^#{META_CHARS}])/) do |match|
      # replace extraneous META_CHARS following any '+-'-led clause
      "#{$1}+#{$2}"
    end
    plus_idx = query.rindex('+')
    return unless plus_idx # no '+' char; not applicable
    if query[plus_idx + 1..-1].match(/[^[[:space:]]#{META_CHARS}]/)
      # there's some other character after the last '+' that will cause
      # the query to parse properly. Such ameliorating characters are neither whitespace
      # nor special syntax characters, and mean the original query should parse fine as-is
      return
    end
    # append an extra dummy "term" to prevent server-side 500 error
    args[:query] = query + ' /'
  end
end
