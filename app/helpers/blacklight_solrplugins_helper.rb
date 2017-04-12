
module BlacklightSolrpluginsHelper
  include BlacklightSolrplugins::HelperBehavior

  def render_rbrowse_result(facet_item, doc_presenter)
    link_to(doc_presenter.field_value('title'), solr_document_path(doc_presenter.field_value('id')))
  end

  def render_rbrowse_display_field(fieldname, doc_presenter)
    # handle special case of availability, which gets loaded via ajax
    if fieldname == 'availability'
      render partial: 'status_location_field', locals: { document: doc_presenter.document }
    else
      super(fieldname, doc_presenter)
    end
  end

end
