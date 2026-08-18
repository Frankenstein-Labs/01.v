# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::ResponseMapper, feature_category: :global_search do
  let(:mapper) { described_class.new(response, options) }
  let(:options) { { klass: Issue, page: 1, per_page: 10 } }
  let_it_be(:issues) { create_list(:issue, 3) }
  let_it_be(:response) do
    { aggregations: 'test',
      hits: { total: { value: issues.count }, hits: [] } }.tap do |resp|
      issues.reverse_each do |issue|
        resp[:hits][:hits] << { _id: "issue_#{issue.id}", _source: { id: issue.id }, highlight: issue.title }
      end
    end
  end

  describe '#aggregations' do
    it 'returns the aggregation key from the response' do
      expect(mapper.aggregations).to eq('test')
    end
  end

  describe '#records' do
    let(:options) { { klass: Issue, page: 1, per_page: 10 } }

    it 'returns sql records from the klass provided in the order from results' do
      expect(mapper.records).to eq(issues.reverse)
    end

    it 'does not call public_send when preload_method is not provided it options' do
      mock_instance = instance_double('Issue::ActiveRecord_Relation', sort_by: [])
      allow(Issue).to receive(:preload_search_data).and_return(mock_instance)
      expect(mock_instance).not_to receive(:public_send)

      mapper.records
    end

    context 'when a preload_method is provided in options' do
      let(:options) { { klass: Issue, page: 1, per_page: 10, preload_method: :with_web_entity_associations } }

      it 'calls the preload method' do
        mock_instance = instance_double(Issue)
        allow(Issue).to receive(:preload_search_data).and_return(mock_instance)
        expect(mock_instance).to receive(:public_send).with(:with_web_entity_associations).and_return(Issue.none)

        mapper.records
      end
    end
  end

  describe '#highlight_map' do
    it 'returns a highlight map hash from response' do
      expected = issues.each_with_object({}) do |issue, hash|
        hash[issue.id] = issue.title
      end

      expect(mapper.highlight_map).to eq(expected)
    end
  end

  describe '#total_count' do
    it 'returns a total value from response' do
      expect(mapper.total_count).to eq(issues.count)
    end
  end

  describe '#paginated_array' do
    it 'returns a Kaminari::Paginatable type' do
      expect(mapper.paginated_array).to be_a(Kaminari::PaginatableArray)
    end
  end

  describe '#failed?' do
    it 'returns false by default' do
      expect(mapper.failed?).to be(false)
    end

    context 'when error is provided in options' do
      let(:response) { { error: 'test error' } }

      it 'returns true' do
        expect(mapper.failed?).to be(true)
      end
    end
  end

  describe '#error' do
    it 'return nil by default' do
      expect(mapper.error).to be_nil
    end

    context 'when error is provided in response' do
      let(:response) { { error: 'test error' } }

      it 'returns the error' do
        expect(mapper.error).to eq('test error')
      end
    end
  end

  describe '#error_type' do
    it 'return nil by default' do
      expect(mapper.error_type).to be_nil
    end

    context 'when error_type is provided in response' do
      let(:response) { { error: { type: 'an error type', reason: 'test error' } } }

      it 'returns the error' do
        expect(mapper.error_type).to eq('an error type')
      end
    end
  end
end
