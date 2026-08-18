# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Elastic::MaintainElasticsearchOnGroupUpdate, feature_category: :global_search do
  describe 'callbacks' do
    let_it_be_with_refind(:group) { create(:group) }

    describe '.after_create_commit' do
      context 'when elastic is enabled' do
        before do
          stub_ee_application_setting(elasticsearch_indexing: true)
        end

        it 'calls ElasticWikiIndexerWorker' do
          expect(ElasticWikiIndexerWorker).to receive(:perform_async).with(anything, 'Group', 'force' => true)
          create(:group, :wiki_repo)
        end
      end

      context 'when elasticsearch is disabled' do
        it 'does not call ElasticWikiIndexerWorker' do
          expect(ElasticWikiIndexerWorker).not_to receive(:perform_async).with(anything, 'Group', 'force' => true)
          create(:group, :wiki_repo)
        end
      end
    end

    describe '.after_update_commit' do
      let(:new_visibility_level) { Gitlab::VisibilityLevel::PRIVATE }

      context 'when use_elasticsearch? is true' do
        before do
          allow(group).to receive(:use_elasticsearch?).and_return true
        end

        it 'calls ElasticWikiIndexerWorker when group visibility_level is changed' do
          expect(ElasticWikiIndexerWorker).to receive(:perform_async).with(group.id, group.class.name, 'force' => true)
          group.update_attribute(:visibility_level, new_visibility_level)
        end

        it 'does not call ElasticWikiIndexerWorker when attribute other than visibility_level is changed' do
          expect(ElasticWikiIndexerWorker).not_to receive(:perform_async)
            .with(group.id, group.class.name, 'force' => true)
          group.update_attribute(:name, "#{group.name}_new")
        end
      end

      context 'when use_elasticsearch?? is false' do
        before do
          allow(group).to receive(:use_elasticsearch?).and_return false
        end

        it 'does not call ElasticWikiIndexerWorker' do
          expect(ElasticWikiIndexerWorker).not_to receive(:perform_async).with(group.id, 'Group', 'force' => true)
          group.update_attribute(:visibility_level, new_visibility_level)
        end
      end

      context 'when visibility_level is changed' do
        it 'calls Elastic::ProcessBookkeepingService.maintain_indexed_namespace_associations!' do
          expect(Elastic::ProcessBookkeepingService).to receive(:maintain_indexed_namespace_associations!)
            .with(group).once

          group.update_attribute(:visibility_level, new_visibility_level)
        end
      end

      context 'when visibility_level is not changed' do
        it 'does not call Elastic::ProcessBookkeepingService.maintain_indexed_namespace_associations!' do
          expect(Elastic::ProcessBookkeepingService).not_to receive(:maintain_indexed_namespace_associations!)
            .with(group)

          group.update_attribute(:name, "#{group.name}_new")
        end
      end
    end

    describe '.after_destroy_commit' do
      context 'when use_elasticsearch? is true' do
        before do
          allow(group).to receive(:use_elasticsearch?).and_return true
        end

        it 'calls Search::Wiki::ElasticDeleteGroupWikiWorker' do
          expect(Search::Wiki::ElasticDeleteGroupWikiWorker).to receive(:perform_async)
            .with(group.id, 'namespace_routing_id' => group.root_ancestor.id)
          group.destroy!
        end
      end

      context 'when use_elasticsearch? is false' do
        before do
          allow(group).to receive(:use_elasticsearch?).and_return false
        end

        it 'does not call Search::Wiki::ElasticDeleteGroupWikiWorker' do
          expect(Search::Wiki::ElasticDeleteGroupWikiWorker).not_to receive(:perform_async).with(group.id)
          group.destroy!
        end
      end

      it 'enqueues Search::ElasticGroupAssociationDeletionWorker' do
        expect(Search::ElasticGroupAssociationDeletionWorker).to receive(:perform_async)
          .with(group.id, group.root_ancestor.id).once

        group.destroy!
      end
    end
  end
end
