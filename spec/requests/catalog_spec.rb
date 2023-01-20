require "rails_helper"

RSpec.describe 'Actions in the CatalogController' do
  it 'properly resolves facet params mangled by drupal' do
    get '/catalog?f%5Bformat_f%5D%5B0%5D=Journal/Periodical'
    expect(response).to have_http_status :ok
  end
end
