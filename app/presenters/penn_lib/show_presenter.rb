
module PennLib
  class ShowPresenter < Blacklight::ShowPresenter

    def heading #EXTRACT:wholesale Xapp/presenters/blacklight/show_presenter.rb
      document.title_display
    end

  end
end
