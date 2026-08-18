# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::TransferService, '#execute', feature_category: :groups_and_projects do
  include ElasticsearchHelpers
  let_it_be_with_reload(:user) { create(:user) }

  let(:group) { create(:group, :public) }
  let(:project) { create(:project, :public, namespace: group) }
  let(:new_group) { create(:group, :public) }

  subject(:transfer_service) { described_class.new(group, user) }

  before do
    group.add_owner(user)
    new_group&.add_owner(user)
  end

  describe '#execute' do
    it 'transfers a group successfully' do
      transfer_service.execute(new_group)

      expect(group.parent).to eq(new_group)
    end

    context 'with a knowledge graph enabled namespace' do
      before do
        create(:knowledge_graph_enabled_namespace, namespace: group)
      end

      it 'removes the enabled namespace when the group becomes a subgroup' do
        expect { transfer_service.execute(new_group) }
          .to change { group.reload.knowledge_graph_enabled_namespace }.to(nil)
      end
    end

    context 'when a transferred subgroup becomes a root group' do
      let(:parent) { create(:group) }
      let(:group) { create(:group, parent: parent) }
      let(:transfer_service) { described_class.new(group, user) }

      before do
        parent.add_owner(user)
        build(:knowledge_graph_enabled_namespace, namespace: group).save!(validate: false)
      end

      it 'keeps the enabled namespace' do
        expect { transfer_service.execute(nil) }
          .not_to change { group.reload.knowledge_graph_enabled_namespace }

        expect(group.reload).to be_root
      end
    end

    context 'with audit events' do
      before do
        stub_licensed_features(extended_audit_events: true)
      end

      it 'logs a group_path_updated audit event with path change details', :aggregate_failures do
        old_full_path = group.full_path
        new_full_path = "#{new_group.full_path}/#{group.path}"

        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(hash_including(
          name: 'group_path_updated',
          author: user,
          scope: group,
          target: group,
          message: "Changed path from #{old_full_path} to #{new_full_path}",
          target_details: new_full_path,
          additional_details: hash_including(
            change: 'path',
            from: old_full_path,
            to: new_full_path,
            target_details: new_full_path
          )
        )).and_call_original

        expect { transfer_service.execute(new_group) }.to change { AuditEventReader.count }.by(1)

        expect(AuditEventReader.order(:id).last).to have_attributes(
          author_id: user.id,
          entity_id: group.id,
          entity_type: 'Group',
          details: hash_including(
            event_name: 'group_path_updated',
            change: 'path',
            from: old_full_path,
            to: new_full_path,
            custom_message: "Changed path from #{old_full_path} to #{new_full_path}",
            target_details: new_full_path
          )
        )
      end
    end

    context 'when SAML provider or SCIM token is configured for the group' do
      let_it_be_with_reload(:group) { create(:group) }
      let_it_be_with_reload(:parent_group) { create(:group, :private) }

      before_all do
        group.add_owner(user)
        parent_group.add_owner(user)
      end

      shared_examples_for 'raises error for paid group' do
        before do
          allow(group).to receive(:paid?).and_return true
        end

        it 'returns false' do
          expect(transfer_service.execute(parent_group)).to be_falsy
        end

        it 'does not add saml provider error' do
          transfer_service.execute(parent_group)

          expect(transfer_service.error)
            .not_to eq('Transfer failed: SAML Provider or SCIM Token is configured for this group.')
        end
      end

      context 'when the group has a scim token' do
        before do
          create(:group_scim_auth_access_token, group: group)
        end

        it_behaves_like 'raises error for paid group'

        it 'adds an error on group' do
          transfer_service.execute(parent_group)

          expect(transfer_service.error)
            .to eq('Transfer failed: SAML Provider or SCIM Token is configured for this group.')
        end
      end

      context 'when the group has a saml provider' do
        before do
          create(:saml_provider, group: group)
        end

        it_behaves_like 'raises error for paid group'

        it 'adds an error on group' do
          transfer_service.execute(parent_group)

          expect(transfer_service.error)
            .to eq('Transfer failed: SAML Provider or SCIM Token is configured for this group.')
        end
      end
    end

    context 'when creator has reached their top-level group creation limit', :saas_enforce_top_level_group_limits,
      time_travel_to: User::FREE_USER_TOP_LEVEL_GROUP_LIMIT_FROM_DATE + 1.day do
      let(:user) { create(:user) }
      let(:creator) { create(:user) }

      before do
        create_list(:group, User::FREE_USER_TOP_LEVEL_GROUP_LIMIT, creator: creator)
      end

      context 'when group is a subgroup' do
        let(:parent_group) { create(:group_with_plan, :private, plan: :free_plan, creator: creator) }
        let(:group) { create(:group, :private, parent: parent_group, creator: creator) }

        it 'adds an error on the group' do
          transfer_service.execute(nil)

          expect(transfer_service.error)
            .to eq('Transfer failed: You have reached the limit of three top-level groups. To transfer this ' \
              'group to the top-level, reduce the number of top-level groups you have, or upgrade to a paid tier.')
        end

        context 'when group creator account no longer exists' do
          before do
            group
            creator.destroy!
            group.reload
          end

          context 'when current user has not reached limit' do
            it 'does not add an error' do
              transfer_service.execute(new_group)

              expect(transfer_service.error).to be_nil
            end
          end

          context 'when current user has reached limit' do
            before do
              create_list(:group, User::FREE_USER_TOP_LEVEL_GROUP_LIMIT, creator: user)
            end

            it 'adds an error' do
              transfer_service.execute(nil)

              expect(transfer_service.error)
                .to eq('Transfer failed: You have reached the limit of three top-level groups. To transfer this ' \
                  'group to the top-level, reduce the number of top-level groups you have, or upgrade to a paid tier.')
            end
          end
        end

        context 'when current user is exempt from top-level group creation limits',
          time_travel_to: User::FREE_USER_TOP_LEVEL_GROUP_LIMIT_FROM_DATE do
          it 'does not add an error' do
            transfer_service.execute(new_group)

            expect(transfer_service.error).to be_nil
          end
        end

        context 'when new parent group provided' do
          it 'does not add an error' do
            transfer_service.execute(new_group)

            expect(transfer_service.error).to be_nil
          end
        end
      end
    end

    context 'with free user cap enforced', :saas do
      before do
        stub_ee_application_setting(dashboard_limit: 1)
      end

      context 'when transferring a subgroup into root group' do
        let(:group) { create(:group_with_plan, :private, plan: :free_plan) }
        let(:subgroup) { create(:group, :private, parent: group) }
        let(:transfer_service) { described_class.new(subgroup, user) }

        before do
          create(:project, group: subgroup).tap { |r| create(:project_member, project: r) }
          stub_ee_application_setting(dashboard_limit_enabled: true)
        end

        it 'ensures there is still an owner for the transferred group' do
          expect(subgroup.all_owner_members).to be_empty

          transfer_service.execute(nil)
          subgroup.reload

          expect(subgroup.all_owner_members.preload_users.map(&:user)).to match_array(user)
          expect(subgroup.parent).to be_nil
        end
      end
    end

    context 'when transfering current status' do
      let(:transfer_status_service) { instance_double(WorkItems::Widgets::Statuses::TransferService) }
      let(:namespace_ids) { group.all_projects.pluck(:project_namespace_id) }

      it 'delegates transfer to WorkItems::Widgets::Statuses::TransferService' do
        project # load the project in order the group to has projects.
        expect(WorkItems::Widgets::Statuses::TransferService).to receive(:new).with(
          old_root_namespace: group.root_ancestor,
          new_root_namespace: new_group.root_ancestor,
          project_namespace_ids: namespace_ids
        ).and_return(transfer_status_service)
        expect(transfer_status_service).to receive(:execute)

        transfer_service.execute(new_group)
      end

      context "when new group is already root" do
        let_it_be_with_reload(:root_group) { create(:group) }
        let_it_be_with_refind(:group) { create(:group, parent: root_group) }
        let(:new_group) { nil }
        let(:transfer_lifecycle_service) { instance_double(WorkItems::Widgets::Statuses::TransferLifecycleService) }

        it 'delegates transfer to TransferLifecycleService and to TransferService' do
          project
          expect(WorkItems::Widgets::Statuses::TransferLifecycleService).to receive(:new).with(
            old_root_namespace: root_group,
            new_root_namespace: group
          ).and_return(transfer_lifecycle_service)
          expect(transfer_lifecycle_service).to receive(:execute)

          expect(WorkItems::Widgets::Statuses::TransferService).to receive(:new).with(
            old_root_namespace: root_group,
            new_root_namespace: group,
            project_namespace_ids: namespace_ids
          ).and_return(transfer_status_service)
          expect(transfer_status_service).to receive(:execute)

          transfer_service.execute(new_group)
        end

        context "with a work_item" do
          before do
            stub_licensed_features(work_item_status: true)
          end

          let_it_be_with_reload(:project) { create(:project, group: group) }
          let!(:work_item) { create(:work_item, :issue, project: project) }
          let!(:custom_lifecycle) { create(:work_item_custom_lifecycle, :for_issues, namespace: root_group) }
          let!(:custom_status) { custom_lifecycle.default_open_status }
          let!(:current_status) do
            create(:work_item_current_status, work_item: work_item, custom_status: custom_status)
          end

          it "ensures that the custom_status changes to the corresponding status of the new lifecycle" do
            expect { transfer_service.execute(new_group) }.to change { current_status.reload.custom_status_id }

            new_lifecycle = WorkItems::Statuses::Custom::Lifecycle.last

            expect(current_status.custom_status).to eq(new_lifecycle.default_open_status)
          end
        end
      end
    end
  end

  describe 'zoekt indexing', :aggregate_failures do
    let(:interval) { 0 }

    context 'when application_setting zoekt_indexing_enabled is enabled', :zoekt_settings_enabled do
      before do
        allow(::Search::Zoekt).to receive(:index?).with(group).and_return(namespace_zoekt_enabled)
        allow(::Search::Zoekt).to receive(:index?).with(project).and_return(project_zoekt_enabled)
      end

      context 'when moving the project from a non-indexed namespace to an indexed namespace' do
        let(:namespace_zoekt_enabled) { false }
        let(:project_zoekt_enabled) { true }

        it 'schedules the project to be indexed and does not delete the project' do
          expect(Search::Zoekt).not_to receive(:delete_async)
          expect(Search::Zoekt).to receive(:index_async).with(project.id).once
          transfer_service.execute(new_group)
        end
      end

      context 'when moving the project from an non-indexed namespace to a non-indexed namespace' do
        let(:namespace_zoekt_enabled) { false }
        let(:project_zoekt_enabled) { false }

        it 'does not schedule the project to be deleted and does not index anything' do
          expect(Search::Zoekt).not_to receive(:delete_async)
          expect(::Search::Zoekt).not_to receive(:index_async)
          transfer_service.execute(new_group)
        end
      end

      context 'when moving the project from an indexed namespace to an indexed namespace' do
        let(:namespace_zoekt_enabled) { true }
        let(:project_zoekt_enabled) { true }

        it 'schedules the project to be deleted and index again' do
          expect(Search::Zoekt).to receive(:delete_async).with(project.id, root_namespace_id: group.id).once
          expect(Search::Zoekt).to receive(:index_async).with(project.id).once
          transfer_service.execute(new_group)
        end
      end

      context 'when moving the project from an indexed namespace to a non-indexed namespace' do
        let(:namespace_zoekt_enabled) { true }
        let(:project_zoekt_enabled) { false }

        it 'schedules the project to be deleted and does not index anything' do
          expect(Search::Zoekt).to receive(:delete_async).with(project.id, root_namespace_id: group.id).once
          expect(::Search::Zoekt).not_to receive(:index_async)
          transfer_service.execute(new_group)
        end
      end

      context 'when project is moved in same root namespace' do
        let_it_be_with_reload(:root_group) { create(:group, :public) }
        let_it_be_with_reload(:group) { create(:group, :public, parent: root_group) }
        let_it_be_with_reload(:new_group) { create(:group, :public, parent: root_group) }
        let_it_be_with_reload(:project) { create(:project, :public, namespace: group) }
        let(:namespace_zoekt_enabled) { true }
        let(:project_zoekt_enabled) { true }

        before do
          allow(::Search::Zoekt).to receive(:index?).with(root_group).and_return(namespace_zoekt_enabled)
        end

        it 'does nothing' do
          expect(::Search::Zoekt).not_to receive(:index_async)
          expect(transfer_service).not_to receive(:process_zoekt_project)
          transfer_service.execute(new_group)
        end
      end
    end

    context 'when application_setting zoekt_indexing_enabled is disabled' do
      before do
        allow(::Search::Zoekt).to receive(:index?).with(group).and_return(namespace_zoekt_enabled)
        allow(::Search::Zoekt).to receive(:index?).with(project).and_return(project_zoekt_enabled)
      end

      context 'when moving the project from a non-indexed namespace to an indexed namespace' do
        let(:namespace_zoekt_enabled) { false }
        let(:project_zoekt_enabled) { true }

        it 'does nothing' do
          expect(Search::Zoekt).not_to receive(:delete_async)
          expect(transfer_service).not_to receive(:process_zoekt_project)
          transfer_service.execute(new_group)
        end
      end
    end

    context 'when license for zoekt_code_search feature is not available', :zoekt_settings_enabled do
      before do
        stub_licensed_features(zoekt_code_search: false)
        allow(::Search::Zoekt).to receive(:index?).with(group).and_return(namespace_zoekt_enabled)
        allow(::Search::Zoekt).to receive(:index?).with(project).and_return(project_zoekt_enabled)
      end

      context 'when moving the project from a non-indexed namespace to an indexed namespace' do
        let(:namespace_zoekt_enabled) { false }
        let(:project_zoekt_enabled) { true }

        it 'does nothing' do
          expect(Search::Zoekt).not_to receive(:delete_async)
          expect(transfer_service).not_to receive(:process_zoekt_project)
          transfer_service.execute(new_group)
        end
      end
    end
  end

  describe 'elasticsearch indexing', :aggregate_failures, :elastic do
    let!(:sub_g) { create :group, parent: group }

    before do
      stub_ee_application_setting(elasticsearch_indexing: true)
    end

    context 'when elasticsearch_limit_indexing is on' do
      before do
        stub_ee_application_setting(elasticsearch_limit_indexing: true)
      end

      context 'when moving from a non-indexed namespace to an indexed namespace' do
        before do
          create(:elasticsearch_indexed_namespace, namespace: new_group)
        end

        it 'invalidates the namespace and project cache and indexes the project and all associated data' do
          expect(project).not_to receive(:maintain_elasticsearch_update)
          expect(project).not_to receive(:maintain_elasticsearch_destroy)
          expect(::Elastic::ProcessInitialBookkeepingService).to receive(:backfill_projects!).with(project)
          expect(ElasticWikiIndexerWorker).to receive(:perform_in).with(elastic_wiki_indexer_worker_random_delay_range,
            group.id, group.class.name, { 'force' => true })
          expect(ElasticWikiIndexerWorker).to receive(:perform_in).with(elastic_wiki_indexer_worker_random_delay_range,
            sub_g.id, sub_g.class.name, { 'force' => true })
          expect(::Gitlab::CurrentSettings).to receive(:invalidate_elasticsearch_indexes_cache_for_project!)
            .with(project.id).and_call_original
          expect(::Gitlab::CurrentSettings).to receive(:invalidate_elasticsearch_indexes_cache_for_namespace!)
            .with(group.id).and_call_original

          transfer_service.execute(new_group)
        end
      end

      context 'when both namespaces are indexed' do
        before do
          create(:elasticsearch_indexed_namespace, namespace: group)
          create(:elasticsearch_indexed_namespace, namespace: new_group)
        end

        it 'invalidates the namespace and project cache and indexes the project and all associated data' do
          expect(project).not_to receive(:maintain_elasticsearch_update)
          expect(project).not_to receive(:maintain_elasticsearch_destroy)
          expect(::Elastic::ProcessInitialBookkeepingService).to receive(:backfill_projects!).with(project)
          expect(ElasticWikiIndexerWorker).to receive(:perform_in).with(elastic_wiki_indexer_worker_random_delay_range,
            group.id, group.class.name, { 'force' => true })
          expect(ElasticWikiIndexerWorker).to receive(:perform_in).with(elastic_wiki_indexer_worker_random_delay_range,
            sub_g.id, sub_g.class.name, { 'force' => true })
          expect(::Gitlab::CurrentSettings).to receive(:invalidate_elasticsearch_indexes_cache_for_project!)
            .with(project.id).and_call_original
          expect(::Gitlab::CurrentSettings).to receive(:invalidate_elasticsearch_indexes_cache_for_namespace!)
            .with(group.id).and_call_original

          transfer_service.execute(new_group)
        end
      end
    end

    context 'when elasticsearch_limit_indexing is off' do
      let(:new_group) { create(:group, :private) }

      it 'does not invalidate the namespace or project cache and reindexes projects and associated data' do
        project1 = create(:project, :public, namespace: group)
        project2 = create(:project, :public, namespace: group)
        project3 = create(:project, :private, namespace: group)

        expect(::Gitlab::CurrentSettings).not_to receive(:invalidate_elasticsearch_indexes_cache_for_namespace!)
        expect(::Gitlab::CurrentSettings).not_to receive(:invalidate_elasticsearch_indexes_cache_for_project!)
        expect(::Elastic::ProcessInitialBookkeepingService).to receive(:backfill_projects!).with(project1)
        expect(::Elastic::ProcessInitialBookkeepingService).to receive(:backfill_projects!).with(project2)
        expect(::Elastic::ProcessInitialBookkeepingService).to receive(:backfill_projects!).with(project3)
        expect(ElasticWikiIndexerWorker).to receive(:perform_in).with(elastic_wiki_indexer_worker_random_delay_range,
          group.id, group.class.name, { 'force' => true })
        expect(ElasticWikiIndexerWorker).to receive(:perform_in).with(elastic_wiki_indexer_worker_random_delay_range,
          sub_g.id, sub_g.class.name, { 'force' => true })

        transfer_service.execute(new_group)

        expect(transfer_service.error).not_to be_present
        expect(group.parent).to eq(new_group)
      end
    end

    describe 'ES doc cleanup after transfer', :aggregate_failures do
      before do
        allow(transfer_service).to receive(:delete_project_associations_with_old_routing).and_call_original
        stub_ee_application_setting(elasticsearch_indexing: true)
      end

      it 'calls delete_project_associations_with_old_routing for each project including in subgroups' do
        project2 = create(:project, namespace: group)
        subgroup = create(:group, parent: group)
        subgroup_project = create(:project, namespace: subgroup)

        expect(transfer_service).to receive(:delete_project_associations_with_old_routing).with(project)
        expect(transfer_service).to receive(:delete_project_associations_with_old_routing).with(project2)
        expect(transfer_service).to receive(:delete_project_associations_with_old_routing).with(subgroup_project)

        transfer_service.execute(new_group)

        expect(group.parent).to eq(new_group)
      end

      it 'does not schedule a DeleteWorker job when elasticsearch indexing is disabled' do
        stub_ee_application_setting(elasticsearch_indexing: false)

        expect(::Search::Elastic::DeleteWorker).not_to receive(:perform_async)

        transfer_service.execute(new_group)
      end
    end
  end

  describe '#delete_project_associations_with_old_routing' do
    before do
      stub_ee_application_setting(elasticsearch_indexing: true)
    end

    it 'schedules DeleteWorker with task: :all, correct project_id, and traversal_id' do
      project_id = project.id # force project creation before transfer
      received_args = nil
      allow(::Search::Elastic::DeleteWorker).to receive(:perform_async) do |args|
        received_args = args if args[:task]&.to_sym == :all
      end

      transfer_service.execute(new_group)

      expect(received_args).to eq(
        task: :all,
        traversal_id: project.reload.namespace.elastic_namespace_ancestry,
        project_id: project_id
      )
    end

    context 'when elasticsearch indexing is disabled' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: false)
      end

      it 'does not schedule a DeleteWorker job' do
        expect(::Search::Elastic::DeleteWorker).not_to receive(:perform_async)

        transfer_service.execute(new_group)
      end
    end
  end

  describe 'security policy synchronization' do
    subject(:transfer) { transfer_service.execute(new_group) }

    context 'with licensed feature' do
      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      it 'synchronizes security policies' do
        expect(::Security::Policies::GroupTransferWorker).to receive(:perform_async).with(group.id, user.id)

        transfer
      end
    end

    context 'without licensed feature' do
      before do
        stub_licensed_features(security_orchestration_policies: false)
      end

      it 'does not synchronize security policies' do
        expect(::Security::Policies::GroupTransferWorker).not_to receive(:perform_async)

        transfer
      end
    end
  end

  context 'with epics' do
    context 'when epics feature is disabled' do
      it 'transfers a group successfully' do
        expect(::Search::ElasticGroupAssociationDeletionWorker).not_to receive(:perform_async)
        expect(::Elastic::ProcessInitialBookkeepingService).not_to receive(:track!)
        transfer_service.execute(new_group)

        expect(group.parent).to eq(new_group)
      end
    end

    context 'when epics feature is enabled' do
      let(:root_group) { create(:group) }
      let(:subgroup_group_level_1) { create(:group, parent: root_group) }
      let(:subgroup_group_level_2) { create(:group, parent: subgroup_group_level_1) }
      let(:subgroup_group_level_3) { create(:group, parent: subgroup_group_level_2) }

      let!(:root_epic) { create(:epic, group: root_group) }
      let!(:level_1_epic_1) { create(:epic, group: subgroup_group_level_1, parent: root_epic) }
      let!(:level_1_epic_2) { create(:epic, group: subgroup_group_level_1, parent: level_1_epic_1) }
      let!(:level_2_epic_1) { create(:epic, group: subgroup_group_level_2, parent: root_epic) }
      let!(:level_2_epic_2) { create(:epic, group: subgroup_group_level_2, parent: level_1_epic_1) }
      let!(:level_2_subepic) { create(:epic, group: subgroup_group_level_2, parent: level_2_epic_2) }
      let!(:level_3_epic) { create(:epic, group: subgroup_group_level_3, parent: level_2_epic_2) }

      before do
        root_group.add_owner(user)
        stub_ee_application_setting(elasticsearch_indexing: true)
        stub_licensed_features(epics: true)
      end

      context 'when group is moved completely out of the main group' do
        it 'keeps relations between all epics' do
          expect(::Search::Elastic::DeleteWorker).to receive(:perform_async).with(
            task: :delete_groups,
            group_ids: array_including(subgroup_group_level_1.id, subgroup_group_level_2.id, subgroup_group_level_3.id),
            ancestor_id: root_group.id
          ).once
          expect(::Search::ElasticGroupAssociationDeletionWorker).to receive(:perform_async).with(
            subgroup_group_level_1.id,
            root_group.id,
            { include_descendants: true }
          ).once
          # Called twice: once for groups indexing, once for epics indexing
          expect(::Elastic::ProcessInitialBookkeepingService).to receive(:track!).twice
          described_class.new(subgroup_group_level_1, user).execute(new_group)

          expect(level_1_epic_2.reload.parent).to eq(level_1_epic_1)
          expect(level_2_epic_2.reload.parent).to eq(level_1_epic_1)
          expect(level_2_subepic.reload.parent).to eq(level_2_epic_2)
          expect(level_3_epic.reload.parent).to eq(level_2_epic_2)
          expect(level_1_epic_1.reload.parent).to eq(root_epic)
          expect(level_2_epic_1.reload.parent).to eq(root_epic)
        end

        it 'schedules deletion of old group records and work items from elasticsearch with old routing' do
          old_root_id = root_group.id

          # Verify DeleteWorker is called with delete_groups task
          expect(::Search::Elastic::DeleteWorker).to receive(:perform_async).with(
            task: :delete_groups,
            group_ids: array_including(subgroup_group_level_1.id, subgroup_group_level_2.id, subgroup_group_level_3.id),
            ancestor_id: old_root_id
          )

          # Verify ElasticGroupAssociationDeletionWorker is called to delete work items
          expect(::Search::ElasticGroupAssociationDeletionWorker).to receive(:perform_async).with(
            subgroup_group_level_1.id,
            old_root_id,
            { include_descendants: true }
          )

          described_class.new(subgroup_group_level_1, user).execute(new_group)
        end
      end

      context 'when group is moved some levels up' do
        it 'keeps relations between all epics' do
          expect(::Search::ElasticGroupAssociationDeletionWorker).not_to receive(:perform_async)

          # First call is for groups indexing, second call is for epics indexing
          expect(::Elastic::ProcessInitialBookkeepingService).to receive(:track!).ordered do |*args|
            expect(args).to all(be_a(Group))
          end
          expect(::Elastic::ProcessInitialBookkeepingService).to receive(:track!).ordered do |*args|
            expect(args).to match_array(subgroup_group_level_2.self_and_descendants.flat_map(&:epics))
          end

          described_class.new(subgroup_group_level_2, user).execute(root_group)

          expect(level_1_epic_1.reload.parent).to eq(root_epic)
          expect(level_1_epic_2.reload.parent).to eq(level_1_epic_1)
          expect(level_2_epic_1.reload.parent).to eq(root_epic)
          expect(level_2_subepic.reload.parent).to eq(level_2_epic_2)
          expect(level_3_epic.reload.parent).to eq(level_2_epic_2)
          expect(level_2_epic_2.reload.parent).to eq(level_1_epic_1)
        end
      end

      describe 'update cached metadata' do
        it 'does not schedule update of issue counts' do
          expect(::Epics::UpdateCachedMetadataWorker).not_to receive(:bulk_perform_in)

          described_class.new(subgroup_group_level_1, user).execute(new_group)
        end
      end
    end
  end

  describe '.update_project_settings' do
    let(:project_settings) { create_list(:project_setting, 2, legacy_open_source_license_available: true) }

    it 'sets `legacy_open_source_license_available` to false' do
      transfer_service.send(:update_project_settings, project_settings.pluck(:project_id))

      project_settings.each(&:reload)
      expect(project_settings.pluck(:legacy_open_source_license_available)).to match_array([false, false])
    end
  end

  describe 'updating paid features' do
    let(:sub_group) { create(:group, :public, parent: group) }

    before do
      create_list(:project, 2, :public, namespace: group)
      create(:project, :public, namespace: sub_group)
    end

    context 'when the root ancestor has changed' do
      it 'calls the service to remove paid features', :aggregate_failures do
        expect(group.all_projects.count).to eq(3)

        group.all_projects.each do |project|
          expect(::EE::Projects::RemovePaidFeaturesService).to receive(:new).with(project).and_call_original
        end

        transfer_service.execute(new_group)
      end

      context 'with pipeline subscriptions', :saas do
        before do
          create(:license, plan: License::PREMIUM_PLAN)
          stub_ee_application_setting(should_check_namespace_plan: true)
        end

        context 'when target namespace has a free plan' do
          it 'schedules cleanup for upstream project subscription' do
            group.all_projects.each do |project|
              expect(::Ci::UpstreamProjectsSubscriptionsCleanupWorker).to receive(:perform_async)
                .with(project.id)
                .and_call_original
            end

            transfer_service.execute(new_group)
          end
        end
      end
    end

    context 'when the root ancestor has not changed' do
      let(:new_group) { create(:group, :public, parent: group) }

      it 'does not call the service to remove paid features' do
        expect(::EE::Projects::RemovePaidFeaturesService).not_to receive(:new)

        transfer_service.execute(new_group)
      end
    end
  end

  context 'with compliance frameworks' do
    let_it_be(:source_root) { create(:group) }
    let_it_be_with_refind(:subgroup) { create(:group, parent: source_root) }
    let_it_be(:project_with_framework) { create(:project, namespace: subgroup) }
    let_it_be(:compliance_framework) { create(:compliance_framework, namespace: source_root) }
    let(:transfer_service) { described_class.new(subgroup, user) }

    before_all do
      source_root.add_owner(user)
    end

    before do
      stub_licensed_features(custom_compliance_frameworks: true)
      create(:compliance_framework_project_setting,
        project: project_with_framework,
        compliance_management_framework: compliance_framework)
    end

    context 'with different root group' do
      it 'removes compliance frameworks' do
        expect { transfer_service.execute(new_group) }
          .to change { project_with_framework.reload.compliance_framework_settings.count }
          .from(1).to(0)
      end
    end

    context 'with same root group' do
      let(:sibling) { create(:group, parent: source_root) }

      before do
        sibling.add_owner(user)
      end

      it 'keeps compliance frameworks' do
        expect { transfer_service.execute(sibling) }
          .not_to change { project_with_framework.reload.compliance_framework_settings.count }
      end
    end

    context 'when unlicensed' do
      before do
        stub_licensed_features(custom_compliance_frameworks: false)
      end

      it 'keeps compliance frameworks' do
        expect { transfer_service.execute(new_group) }
          .not_to change { project_with_framework.reload.compliance_framework_settings.count }
      end
    end
  end

  describe 'secrets manager deprovisioning' do
    let(:subgroup) { create(:group, parent: group) }
    let(:subgroup_project) { create(:project, namespace: subgroup) }

    before do
      # Force evaluation so the records exist before the transfer.
      subgroup
      subgroup_project
    end

    context 'when a secrets manager in the hierarchy is provisioning' do
      let!(:provisioning_sm) { create(:group_secrets_manager, group: subgroup) }

      it 'transfers anyway and leaves the provisioning SM for the orphan reaper' do
        # We do not block transfer on provisioning state. The orphan
        # reaper (gitlab-org/gitlab#600120) sweeps up any SM left in a
        # transient state after the transfer.
        expect(transfer_service.execute(new_group)).not_to be(false)
        expect(group.reload.parent).to eq(new_group)
        expect(provisioning_sm.reload).to be_provisioning
      end
    end

    context 'when active secrets managers exist on the group and its descendants' do
      let!(:group_sm) { create(:group_secrets_manager, :active, group: group) }
      let!(:subgroup_sm) { create(:group_secrets_manager, :active, group: subgroup) }
      let!(:project_sm) { create(:project_secrets_manager, :active, project: subgroup_project) }

      it 'bulk-destroys SMs for each scope, letting the AFTER DELETE trigger insert one task per row' do
        expect(SecretsManagement::GroupSecretsManagers::InitiateDeprovisionService)
          .to receive(:bulk_initiate_for_groups)
          .with(kind_of(ActiveRecord::Relation))
          .at_least(:once)
          .and_call_original

        expect(SecretsManagement::ProjectSecretsManagers::InitiateDeprovisionService)
          .to receive(:bulk_initiate_for_projects)
          .with(kind_of(ActiveRecord::Relation))
          .at_least(:once)
          .and_call_original

        transfer_service.execute(new_group)
      end

      it 'destroys every active SM in the subtree and creates one task per SM' do
        expect { transfer_service.execute(new_group) }
          .to change { SecretsManagement::GroupSecretsManagerMaintenanceTask.count }.by(2)
          .and change { SecretsManagement::ProjectSecretsManagerMaintenanceTask.count }.by(1)
          .and change {
                 SecretsManagement::GroupSecretsManager.where(id: [group_sm.id, subgroup_sm.id]).count
               }.from(2).to(0)
          .and change { SecretsManagement::ProjectSecretsManager.where(id: project_sm.id).count }.from(1).to(0)
      end

      it 'persists the OLD root and org ids on the created tasks (from the SM denormalized columns)' do
        old_root_id = group.root_ancestor.id
        old_org_id  = group.organization_id

        transfer_service.execute(new_group)

        SecretsManagement::GroupSecretsManagerMaintenanceTask.find_each do |task|
          expect(task.root_namespace_id).to eq(old_root_id)
          expect(task.organization_id).to eq(old_org_id)
        end

        SecretsManagement::ProjectSecretsManagerMaintenanceTask.find_each do |task|
          expect(task.root_namespace_id).to eq(old_root_id)
          expect(task.organization_id).to eq(old_org_id)
        end
      end

      it 'populates parent ids on the created tasks' do
        transfer_service.execute(new_group)

        expect(SecretsManagement::GroupSecretsManagerMaintenanceTask.find_by(group_id: group.id)).to be_present
        expect(SecretsManagement::GroupSecretsManagerMaintenanceTask.find_by(group_id: subgroup.id)).to be_present

        project_task = SecretsManagement::ProjectSecretsManagerMaintenanceTask.find_by(project_id: subgroup_project.id)
        expect(project_task).to be_present
      end

      it 'skips SMs already in deprovisioning state in the subtree (filter on :active)' do
        subgroup_sm.update_column(:status, SecretsManagement::BaseSecretsManager::STATUSES[:deprovisioning])

        expect { transfer_service.execute(new_group) }
          .to change { SecretsManagement::GroupSecretsManagerMaintenanceTask.count }.by(1)
          .and change { SecretsManagement::ProjectSecretsManagerMaintenanceTask.count }.by(1)

        expect(SecretsManagement::GroupSecretsManager.where(id: subgroup_sm.id).count).to eq(1)
      end

      context 'when the subtree exceeds the batch size on both scopes' do
        # Force batch size = 2 with 3 entities per scope (group + 2
        # subgroups; 3 projects). That gives one full batch + one
        # remainder per scope, exercising the each_batch loop across
        # a boundary without creating thousands of records.
        let!(:third_subgroup) { create(:group, parent: group) }
        let!(:fourth_subgroup) { create(:group, parent: group) }
        let!(:project_a) { create(:project, namespace: subgroup) }
        let!(:project_b) { create(:project, namespace: subgroup) }
        let!(:project_c) { create(:project, namespace: subgroup) }

        let!(:third_subgroup_sm) { create(:group_secrets_manager, :active, group: third_subgroup) }
        # provisioning state SM, must be skipped by the bulk filter
        let!(:fourth_subgroup_sm) { create(:group_secrets_manager, group: fourth_subgroup) }
        let!(:project_a_sm) { create(:project_secrets_manager, :active, project: project_a) }
        let!(:project_b_sm) { create(:project_secrets_manager, :active, project: project_b) }
        # provisioning state SM, must be skipped by the bulk filter
        let!(:project_c_sm) { create(:project_secrets_manager, project: project_c) }

        before do
          stub_const('EE::Groups::TransferService::GROUP_QUERY_BATCH_SIZE', 2)
          stub_const('EE::Groups::TransferService::PROJECT_QUERY_BATCH_SIZE', 2)
        end

        it 'destroys every active SM across batches and skips non-active ones' do
          # Per-scope mix: 2 active + 1 deprovisioning + 1 provisioning,
          # spread across 4 entities. Batch size 2 means 2 batches per
          # scope. The state filter must exclude the non-active SMs in
          # every batch, not just at the start of one.
          subgroup_sm.update_column(:status, SecretsManagement::BaseSecretsManager::STATUSES[:deprovisioning])
          project_a_sm.update_column(:status, SecretsManagement::BaseSecretsManager::STATUSES[:deprovisioning])

          expect { transfer_service.execute(new_group) }
            .to change { SecretsManagement::GroupSecretsManagerMaintenanceTask.count }.by(2)
            .and change { SecretsManagement::ProjectSecretsManagerMaintenanceTask.count }.by(2)

          # Originally-active SMs destroyed.
          expect(SecretsManagement::GroupSecretsManager.where(id: [group_sm.id, third_subgroup_sm.id])).to be_empty
          expect(SecretsManagement::ProjectSecretsManager.where(id: [project_sm.id, project_b_sm.id])).to be_empty

          # Non-active SMs survive: their rows still exist with the original states.
          expect(SecretsManagement::GroupSecretsManager.where(id: subgroup_sm.id).count).to eq(1)
          expect(SecretsManagement::GroupSecretsManager.where(id: fourth_subgroup_sm.id).count).to eq(1)
          expect(SecretsManagement::ProjectSecretsManager.where(id: project_a_sm.id).count).to eq(1)
          expect(SecretsManagement::ProjectSecretsManager.where(id: project_c_sm.id).count).to eq(1)

          # No tasks for the skipped non-active rows.
          group_tasks = SecretsManagement::GroupSecretsManagerMaintenanceTask
          project_tasks = SecretsManagement::ProjectSecretsManagerMaintenanceTask
          expect(group_tasks.where(group_id: [fourth_subgroup.id])).to be_empty
          expect(project_tasks.where(project_id: [project_c.id])).to be_empty
        end
      end

      it 'lets exceptions raised by the bulk delete bubble up to Sentry' do
        # The only realistic mid-transfer failure is infrastructure (DB
        # hiccup, OOM). Don't rescue; the reaper (gitlab-org/gitlab#600120)
        # backstops.
        allow(SecretsManagement::GroupSecretsManagers::InitiateDeprovisionService)
          .to receive(:bulk_initiate_for_groups)
        allow(SecretsManagement::ProjectSecretsManagers::InitiateDeprovisionService)
          .to receive(:bulk_initiate_for_projects)
          .and_raise(ActiveRecord::StatementInvalid, 'db down')

        expect { transfer_service.execute(new_group) }
          .to raise_error(ActiveRecord::StatementInvalid, /db down/)
      end
    end

    context 'when super raises mid-transfer' do
      let!(:group_sm) { create(:group_secrets_manager, :active, group: group) }

      it 'does not initiate deprovision when super fails' do
        # Force `proceed_to_transfer`'s super (the actual transfer) to fail
        # with a rescue-able error so the base service returns falsey instead
        # of bubbling the exception up.
        allow_next_instance_of(described_class) do |service|
          allow(service).to receive(:update_group_attributes)
            .and_raise(::Groups::TransferService::TransferError, 'kaboom')
        end

        expect(SecretsManagement::GroupSecretsManagers::InitiateDeprovisionService)
          .not_to receive(:bulk_initiate_for_groups)
        expect(SecretsManagement::ProjectSecretsManagers::InitiateDeprovisionService)
          .not_to receive(:bulk_initiate_for_projects)

        expect(transfer_service.execute(new_group)).to be_falsey
        expect(group_sm.reload).to be_active
      end
    end

    context 'when there are no active secrets managers in the hierarchy' do
      it 'still calls the bulk initiate methods but they no-op without creating tasks' do
        expect { transfer_service.execute(new_group) }
          .to not_change { SecretsManagement::GroupSecretsManagerMaintenanceTask.count }
          .and not_change { SecretsManagement::ProjectSecretsManagerMaintenanceTask.count }
      end
    end
  end
end
