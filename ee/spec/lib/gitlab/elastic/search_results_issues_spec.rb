# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Elastic::SearchResults, 'issues', feature_category: :global_search do
  let(:query) { 'hello world' }
  let(:scope) { 'issues' }
  let_it_be(:user) { create(:user) }
  let_it_be(:project_1) { create(:project, :public, :repository, :wiki_repo, :in_group) }
  let_it_be(:project_2) { create(:project, :public, :repository, :wiki_repo) }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  describe 'issues', :elastic_delete_by_query do
    let_it_be(:issue_1) do
      create(:issue, project: project_1, title: 'Hello world, here I am!',
        description: '20200623170000, see details in issue 287661', iid: 1)
    end

    let_it_be(:issue_2) do
      create(:issue, project: project_1, title: 'Issue Two', description: 'Hello world, here I am!', iid: 2)
    end

    let_it_be(:issue_3) { create(:issue, project: project_2, title: 'Issue Three', iid: 2) }

    before do
      Elastic::ProcessInitialBookkeepingService.backfill_projects!(project_1, project_2)
      ensure_elasticsearch_index!
    end

    it_behaves_like 'a paginated object', 'issues'

    it 'lists found issues' do
      results = described_class.new(user, query)
      issues = results.objects(scope)

      expect(issues).to contain_exactly(issue_1, issue_2)
      expect(results.issues_count).to eq 2
    end

    it 'returns empty list when issues are not found' do
      results = described_class.new(user, 'security')

      expect(results.objects(scope)).to be_empty
      expect(results.issues_count).to eq 0
    end

    it 'lists issue when search by a valid iid' do
      results = described_class.new(user, '#2')
      issues = results.objects(scope)

      expect(issues).to contain_exactly(issue_2, issue_3)
      expect(results.issues_count).to eq 2
    end

    it 'can also find an issue by iid without the prefixed #' do
      results = described_class.new(user, '2')
      issues = results.objects(scope)

      expect(issues).to contain_exactly(issue_3, issue_2)
      expect(results.issues_count).to eq 2
    end

    it 'finds the issue with an out of integer range number in its description without exception' do
      results = described_class.new(user, '20200623170000')
      issues = results.objects(scope)

      expect(issues).to contain_exactly(issue_1)
      expect(results.issues_count).to eq 1
    end

    it 'returns empty list when search by invalid iid' do
      results = described_class.new(user, '#222')

      expect(results.objects(scope)).to be_empty
      expect(results.issues_count).to eq 0
    end

    it_behaves_like 'can search by title for miscellaneous cases', 'issues'

    it 'executes count only queries' do
      results = described_class.new(user, query)
      expect(results).to receive(:issues).with(count_only: true, scope: 'issues').and_call_original

      count = results.issues_count

      expect(count).to eq(2)
    end

    describe 'filtering' do
      let_it_be(:project) { create(:project, :public, developers: [user]) }
      let_it_be(:closed_result) { create(:issue, :closed, project: project, title: 'foo closed') }
      let_it_be(:opened_result) { create(:issue, :opened, project: project, title: 'foo opened') }
      let_it_be(:confidential_result) { create(:issue, :confidential, project: project, title: 'foo confidential') }

      let(:results) { described_class.new(user, 'foo', filters: filters) }

      before do
        ::Elastic::ProcessInitialBookkeepingService.backfill_projects!(project)
        ensure_elasticsearch_index!
      end

      include_examples 'search results filtered by state'
      include_examples 'search results filtered by confidential'
      include_examples 'search results filtered by labels'

      context 'for work_item_type filter' do
        using RSpec::Parameterized::TableSyntax
        let_it_be(:requirement) { create(:issue, :requirement, project: project) }
        let_it_be(:task) { create(:issue, :task, project: project) }
        let_it_be(:incident) { create(:issue, :incident, project: project) }
        let_it_be(:issue) { create(:issue, project: project) }

        before do
          ::Elastic::ProcessBookkeepingService.track!(requirement, task, incident, issue)
          ensure_elasticsearch_index!
        end

        where(:type, :expected) do
          'requirement'  | [ref(:requirement)]
          'task'         | [ref(:task)]
          'incident'     | [ref(:incident)]
          'issue'        | [ref(:issue)]
          'invalid_type' | [ref(:issue), ref(:incident), ref(:requirement), ref(:task)]
        end

        with_them do
          it 'returns the expected issue based on type' do
            issues = described_class.new(user, '*', filters: { type: type }).objects(scope)
            expect(issues).to include(*expected)
          end
        end
      end
    end

    describe 'ordering' do
      let_it_be(:project) { create(:project, :public) }

      let_it_be(:old_result) do
        create(:work_item, project: project, title: 'sorted old', created_at: 1.month.ago)
      end

      let_it_be(:new_result) do
        create(:work_item, project: project, title: 'sorted recent', created_at: 1.day.ago)
      end

      let_it_be(:very_old_result) do
        create(:work_item, project: project, title: 'sorted very old', created_at: 1.year.ago)
      end

      let_it_be(:old_updated) do
        create(:work_item, project: project, title: 'updated old', updated_at: 1.month.ago)
      end

      let_it_be(:new_updated) do
        create(:work_item, project: project, title: 'updated recent', updated_at: 1.day.ago)
      end

      let_it_be(:very_old_updated) do
        create(:work_item, project: project, title: 'updated very old', updated_at: 1.year.ago)
      end

      let_it_be(:less_popular_result) do
        create(:work_item, project: project, title: 'less popular', upvotes_count: 10)
      end

      let_it_be(:non_popular_result) do
        create(:work_item, project: project, title: 'non popular', upvotes_count: 1)
      end

      let_it_be(:popular_result) do
        create(:work_item, project: project, title: 'popular', upvotes_count: 100)
      end

      before do
        ::Elastic::ProcessInitialBookkeepingService.backfill_projects!(project)
        ensure_elasticsearch_index!
      end

      include_examples 'search results sorted' do
        let(:results_created) { described_class.new(user, 'sorted', sort: sort) }
        let(:results_updated) { described_class.new(user, 'updated', sort: sort) }
      end

      include_examples 'search results sorted by popularity' do
        let(:results_popular) { described_class.new(user, 'popular', sort: sort) }
      end
    end
  end

  describe 'confidential issues', :elastic_delete_by_query, :sidekiq_inline do
    let_it_be(:project_3) { create(:project, :public) }
    let_it_be(:project_4) { create(:project, :public) }
    let_it_be_with_reload(:author) { create(:user) }
    let_it_be_with_reload(:assignee) { create(:user) }
    let_it_be(:non_member) { create(:user) }
    let_it_be(:member) { create(:user) }
    let_it_be(:admin) { create(:admin) }
    let_it_be(:issue) { create(:issue, project: project_1, title: 'Issue 1', iid: 1) }
    let_it_be(:security_issue_1) do
      create(:issue, :confidential, project: project_1, title: 'Security issue 1', author: author, iid: 2)
    end

    let_it_be(:security_issue_2) do
      create(:issue, :confidential, title: 'Security issue 2', project: project_1, assignees: [assignee], iid: 3)
    end

    let_it_be(:security_issue_3) do
      create(:issue, :confidential, project: project_2, title: 'Security issue 3', author: author, iid: 1)
    end

    let_it_be(:security_issue_4) do
      create(:issue, :confidential, project: project_3,
        title: 'Security issue 4', assignees: [assignee], iid: 1)
    end

    let_it_be(:security_issue_5) do
      create(:issue, :confidential, project: project_4, title: 'Security issue 5', iid: 1)
    end

    before do
      ::Elastic::ProcessInitialBookkeepingService.backfill_projects!(project_1, project_2, project_3, project_4)
      ensure_elasticsearch_index!
    end

    context 'when searching by term' do
      let(:query) { 'issue' }

      it 'does not list confidential issues for anonymous users' do
        results = described_class.new(nil, query)
        issues = results.objects(scope)

        expect(issues).to contain_exactly(issue)
        expect(results.issues_count).to eq 1
      end

      it 'does not list confidential issues for guest users' do
        project_1.add_guest(member)
        results = described_class.new(member, query)
        issues = results.objects(scope)

        expect(issues).to contain_exactly(issue)
        expect(results.issues_count).to eq 1
      end

      it 'does not list confidential issues for non project members' do
        results = described_class.new(non_member, query)
        issues = results.objects(scope)

        expect(issues).to contain_exactly(issue)
        expect(results.issues_count).to eq 1
      end

      it 'lists confidential issues for author' do
        results = described_class.new(author, query)
        issues = results.objects(scope)

        expect(issues).to contain_exactly(issue, security_issue_1, security_issue_3)
        expect(results.issues_count).to eq 3
      end

      it 'lists confidential issues for assignee' do
        results = described_class.new(assignee, query)
        issues = results.objects(scope)

        expect(issues).to contain_exactly(issue, security_issue_2, security_issue_4)
        expect(results.issues_count).to eq 3
      end

      it 'lists confidential issues for project members with developer+ role' do
        project_1.add_developer(member)
        project_2.add_developer(member)

        results = described_class.new(member, query)
        issues = results.objects(scope)

        expect(issues).to contain_exactly(issue, security_issue_1, security_issue_2, security_issue_3)
        expect(results.issues_count).to eq 4
      end

      context 'for admin users' do
        context 'when admin mode enabled', :enable_admin_mode do
          it 'lists all issues' do
            results = described_class.new(admin, query)
            issues = results.objects(scope)

            expect(issues).to contain_exactly(issue, security_issue_1,
              security_issue_2, security_issue_3, security_issue_4, security_issue_5)
            expect(results.issues_count).to eq 6
          end
        end

        context 'when admin mode disabled' do
          it 'does not list confidential issues' do
            results = described_class.new(admin, query)
            issues = results.objects(scope)

            expect(issues).to contain_exactly(issue)
            expect(results.issues_count).to eq 1
          end
        end
      end

      context 'for user who is the member of only project which does not have any confidential issues' do
        let_it_be(:other_project) { create(:project) }
        let_it_be(:other_project_member_user) { create(:user) }

        it 'does not list any confidential issues' do
          other_project.add_developer(other_project_member_user)
          results = described_class.new(other_project_member_user, query)
          issues = results.objects(scope)

          expect(issues).to contain_exactly(issue)
        end
      end
    end

    context 'when searching by iid' do
      let(:query) { '#1' }

      it 'does not list confidential issues for anonymous users' do
        results = described_class.new(nil, query)
        issues = results.objects(scope)

        expect(issues).to contain_exactly(issue)
        expect(results.issues_count).to eq 1
      end

      it 'does not list confidential issues for guests' do
        project_1.add_guest(member)
        results = described_class.new(nil, query)
        issues = results.objects(scope)

        expect(issues).to contain_exactly(issue)
        expect(results.issues_count).to eq 1
      end

      it 'does not list confidential issues for non project members' do
        results = described_class.new(non_member, query)
        issues = results.objects(scope)

        expect(issues).to contain_exactly(issue)
        expect(results.issues_count).to eq 1
      end

      it 'lists confidential issues for author' do
        results = described_class.new(author, query)
        issues = results.objects(scope)

        expect(issues).to contain_exactly(issue, security_issue_3)
        expect(results.issues_count).to eq 2
      end

      it 'lists confidential issues for assignee' do
        results = described_class.new(assignee, query)
        issues = results.objects(scope)

        expect(issues).to contain_exactly(issue, security_issue_4)
        expect(results.issues_count).to eq 2
      end

      it 'lists confidential issues for project members with developer+ role' do
        project_2.add_developer(member)
        project_3.add_developer(member)

        results = described_class.new(member, query)
        issues = results.objects(scope)

        expect(issues).to contain_exactly(issue, security_issue_3, security_issue_4)
        expect(results.issues_count).to eq 3
      end

      context 'for admin users' do
        context 'when admin mode enabled', :enable_admin_mode do
          it 'lists all issues' do
            results = described_class.new(admin, query)
            issues = results.objects(scope)

            expect(issues).to contain_exactly(issue, security_issue_3, security_issue_4, security_issue_5)
            expect(results.issues_count).to eq 4
          end
        end

        context 'when admin mode disabled' do
          it 'does not list confidential issues' do
            results = described_class.new(admin, query)
            issues = results.objects(scope)

            expect(issues).to contain_exactly(issue)
            expect(results.issues_count).to eq 1
          end
        end
      end
    end
  end

  describe 'issues with notes', :elastic_delete_by_query do
    let(:query) { 'Goodbye moon' }
    let_it_be(:issue) { create(:issue, project: project_1, title: 'Hello world, here I am!') }
    let_it_be(:note) { create(:note_on_issue, note: 'Goodbye moon', noteable: issue, project: issue.project) }

    let(:results) do
      described_class.new(user, query, public_and_internal_projects: true)
    end

    before do
      Elastic::ProcessInitialBookkeepingService.track!(issue, note)
      ensure_elasticsearch_index!
    end

    subject(:issues) { results.objects(scope) }

    it 'returns the issue when searching with note text' do
      expect(issues).to contain_exactly(issue)
      expect(results.issues_count).to eq 1
    end

    context 'when on saas', :saas do
      it 'does not return the issue when searching with note text' do
        expect(issues).to be_empty
        expect(results.issues_count).to eq 0
      end
    end
  end
end
