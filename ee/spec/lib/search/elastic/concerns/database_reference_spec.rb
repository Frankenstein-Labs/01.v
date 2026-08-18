# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::Concerns::DatabaseReference, :elastic_helpers, feature_category: :global_search do
  describe '#apply_field_limit' do
    let(:test_object) { Object.new }

    before do
      test_object.extend(described_class)
    end

    context 'when result is not a string' do
      let(:result) { create_list(:project, 2) }

      it 'no limit check is done' do
        expect(test_object.apply_field_limit(result)).to eq(result)
      end
    end

    context 'when result is a string' do
      let(:result) { 'foobar' }

      context 'when limit is less than results' do
        before do
          stub_ee_application_setting(elasticsearch_indexed_field_length_limit: 3)
        end

        it 'returns all the results' do
          expect(test_object.apply_field_limit(result).length).to eq(3)
        end
      end

      context 'when limit is 0' do
        before do
          stub_ee_application_setting(elasticsearch_indexed_field_length_limit: 0)
        end

        it 'returns all the results' do
          expect(test_object.apply_field_limit(result).length).to eq(result.length)
        end
      end
    end
  end
end
