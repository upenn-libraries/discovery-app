
module AssociateExpandedDocs

  extend ActiveSupport::Concern

  def associate_expanded(response, document_list)
    expanded = response['expanded']
    if expanded.present?
      document_list.each do |document|
        item_in_expanded = expanded[document.fetch('cluster_id')]
        if item_in_expanded.present?
          expanded_docs = item_in_expanded['docs'] || []
          expanded_docs.each do |expanded_doc|
            document.expanded_docs << SolrDocument.new(expanded_doc, response)
          end
        end
      end
    end
  end

  # override
  def search_results(params)
    (response, document_list) = super(params)
    associate_expanded(response, document_list)
    [response, document_list]
  end

  # override
  def fetch(id)
    response, document = super(id)
    associate_expanded(response, [document])
    [response, document]
  end

end
