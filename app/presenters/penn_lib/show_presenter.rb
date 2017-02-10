
module PennLib
  class ShowPresenter < Blacklight::ShowPresenter

    def heading
      document.title_display
    end

  end
end
