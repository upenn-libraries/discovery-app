class IndexDeletedBibJob < ActiveJob::Base
  queue_as :default

  def perform(marcxml)
    # Do something later
  end
end
