# frozen_string_literal: true
class SavedSearchesController < ApplicationController
  include Blacklight::SavedSearches

  helper BlacklightAdvancedSearch::RenderConstraintsOverride #EXTRACT:candidate Xapp/controllers/saved_searches_controller.rb
end
