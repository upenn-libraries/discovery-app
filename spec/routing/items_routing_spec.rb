# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'routes for Items API', type: :routing do
  it 'routes /alma/items/1234/all to items#all' do
    expect(get('/alma/items/1234/all')).to route_to controller: 'items',
                                                    action: 'all',
                                                    mms_id: '1234'
  end
  it 'routes /alma/bib/1234/holding/2345/item/3456 to items#one' do
    expect(get('/alma/bib/1234/holding/2345/item/3456'))
      .to route_to controller: 'items',
                   action: 'one',
                   mms_id: '1234',
                   holding_id: '2345',
                   item_pid: '3456'
  end
end
