class BibRequest

  def initialize(id)
    bib_set = Alma::Bib.find [id], {}
    @data = bib_set.response['bib_data']
  end

  def title
    @data['title']
  end

  def author
    @data['author']
  end

  def publisher
    @data['publisher']
  end

  def pub_place
    @data['place_of_publication']
  end

  def pub_date
    @data['date_of_publication']
  end

  def isxn
    @data['issn']
  end

  def other_identifiers
    @data['network_number']
  end

  def edition
    nil
  end

  def citation_source
    'UPenn Alma'
  end
end
