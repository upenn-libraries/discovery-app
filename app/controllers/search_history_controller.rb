class SearchHistoryController < ApplicationController
  #EXTRACT:candidate Xapp/controllers/search_history_controller.rb (but probably not, since gem-managed?)
  include Blacklight::SearchHistory

  helper BlacklightRangeLimit::ViewHelperOverride
  helper RangeLimitHelper
  helper BlacklightAdvancedSearch::RenderConstraintsOverride
end
