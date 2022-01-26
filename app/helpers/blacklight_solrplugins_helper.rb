
module BlacklightSolrpluginsHelper
  include BlacklightSolrplugins::HelperBehavior

  # current possible values for ref:
  # Subjects & Names: PREF, ALT, RELATED
  # Subjects: BROADER, NARROWER
  def xfacet_ref_type_display(ref)
    case ref
      when 'PREF'
        'Preferred'
      when 'ALT'
        'Alternate'
      else
        ref.humanize.capitalize
    end
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
