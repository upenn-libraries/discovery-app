# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'routes for Requesting Items', type: :routing do
  it 'routes /request/confirm to requests#confirm' do
    expect(get('/request/confirm')).to route_to controller: 'requests',
                                                action: 'confirm'
  end
  it 'routes /request/submit to requests#create' do
    expect(post('/request/submit'))
      .to route_to controller: 'requests',
                   action: 'submit'
  end
end
