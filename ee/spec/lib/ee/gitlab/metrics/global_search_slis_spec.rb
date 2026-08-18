# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Metrics::GlobalSearchSlis, feature_category: :global_search do
  using RSpec::Parameterized::TableSyntax

  describe '#initialize_slis!' do
    let(:aggregations_label) { a_hash_including(endpoint_id: 'SearchController#aggregations') }

    where(:search_type, :search_scope, :search_level, :valid) do
      'advanced' | 'wiki_blobs' | 'global'  | true
      'advanced' | 'wiki_blobs' | 'project' | true
      'advanced' | 'blobs'      | 'global'  | true
      'zoekt'    | 'blobs'      | 'global'  | true
      'zoekt'    | 'blobs'      | 'group'   | true
      'zoekt'    | 'blobs'      | 'project' | true
      'advanced' | 'work_items' | 'global'  | true
      'basic'    | 'work_items' | 'global'  | true
      'basic'    | 'work_items' | 'group'   | true
      'zoekt'    | 'work_items' | 'global'  | false
      'zoekt'    | 'wiki_blobs' | 'global'  | false
    end

    with_them do
      it 'initializes valid label combinations and excludes impossible ones' do
        if valid
          expect(Gitlab::Metrics::Sli::Apdex).to receive(:initialize_sli).with(
            :global_search, array_including(a_hash_including(
              search_type: search_type, search_scope: search_scope, search_level: search_level
            ))
          )
        else
          expect(Gitlab::Metrics::Sli::Apdex).not_to receive(:initialize_sli).with(
            :global_search, array_including(a_hash_including(
              search_type: search_type, search_scope: search_scope, search_level: search_level
            ))
          )
        end

        described_class.initialize_slis!
      end
    end

    context 'when running in a web environment' do
      before do
        allow(Gitlab::Metrics::Environment).to receive_messages(web?: true, api?: false)
      end

      it 'includes SearchController#aggregations in Apdex SLI labels' do
        expect(Gitlab::Metrics::Sli::Apdex).to receive(:initialize_sli).with(
          :global_search, array_including(aggregations_label)
        )

        described_class.initialize_slis!
      end

      it 'includes SearchController#aggregations in ErrorRate SLI labels' do
        expect(Gitlab::Metrics::Sli::ErrorRate).to receive(:initialize_sli).with(
          :global_search, array_including(aggregations_label)
        )

        described_class.initialize_slis!
      end
    end

    context 'when running in an API environment' do
      before do
        allow(Gitlab::Metrics::Environment).to receive_messages(web?: false, api?: true)
      end

      it 'does not include SearchController#aggregations in SLI labels' do
        expect(Gitlab::Metrics::Sli::Apdex).not_to receive(:initialize_sli).with(
          :global_search, array_including(aggregations_label)
        )

        described_class.initialize_slis!
      end
    end
  end
end
