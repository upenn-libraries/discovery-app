class OpenURLItem

  MAPPING = {
    # book
    title: %w[title Book bookTitle rft.title rft.stitle rft.btitle],
    author: %w[Author author aau au rft.au], # TODO: assemble from aulast and aufirst?
    edition: %w[edition rft.edition],
    publisher: %w[publisher Publisher rft.pub],
    pub_place: %w[place PubliPlace rft.place],
    pub_date: %w[year rft.year rft.pubyear rft.pubdate], # TODO: assemble from pmonth/rft.month?
    isxn: %w[ISSN issn rft.issn ISBN isbn rft.isbn],
    citation_source: %w[sid rfr_id],
    # article
    journal_title: %w[Journal journal rft.btitle rft.jtitle rft.title title],
    article_title: %w[Article article atitle rft.atitle],
    date: %w[], # TODO: complicated
    volume: %w[Volume volume rft.volume],
    issue: %w[Issue issue rft.issue],
    pages: %w[Pages pages]  # TODO: could have (rft.)spage and (rft.)epage
  }

  attr_reader :params

  def initialize(params)
    @params = params
  end

  MAPPING.keys.each do |key|
    define_method key do
      value = hunt_for key
      URI.decode(value)&.gsub('+', ' ')
    end
  end

  def hunt_for(value)
    if MAPPING.keys.include? value
      MAPPING[value].each do |key|
        if @params[key.to_s].present?
          return @params[key.to_s] # TODO: break?
        end
      end
      ''
    else
      raise StandardError
    end
  end

end
