# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Epic index', :elastic_helpers, :clean_gitlab_redis_cache, feature_category: :global_search do
  let_it_be(:user) { create(:user) }
  let_it_be(:parent_group) { create(:group) }
  let_it_be(:another_group) { create(:group) }
  let_it_be_with_refind(:group) { create(:group, parent: parent_group) }
  let_it_be_with_refind(:epic) { create(:epic, group: group) }
  let_it_be(:member) { create(:group_member, :owner, group: group, user: user) }
  let_it_be(:another_member) { create(:group_member, :owner, group: another_group, user: user) }

  let(:work_item_index) { ::Search::Elastic::Types::WorkItem.index_name }
  let(:helper) { Search::Elastic::Helper.default }
  let(:client) { helper.client }

  before do
    allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?).and_return(true)
    stub_ee_application_setting(elasticsearch_indexing: true)
    allow(::Elastic::ProcessBookkeepingService).to receive(:track!)
  end

  shared_examples 'epics get tracked in Elasticsearch' do
    it 'use_elasticsearch? is true' do
      expect(epic).to be_use_elasticsearch
    end

    context 'when an epic is created' do
      let(:epic) { build(:epic, group: group) }

      it 'tracks the epic and work item' do
        expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once do |*tracked_refs|
          expect(tracked_refs.count).to eq(1)
          expect(tracked_refs[0].class).to eq(Epic)
          expect(tracked_refs[0].id).to eq(epic.id)
        end
        expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once do |*tracked_refs|
          expect(tracked_refs.count).to eq(1)
          expect(tracked_refs[0].class).to eq(User)
        end
        expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once do |*tracked_refs|
          expect(tracked_refs.count).to eq(1)
          expect(tracked_refs[0].class).to eq(WorkItem)
          expect(tracked_refs[0].id).to eq(epic.issue_id)
        end
        epic.save!
      end
    end

    context 'when an epic is updated' do
      it 'tracks the epic' do
        expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once do |*tracked_refs|
          expect(tracked_refs.count).to eq(1)
          expect(tracked_refs[0].class).to eq(Epic)
          expect(tracked_refs[0].id).to eq(epic.id)
        end
        epic.update!(title: 'A new title')
      end
    end

    context 'when an epic is deleted' do
      it 'tracks the work item and epic' do
        expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once do |*tracked_refs|
          expect(tracked_refs.count).to eq(1)
          expect(tracked_refs[0].class).to eq(Epic)
          expect(tracked_refs[0].id).to eq(epic.id)
        end
        expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once.with(*[WorkItem.find(epic.issue_id)])
        epic.destroy!
      end

      it 'deletes the corresponding work_item from elasticsearch', :elastic_clean do
        allow(::Elastic::ProcessBookkeepingService).to receive(:track!).and_call_original

        epic = create(:epic, group: group)
        ensure_elasticsearch_index!
        expect(items_in_index(work_item_index)).to eq([epic.issue_id])

        epic.destroy!

        ensure_elasticsearch_index!
        expect(items_in_index(work_item_index)).to be_empty
      end
    end

    context 'when epic uses parent epic start and due dates', :sidekiq_inline do
      let_it_be_with_reload(:referenced_epic) { create(:epic, :use_fixed_dates) }
      let_it_be(:epic) do
        create(:epic, start_date_sourcing_epic: referenced_epic, due_date_sourcing_epic: referenced_epic)
      end

      context 'when the start date of start_date_sourcing_epic is updated' do
        it 'tracks the epic' do
          expect(epic.start_date_from_inherited_source).to eq(referenced_epic.start_date)

          expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(epic).once

          referenced_epic.update!(start_date_fixed: referenced_epic.start_date_fixed - 1.day)
        end
      end

      context 'when the due date of due_date_sourcing_epic is updated' do
        it 'tracks the epic' do
          expect(epic.due_date_from_inherited_source).to eq(referenced_epic.end_date)

          expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(epic).once

          referenced_epic.update!(due_date_fixed: referenced_epic.due_date_fixed + 1.day)
        end
      end
    end

    context 'when epic uses milestone start and due dates', :sidekiq_inline do
      let_it_be_with_reload(:milestone) { create(:milestone, :with_dates) }

      before do
        epic.update!(
          start_date_sourcing_milestone: milestone,
          due_date_sourcing_milestone: milestone
        )
      end

      context 'when start date of start_date_sourcing_milestone is updated' do
        it 'tracks the epic' do
          expect(epic.start_date_from_inherited_source).to eq(milestone.start_date)

          expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(epic).once

          milestone.update!(start_date: milestone.start_date - 1.day)
        end
      end

      context 'when due date of due_date_sourcing_milestone is updated' do
        it 'tracks the epic' do
          expect(epic.due_date_from_inherited_source).to eq(milestone.due_date)

          expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(epic).once

          milestone.update!(due_date: milestone.due_date + 1.day)
        end
      end
    end

    context 'when an epic is moved to another group' do
      it 'tracks the epic' do
        expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once do |*tracked_refs|
          expect(tracked_refs.count).to eq(1)
          expect(tracked_refs[0]).to be_a_kind_of(Epic)
          expect(tracked_refs[0].id).to eq(epic.id)
        end
        epic.update!(group: parent_group)
      end
    end

    context 'when visibility_level changes for the group', :sidekiq_inline do
      it 'tracks the epic via ElasticAssociationIndexerWorker' do
        allow(ElasticWikiIndexerWorker).to receive(:perform_async)
        expect(ElasticAssociationIndexerWorker).to receive(:perform_async)
          .with(anything, group.id, %w[epics work_items])
          .and_call_original

        expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(epic).once
        expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(epic.work_item).once

        group.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)
      end
    end

    context 'when the group is deleted', :sidekiq_inline do
      it 'deletes the epic from elasticsearch via Search::ElasticGroupAssociationDeletionWorker', :elastic_clean do
        expect(Search::ElasticGroupAssociationDeletionWorker).to receive(:perform_async)
          .with(group.id, parent_group.id).and_call_original
        allow(::Elastic::ProcessBookkeepingService).to receive(:track!).and_call_original

        epic = create(:epic, group: group)
        ensure_elasticsearch_index!
        expect(items_in_index(work_item_index)).to eq([epic.issue_id])

        Groups::DestroyService.new(group, user).execute

        ensure_elasticsearch_index!
        expect(items_in_index(work_item_index)).to be_empty
      end
    end

    context 'when the parent of the group is changed', :sidekiq_inline do
      before do
        stub_licensed_features(epics: true)
      end

      it 'tracks the epic via Elastic::NamespaceUpdateWorker if the new parent has indexing enabled' do
        expect(Elastic::NamespaceUpdateWorker).to receive(:perform_async).with(group.id).and_call_original
        expect(ElasticAssociationIndexerWorker).to receive(:perform_async)
          .with(anything, group.id, %w[epics work_items])
          .and_call_original

        expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(epic).once
        expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(epic.work_item).once
        group.update!(parent: another_group)
      end
    end

    context 'when the group is transferred', :sidekiq_inline do
      before do
        stub_licensed_features(epics: true)
      end

      it 'tracks the epic via Elastic::NamespaceUpdateWorker' do
        allow(ElasticWikiIndexerWorker).to receive(:perform_in)
        expect(Elastic::NamespaceUpdateWorker).to receive(:perform_async).with(group.id).and_call_original
        expect(Search::Elastic::DeleteWorker).to receive(:perform_async)
          .with(hash_including(task: :delete_groups, group_ids: [group.id], ancestor_id: parent_group.id)).once
        expect(Search::ElasticGroupAssociationDeletionWorker).to receive(:perform_async)
          .with(group.id, parent_group.id, { include_descendants: true }).once
        expect(ElasticAssociationIndexerWorker).to receive(:perform_async)
          .with(anything, group.id, %w[epics work_items])
          .and_call_original

        expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(epic.work_item).once
        expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(epic).once
        expect(::Elastic::ProcessInitialBookkeepingService).to receive(:track!).with(group).once
        expect(::Elastic::ProcessInitialBookkeepingService).to receive(:track!).with(epic).once
        Groups::TransferService.new(group, user).execute(another_group)
      end
    end
  end

  shared_examples 'epics do not get tracked in Elasticsearch' do
    it 'use_elasticsearch? is false' do
      expect(epic).not_to be_use_elasticsearch
    end

    context 'when an epic is created' do
      let(:epic) { build(:epic, group: group) }

      it 'does not track the epic' do
        expect(::Elastic::ProcessBookkeepingService).not_to receive(:track!).with(epic)
        epic.save!
      end
    end

    context 'when an epic is updated' do
      it 'does not track the epic' do
        expect(::Elastic::ProcessBookkeepingService).not_to receive(:track!).with(epic)
        epic.update!(title: 'A new title')
      end
    end

    context 'when an epic is deleted' do
      it 'does not track the epic' do
        expect(::Elastic::ProcessBookkeepingService).not_to receive(:track!).with(epic)
        epic.destroy!
      end
    end

    context 'when visibility_level changes for the group', :sidekiq_inline do
      it 'does not track the epic via ElasticAssociationIndexerWorker' do
        expect(ElasticAssociationIndexerWorker).not_to receive(:perform_async)

        expect(::Elastic::ProcessBookkeepingService).not_to receive(:track!).with(epic)

        group.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)
      end
    end

    context 'when an epic is moved to another group' do
      it 'does not track the epic' do
        expect(::Elastic::ProcessBookkeepingService).not_to receive(:track!).with(epic)
        epic.update!(group: create(:group))
      end
    end

    context 'when the parent of the group is changed', :sidekiq_inline do
      it 'does not track the epic' do
        allow(Elastic::NamespaceUpdateWorker).to receive(:perform_async).with(group.id).and_call_original

        expect(::Elastic::ProcessBookkeepingService).not_to receive(:track!).with(epic)
        group.update!(parent: nil)
      end
    end

    context 'when the group is transferred', :sidekiq_inline do
      it 'does not track the epic' do
        allow(Elastic::NamespaceUpdateWorker).to receive(:perform_async).with(group.id).and_call_original
        allow(ElasticWikiIndexerWorker).to receive(:perform_in)

        expect(::Elastic::ProcessBookkeepingService).not_to receive(:track!).with(epic)
        Groups::TransferService.new(group, user).execute(nil)
      end
    end
  end

  it_behaves_like 'epics get tracked in Elasticsearch'

  context 'when elasticsearch_limit_indexing? is true' do
    before do
      stub_ee_application_setting(elasticsearch_limit_indexing?: true)
    end

    context 'if the parent group is in the limited indexes list' do
      let_it_be(:indexed_namespace) { create(:elasticsearch_indexed_namespace, namespace: parent_group) }
      let_it_be(:another_indexed_namespace) { create(:elasticsearch_indexed_namespace, namespace: another_group) }

      it_behaves_like 'epics get tracked in Elasticsearch'

      context 'if the parent group is removed from the list' do
        before do
          stub_licensed_features(epics: true)
        end

        it 'deletes the epic from elasticsearch', :elastic_clean, :sidekiq_inline do
          # parent group and sub group
          allow(Search::Wiki::ElasticDeleteGroupWikiWorker).to receive(:perform_in).twice

          expect(Search::ElasticGroupAssociationDeletionWorker).to receive(:perform_in)
            .with(elastic_group_association_deletion_worker_random_delay_range, group.id, parent_group.id)
            .and_call_original

          expect(Search::ElasticGroupAssociationDeletionWorker).to receive(:perform_in)
            .with(elastic_group_association_deletion_worker_random_delay_range, parent_group.id, parent_group.id)
            .and_call_original

          allow(::Elastic::ProcessBookkeepingService).to receive(:track!).and_call_original

          epic = create(:epic, group: group)
          ensure_elasticsearch_index!
          expect(items_in_index(work_item_index)).to eq([epic.issue_id])

          indexed_namespace.destroy!

          ensure_elasticsearch_index!
          expect(items_in_index(work_item_index)).to be_empty
        end
      end
    end

    context 'if the parent group is not in the limited indexes list' do
      it_behaves_like 'epics do not get tracked in Elasticsearch'

      context 'if the group is added to limited index list', :sidekiq_inline do
        it 'tracks the epic via ElasticNamespaceIndexerWorker' do
          allow(ElasticWikiIndexerWorker).to receive(:perform_in)
          expect(ElasticNamespaceIndexerWorker).to receive(:perform_async).with(group.id, 'index').and_call_original

          expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(epic).once

          create(:elasticsearch_indexed_namespace, namespace: group)
        end
      end
    end
  end
end
