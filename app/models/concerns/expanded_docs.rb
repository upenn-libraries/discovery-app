
# mixin for SolrDocument to support storing the associated
# expanded documents from Solr response
module ExpandedDocs

  attr_accessor :expanded_docs

  def initialize(source_doc={}, response=nil)
    super(source_doc, response)
    @expanded_docs = []
  end

end
