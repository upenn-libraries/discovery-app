# frozen_string_literal: true

require 'rails_helper'

Rails.application.load_tasks

describe 'penn_lib.rake' do
  describe 'index_from_stdin' do
    let(:test_filename) { 'test_filename.xml.gz' }
    context 'with parameter usage' do
      before do
        allow_any_instance_of(FranklinIndexer).to receive(:process).and_return(true)
      end
      it 'takes a filename parameter' do
        expect(
          Rake::Task['pennlib:marc:index_from_stdin'].execute({ filename: test_filename })
        ).to be_truthy
      end

      it 'works without a filename parameter' do
        expect(
          Rake::Task['pennlib:marc:index_from_stdin'].execute
        ).to be_truthy
      end
    end

    context 'with a raised exception' do
      before do
        allow_any_instance_of(FranklinIndexer).to receive(:process).and_raise(StandardError, 'XML disaster!')
      end

      # this STDOUT hackery is inspired by https://medium.com/@jelaniwoods/rspec-tests-for-rake-tasks-da7985896014
      it 'prints helpful information to STDOUT' do
        output = StringIO.new
        $stdout = output # redirect $stdout to our own output stream temporarily
        Rake::Task['pennlib:marc:index_from_stdin'].execute({ filename: test_filename })
        $stdout = STDOUT # return to normal STDOUT
        expect(output.string).to include test_filename
        expect(output.string).to include 'XML disaster'
      end
    end
  end
end
