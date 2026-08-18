# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Elastic::SearchResults, 'merge_requests', feature_category: :global_search do
  let(:query) { 'hello world' }
  let_it_be(:user) { create(:user) }
  let_it_be(:project_1) { create(:project, :public, :repository, :wiki_repo) }
  let_it_be(:project_2) { create(:project, :private, :repository, :wiki_repo) }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  describe 'merge requests', :elastic_delete_by_query do
    let(:scope) { 'merge_requests' }
    let_it_be(:merge_request_1) do
      create(:merge_request, source_project: project_1, target_project: project_1,
        title: 'Hello world, here I am!', description: '20200623170000, see details in issue 287661', iid: 1)
    end

    let_it_be(:merge_request_2) do
      create(:merge_request, :conflict, source_project: project_1, target_project: project_1,
        title: 'Merge Request Two', description: 'Hello world, here I am!', iid: 2)
    end

    let_it_be(:merge_request_3) do
      create(:merge_request, source_project: project_2, target_project: project_2,
        title: 'Merge Request Three', iid: 2)
    end

    before do
      ::Elastic::ProcessInitialBookkeepingService.backfill_projects!(project_1, project_2)
      ensure_elasticsearch_index!
    end

    it_behaves_like 'a paginated object', 'merge_requests'

    it 'lists found merge requests' do
      results = described_class.new(user, query, public_and_internal_projects: false)
      merge_requests = results.objects('merge_requests')

      expect(merge_requests).to contain_exactly(merge_request_1, merge_request_2)
      expect(results.merge_requests_count).to eq 2
    end

    it_behaves_like 'can search by title for miscellaneous cases', 'merge_requests'

    context 'when description has code snippets' do
      include_context 'with code examples' do
        before do
          code_examples.values.uniq.each.with_index do |code, idx|
            sha = Digest::SHA256.hexdigest(code)
            create :merge_request, target_branch: "feature#{idx}", source_project: project_1, target_project: project_1,
              title: sha, description: code
          end

          ensure_elasticsearch_index!
        end

        it 'finds all examples' do
          code_examples.each do |query, description|
            sha = Digest::SHA256.hexdigest(description)
            merge_requests = described_class.new(user, query).objects('merge_requests')
            expect(merge_requests.map(&:title)).to include(sha)
          end
        end
      end
    end

    it 'returns empty list when merge requests are not found' do
      results = described_class.new(user, 'security')

      expect(results.objects('merge_requests')).to be_empty
      expect(results.merge_requests_count).to eq 0
    end

    it 'lists merge request when search by a valid iid' do
      results = described_class.new(user, '!2', public_and_internal_projects: false)
      merge_requests = results.objects('merge_requests')

      expect(merge_requests).to contain_exactly(merge_request_2)
      expect(results.merge_requests_count).to eq 1
    end

    it 'can also find an issue by iid without the prefixed !' do
      results = described_class.new(user, '2', public_and_internal_projects: false)
      merge_requests = results.objects('merge_requests')

      expect(merge_requests).to contain_exactly(merge_request_2)
      expect(results.merge_requests_count).to eq 1
    end

    it 'finds the MR with an out of integer range number in its description without exception' do
      results = described_class.new(user, '20200623170000', public_and_internal_projects: false)
      merge_requests = results.objects('merge_requests')

      expect(merge_requests).to contain_exactly(merge_request_1)
      expect(results.merge_requests_count).to eq 1
    end

    it 'returns empty list when search by invalid iid' do
      results = described_class.new(user, '#222')

      expect(results.objects('merge_requests')).to be_empty
      expect(results.merge_requests_count).to eq 0
    end

    describe 'merge requests with notes', :elastic_delete_by_query do
      let(:query) { 'Goodbye moon' }
      let_it_be(:merge_request) do
        create(:merge_request, source_project: project_1, source_branch: 'open-1', title: 'Hello world, here I am!')
      end

      let_it_be(:note) do
        create(:note_on_merge_request, note: 'Goodbye moon', noteable: merge_request, project: merge_request.project)
      end

      let(:results) { described_class.new(user, query, public_and_internal_projects: true) }

      before do
        Elastic::ProcessInitialBookkeepingService.track!(merge_request, note)
        ensure_elasticsearch_index!
      end

      subject(:merge_requests) { results.objects('merge_requests') }

      it 'returns the merge request when searching with note text' do
        expect(merge_requests).to contain_exactly(merge_request)
        expect(results.merge_requests_count).to eq 1
      end
    end

    describe 'filtering' do
      let_it_be(:unarchived_project) { create(:project, :public) }
      let_it_be(:archived_project) { create(:project, :public, :archived) }
      let_it_be(:opened_result) do
        create(:merge_request, :opened, source_project: project_1, source_branch: 'open-1', title: 'foo opened')
      end

      let_it_be(:closed_result) do
        create(:merge_request, :closed, source_project: project_1, source_branch: 'closed-1', title: 'foo closed')
      end

      let_it_be(:unarchived_result) do
        create(:merge_request, source_project: unarchived_project, source_branch: 'unarchived-1',
          title: 'foo unarchived')
      end

      let_it_be(:archived_result) do
        create(:merge_request, source_project: archived_project, source_branch: 'archived-1', title: 'foo archived')
      end

      let(:scope) { 'merge_requests' }
      let(:project_ids) { [project_1.id, unarchived_project.id, archived_project.id] }
      let(:results) { described_class.new(user, 'foo', filters: filters) }

      before do
        Elastic::ProcessInitialBookkeepingService.backfill_projects!(unarchived_project, archived_project)

        ensure_elasticsearch_index!
      end

      include_examples 'search results filtered by state'
      include_examples 'search results filtered by archived'
    end

    describe 'ordering' do
      let_it_be(:old_result) do
        create(:merge_request, :opened, source_project: project_1, source_branch: 'old-1', title: 'sorted old',
          created_at: 1.month.ago)
      end

      let_it_be(:new_result) do
        create(:merge_request, :opened, source_project: project_1, source_branch: 'new-1', title: 'sorted recent',
          created_at: 1.day.ago)
      end

      let_it_be(:very_old_result) do
        create(:merge_request, :opened, source_project: project_1, source_branch: 'very-old-1',
          title: 'sorted very old', created_at: 1.year.ago)
      end

      let_it_be(:old_updated) do
        create(:merge_request, :opened, source_project: project_1, source_branch: 'updated-old-1', title: 'updated old',
          updated_at: 1.month.ago)
      end

      let_it_be(:new_updated) do
        create(:merge_request, :opened, source_project: project_1, source_branch: 'updated-new-1',
          title: 'updated recent', updated_at: 1.day.ago)
      end

      let_it_be(:very_old_updated) do
        create(:merge_request, :opened, source_project: project_1, source_branch: 'updated-very-old-1',
          title: 'updated very old', updated_at: 1.year.ago)
      end

      before do
        Elastic::ProcessInitialBookkeepingService.backfill_projects!(project_1)

        ensure_elasticsearch_index!
      end

      include_examples 'search results sorted' do
        let(:results_created) { described_class.new(user, 'sorted', sort: sort) }
        let(:results_updated) { described_class.new(user, 'updated', sort: sort) }
      end
    end
  end
end
