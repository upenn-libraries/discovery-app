class IndexCreatedBibJob < ActiveJob::Base
  queue_as :default

  def perform(marcxml)
    FranklinIndexer.process marcxml
  end
end
