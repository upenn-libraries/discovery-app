
module BlacklightSolrpluginsHelper
  include BlacklightSolrplugins::HelperBehavior

  def render_rbrowse_result(facet_item, doc_presenter)
    link_to(doc_presenter.field_value('title'), solr_document_path(doc_presenter.field_value('id')))
  end

end
