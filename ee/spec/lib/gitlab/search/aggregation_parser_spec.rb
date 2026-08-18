# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Search::AggregationParser, feature_category: :global_search do
  describe '.call' do
    subject(:call) { described_class.call(aggregations) }

    shared_examples 'parses aggregations' do
      context 'when elasticsearch buckets are provided' do
        context 'for work item search with work_item_type_ids aggregations' do
          let(:work_item_type) { build(:work_item_system_defined_type, :issue) }
          let(:work_item_type2) { build(:work_item_system_defined_type, :task) }

          let!(:elastic_aggregations) do
            {
              'aggregations' =>
                {
                  'work_item_type_ids' =>
                    {
                      'buckets' =>
                        [
                          { 'key' => work_item_type.id.to_s, 'doc_count' => 25 },
                          { 'key' => work_item_type2.id.to_s, 'doc_count' => 10 },
                          { 'key' => non_existing_record_id.to_s, 'doc_count' => 3 }
                        ]
                    }
                }
            }
          end

          it 'adds work item type-specific fields for existing records only' do
            expect { call }.not_to exceed_query_limit(0)

            expect(call.length).to eq(1)
            expect(call.first.name).to eq('work_item_type_ids')
            expect(call.first.buckets.length).to eq(2)
            expect(call.first.buckets.first.symbolize_keys).to match(
              key: work_item_type.id.to_s,
              count: 25,
              name: work_item_type.name,
              icon_name: work_item_type.icon_name,
              base_type: work_item_type.base_type
            )
          end
        end

        context 'for code search' do
          let(:elastic_aggregations) do
            {
              'aggregations' =>
                {
                  'terms_agg' =>
                    {
                      'buckets' =>
                        [
                          { 'key' => 'Markdown', 'doc_count' => 142 },
                          { 'key' => 'C', 'doc_count' => 6 },
                          { 'key' => 'C++', 'doc_count' => 1 }
                        ]
                    },
                  'composite_agg' =>
                    {
                      'after_key' => { 'composite_agg' => 'Makefile' },
                      'buckets' =>
                        [
                          { 'key' => { 'composite_agg' => 'JavaScript' }, 'doc_count' => 1000 },
                          { 'key' => { 'composite_agg' => 'Java' }, 'doc_count' => 3 }
                        ]
                    }
                }
            }
          end

          it 'parses the results' do
            expected_buckets_1 = [
              { key: 'Markdown', count: 142 },
              { key: 'C', count: 6 },
              { key: 'C++', count: 1 }
            ]
            expected_buckets_2 = [
              { key: { composite_agg: 'JavaScript' }, count: 1000 },
              { key: { composite_agg: 'Java' }, count: 3 }
            ]

            expect(call.length).to eq(2)
            expect(call.first.name).to eq('terms_agg')
            expect(call.first.buckets).to match_array(expected_buckets_1)
            expect(call.second.name).to eq('composite_agg')
            expect(call.second.buckets).to match_array(expected_buckets_2)
          end
        end

        context 'for issue search with labels aggregations' do
          let(:label1) { create(:label) }
          let(:label2) { create(:label) }

          let!(:elastic_aggregations) do
            {
              'aggregations' =>
                {
                  'labels' =>
                    {
                      'buckets' =>
                        [
                          { 'key' => non_existing_record_id.to_s, 'doc_count' => 14 },
                          { 'key' => label2.id.to_s, 'doc_count' => 6 }
                        ]
                    }
                }
            }
          end

          it 'adds label-specific fields for existing records only' do
            expect { call }.not_to exceed_query_limit(5)

            expect(call.length).to eq(1)
            expect(call.first.name).to eq('labels')
            expect(call.first.buckets.first.symbolize_keys).to match(
              key: label2.id.to_s,
              count: 6,
              title: label2.title,
              type: label2.type,
              color: label2.color.to_s,
              parent_full_name: label2.project.full_name
            )
          end
        end
      end

      context 'when aggregations are not present' do
        let(:elastic_aggregations) { {} }

        it 'parses the results' do
          expect(call).to be_empty
        end

        context 'when aggregations are not present' do
          let(:elastic_aggregations) { {} }

          it 'parses the results' do
            expect(call).to be_empty
          end
        end
      end
    end

    context 'when passed an Elasticsearch::Model::Response::Response instance' do
      let(:search) do
        Elasticsearch::Model::Searching::SearchRequest.new(Issue, '*').tap do |request|
          allow(request).to receive(:execute!).and_return(elastic_aggregations)
        end
      end

      let(:aggregations) do
        Elasticsearch::Model::Response::Response.new(Issue, search).aggregations
      end

      it_behaves_like 'parses aggregations'
    end

    context 'when passed a Hash instance' do
      let(:aggregations) do
        ::Search::Elastic::ResponseMapper.new(elastic_aggregations).aggregations
      end

      it_behaves_like 'parses aggregations'
    end
  end
end
