# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OpenURLItem, type: :model do

  # these params are output by Alma for the ILL GES request option
  let(:params) do
    {
      'rft.stitle' => 'Churchill+%3A',
      'rft.pub' => 'Edward+Everett+Root%2C',
      'rft.place' => 'Sussex+%3A',
      'rft.isbn' => '1912224224',
      'rft.btitle' => 'Churchill+%3A+the+contradictions+of+greatness+%2F',
      'rft.genre' => 'book',
      'rft.normalized_isbn' => '9781912224227',
      'rft.oclcnum' => '1000128451',
      'rft.mms_id' => '9978056641203681',
      'rft.object_type' => 'BOOK',
      'rft.publisher' => 'Edward+Everett+Root%2C',
      'rft.au' => 'Rubinstein%2C+W.+D.+author.',
      'rft.pubdate' => '2020.',
      'rft.title' => 'Churchill+%3A+the+contradictions+of+greatness+%2F',
    }
  end
  let(:openurl_item) { described_class.new params }

  it 'responds to expected form fields properly' do
    expect(openurl_item.title).to eq 'Churchill : the contradictions of greatness /'
    expect(openurl_item.author).to eq 'Rubinstein, W. D. author.'
    expect(openurl_item.edition).to eq ''
    expect(openurl_item.publisher).to eq 'Edward Everett Root,'
    expect(openurl_item.pub_place).to eq 'Sussex :'
    expect(openurl_item.pub_date).to eq '2020.'
    expect(openurl_item.isxn).to eq '1912224224'
    expect(openurl_item.citation_source).to eq ''
  end
end
