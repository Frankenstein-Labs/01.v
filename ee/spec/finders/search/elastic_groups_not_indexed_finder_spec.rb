# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::ElasticGroupsNotIndexedFinder, :elastic, :sidekiq_inline, feature_category: :global_search do
  describe '.execute' do
    let_it_be(:group) { create(:group) }
    let_it_be(:group2) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: group) }

    subject(:execute) { described_class.execute }

    context 'when on GitLab.com', :saas do
      it 'raises an error' do
        expect { execute }.to raise_error('This cannot be run on GitLab.com')
      end
    end

    context 'when limit indexing is disabled' do
      context 'when no groups are indexed' do
        it 'returns all groups' do
          expect(execute).to match_array([group, group2, subgroup])
        end
      end

      context 'when some groups are indexed' do
        before do
          create(:group_index_status, group: subgroup)
        end

        it 'returns unindexed groups' do
          expect(execute).to match_array([group, group2])
        end
      end
    end

    context 'when limit indexing is enabled' do
      before do
        stub_ee_application_setting(elasticsearch_limit_indexing: true)
        create(:elasticsearch_indexed_namespace, namespace: group)
      end

      context 'when no groups are indexed' do
        it 'returns all groups that are included in limited indexing' do
          expect(execute).to match_array([group, subgroup])
        end
      end

      context 'when some groups are indexed' do
        before do
          create(:group_index_status, group: subgroup)
        end

        it 'returns unindexed groups that are included in limited indexing' do
          expect(execute).to match_array([group])
        end
      end
    end
  end
end
