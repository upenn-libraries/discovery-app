class SearchHistoryController < ApplicationController
  include Blacklight::SearchHistory

  helper BlacklightAdvancedSearch::RenderConstraintsOverride
end
