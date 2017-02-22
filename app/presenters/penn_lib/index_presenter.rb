
module PennLib
  class IndexPresenter < Blacklight::IndexPresenter

    def label(field_or_string_or_proc, opts = {})
      # unlike ShowPresenter, IndexPresenters don't have a #heading method;
      # BL simply calls #label with the 'title_field' value from config.
      # So we intercept that here. This is ugly, but I can't figure out
      # a better way to override title display behavior.

      title_field = configuration.view_config(:index).title_field.to_sym

      if field_or_string_or_proc == title_field
        ([ document.fetch('title', '') ] + document.fetch('title_880_a', []))
            .select { |value| value.present? }
            .join('<br/>')
            .html_safe
      else
        # I'm not sure that #label is EVER used for anything besides the heading,
        # so call super just in case
        super(field_or_string_or_proc, opts)
      end
    end

  end
end
