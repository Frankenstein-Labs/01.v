# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ElasticDeleteProjectWorker, feature_category: :global_search do
  subject(:worker) { described_class.new }

  context 'when elasticsearch_indexing is false' do
    before do
      stub_ee_application_setting(elasticsearch_indexing: false)
    end

    it 'does nothing' do
      expect(::Search::Elastic::DeleteWorker).not_to receive(:perform_async)

      worker.perform(1, 'project_1')
    end
  end

  context 'when elasticsearch_indexing is true', :elastic do
    let_it_be(:project_index) { Project.index_name }
    let_it_be(:milestone_index) { Repository.index_name }
    let_it_be(:code_index) { Repository.index_name }
    let_it_be(:merge_request_index) { MergeRequest.index_name }
    let_it_be(:note_index) { Note.index_name }
    let_it_be(:wiki_index) { Wiki.index_name }
    let_it_be(:work_item_index) { ::Search::Elastic::Types::WorkItem.index_name }

    # Create admin user and search globally to avoid dealing with permissions in
    # these tests
    let_it_be(:user) { create(:admin) }
    let_it_be(:group) { create(:group, owners: user) }
    let_it_be_with_reload(:project) { create(:project, group: group) }
    let_it_be(:issue) { create(:issue, project: project) }
    let_it_be(:milestone) { create(:milestone, project: project) }
    let_it_be(:note) { create(:note, project: project) }
    let_it_be(:merge_request) { create(:merge_request, target_project: project, source_project: project) }
    # `freeze: false` is required here: `project.wiki` returns a ProjectWiki
    # PORO that memoizes state and is mutated by `create_page`; freezing it
    # raises FrozenError. Keep the opt-out (see gitlab-org/gitlab#602925).
    let_it_be(:wiki, freeze: false) { project.wiki.create_page('index_page', 'Bla bla term') }

    let(:helper) { Search::Elastic::Helper.default }

    before do
      stub_ee_application_setting(elasticsearch_indexing: true)

      allow(::Search::Elastic::Helper).to receive(:default).and_return(helper)
    end

    # Extracted to a method as the `#elastic_search` methods using it below will
    # mutate the hash and mess up the following searches
    def search_options
      { options: { search_level: 'global', current_user: user, project_ids: :any } }
    end

    it 'deletes a project with all nested objects and clears the index_status', :sidekiq_inline, :enable_admin_mode do
      ::Elastic::ProcessInitialBookkeepingService.backfill_projects!(project)

      ensure_elasticsearch_index!

      expect(project.reload.index_status).not_to be_nil
      expect(items_in_index(project_index)).to include(project.id)
      expect(items_in_index(work_item_index)).to include(issue.id)
      # milestone is in the main index with code
      # too many records come back to check using items_in_index
      expect(Milestone.elastic_search('*', **search_options).records).to include(milestone)
      expect(items_in_index(note_index)).to include(note.id)
      expect(items_in_index(merge_request_index)).to include(merge_request.id)
      expect(items_in_index(code_index).count).to be > 0
      expect(items_in_index(wiki_index).count).to be > 0

      expect(::Search::Elastic::DeleteWorker).to receive(:perform_async).with({
        'task' => 'all',
        'project_id' => project.id
      }).once.and_call_original
      allow(::Search::Elastic::DeleteWorker).to receive(:perform_async).and_call_original

      worker.perform(project.id, project.es_id)

      ensure_elasticsearch_index!

      expect(items_in_index(project_index).count).to eq(0)
      expect(items_in_index(work_item_index).count).to eq(0)
      expect(Milestone.elastic_search('*', **search_options).total_count).to eq(0)
      expect(items_in_index(note_index).count).to eq(0)
      expect(items_in_index(merge_request_index).count).to eq(0)
      expect(items_in_index(code_index).count).to eq(0)
      expect(items_in_index(wiki_index).count).to eq(0)

      # verify that entire main index is empty
      expect(helper.documents_count).to eq(0)
      expect(items_in_index(work_item_index).count).to eq(0)

      expect(project.reload.index_status).to be_nil
    end

    it 'does not include indexes which do not exist' do
      allow(::Search::Elastic::Helper).to receive(:default).and_return(helper)
      allow(helper).to receive(:index_exists?).and_return(false)

      expect(::Search::Elastic::DeleteWorker).to receive(:perform_async).with({
        'task' => 'all',
        'project_id' => 1
      }).once

      # this is called in other spots
      allow(helper.client).to receive(:delete_by_query)

      # test that it only includes one index, all others are stubbed to not exist
      expect(helper.client).to receive(:delete_by_query).with(a_hash_including(index: [helper.target_name]))

      worker.perform(1, 2)
    end

    it 'does not raise exception when project document not found' do
      expect { worker.perform(non_existing_record_id, "project_#{non_existing_record_id}") }.not_to raise_error
    end

    context 'when there is a version conflict in remove_project_document' do
      before do
        allow(helper.client).to receive(:delete_by_query)

        # cover both paths to avoid flaky tests
        allow(helper.client).to receive(:delete)
          .with(a_hash_including(index: project_index))
          .and_raise(Elasticsearch::Transport::Transport::Errors::Conflict)

        allow(helper.client).to receive(:delete_by_query)
          .with(a_hash_including(index: project_index))
          .and_raise(Elasticsearch::Transport::Transport::Errors::Conflict)
      end

      it 'enqueues the worker to try again' do
        expect(described_class).to receive(:perform_in).with(1.minute, 1, 2, {}).once

        expect { worker.perform(1, 2) }.not_to raise_error
      end
    end

    context 'when there is a version conflict in remove_children_documents' do
      before do
        allow(helper).to receive_messages(standalone_indices_proxies: [], remove_wikis_from_the_standalone_index: nil)

        allow(helper.client).to receive(:delete_by_query)

        allow(helper.client).to receive(:delete_by_query)
          .with(a_hash_including(index: [helper.target_name]))
          .and_raise(Elasticsearch::Transport::Transport::Errors::Conflict)

        ::Elastic::ProcessInitialBookkeepingService.track!(project)
        ::Elastic::ProcessInitialBookkeepingService.maintain_indexed_associations(project, [:issues])

        ensure_elasticsearch_index!
      end

      it 'enqueues the worker to try again' do
        expect(described_class).to receive(:perform_in).with(1.minute, project.id, project.es_id, {}).once

        expect { worker.perform(project.id, project.es_id) }.not_to raise_error
      end
    end

    context 'when namespace_routing_id is passed in options', :enable_admin_mode do
      it 'deletes the project' do
        ::Elastic::ProcessInitialBookkeepingService.backfill_projects!(project)

        ensure_elasticsearch_index!

        expect(items_in_index(project_index)).to include(project.id)

        worker.perform(project.id, project.es_id, namespace_routing_id: group.id)

        ensure_elasticsearch_index!

        expect(items_in_index(project_index)).not_to include(project.id)
      end

      it 'does not raise exception when namespace document not found' do
        expect do
          worker.perform(project.id, project.es_id, namespace_routing_id: non_existing_record_id)
        end.not_to raise_error
      end
    end

    context 'when passed delete_project option of false', :sidekiq_inline, :enable_admin_mode do
      it 'deletes only the nested objects and clears the index_status' do
        ::Elastic::ProcessInitialBookkeepingService.backfill_projects!(project)

        ensure_elasticsearch_index!

        expect(project.reload.index_status).not_to be_nil
        expect(items_in_index(project_index)).to include(project.id)
        expect(items_in_index(work_item_index)).to include(issue.id)
        expect(Milestone.elastic_search('*', **search_options).records).to include(milestone)
        expect(items_in_index(note_index)).to include(note.id)
        expect(items_in_index(merge_request_index)).to include(merge_request.id)
        expect(items_in_index(code_index).count).to be > 0
        expect(items_in_index(wiki_index).count).to be > 0

        expect(::Search::Elastic::DeleteWorker).to receive(:perform_async).with({
          'task' => 'all',
          'project_id' => project.id
        }).once.and_call_original
        allow(::Search::Elastic::DeleteWorker).to receive(:perform_async).and_call_original

        worker.perform(project.id, project.es_id, delete_project: false)

        ensure_elasticsearch_index!

        expect(items_in_index(project_index)).to include(project.id)
        expect(items_in_index(project_index).count).to eq(1)
        expect(items_in_index(work_item_index).count).to eq(0)
        expect(items_in_index(milestone_index).count).to eq(0)
        expect(items_in_index(note_index).count).to eq(0)
        expect(items_in_index(merge_request_index).count).to eq(0)
        expect(items_in_index(code_index).count).to eq(0)
        expect(items_in_index(wiki_index).count).to eq(0)

        # verify that entire main index is empty
        expect(helper.documents_count).to eq(0)

        expect(project.reload.index_status).to be_nil
      end
    end

    context 'when passed project_only option of true', :sidekiq_inline, :enable_admin_mode do
      it 'deletes only the project objects' do
        allow(::Search::Elastic::Helper).to receive(:default).and_return(helper)

        ::Elastic::ProcessInitialBookkeepingService.backfill_projects!(project)

        ensure_elasticsearch_index!

        expect(project.reload.index_status).not_to be_nil
        expect(items_in_index(project_index)).to include(project.id)
        expect(items_in_index(work_item_index)).to include(issue.id)
        expect(Milestone.elastic_search('*', **search_options).records).to include(milestone)
        expect(items_in_index(note_index)).to include(note.id)
        expect(items_in_index(merge_request_index)).to include(merge_request.id)
        expect(items_in_index(code_index).count).to be > 0
        expect(items_in_index(wiki_index).count).to be > 0

        expect(helper.client).to receive(:delete)
          .with(a_hash_including(index: project_index)).once.and_call_original

        expect(::Search::Elastic::DeleteWorker).not_to receive(:perform_async)

        worker.perform(project.id, project.es_id, project_only: true)

        ensure_elasticsearch_index!

        expect(project.reload.index_status).not_to be_nil
        expect(items_in_index(project_index).count).to eq(0)
        expect(items_in_index(work_item_index)).to include(issue.id)
        expect(Milestone.elastic_search('*', **search_options).records).to include(milestone)
        expect(items_in_index(note_index)).to include(note.id)
        expect(items_in_index(merge_request_index)).to include(merge_request.id)
        expect(items_in_index(code_index).count).to be > 0
        expect(items_in_index(wiki_index).count).to be > 0
      end
    end
  end
end
