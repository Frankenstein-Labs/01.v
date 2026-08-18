# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Elastic::SearchResults, 'visibility_levels', feature_category: :global_search do
  let(:query) { 'hello world' }
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :public, :repository, :wiki_repo) }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  describe 'visibility levels', :elastic_delete_by_query, :sidekiq_inline do
    let_it_be_with_reload(:internal_project) do
      create(:project, :internal, :repository, :wiki_repo, description: "Internal project")
    end

    let_it_be_with_reload(:private_project1) do
      create(:project, :private, :repository, :wiki_repo, description: "Private project")
    end

    let_it_be_with_reload(:private_project2) do
      create(:project, :private, :repository, :wiki_repo, developers: user,
        description: "Private project where I'm a member")
    end

    let_it_be_with_reload(:public_project) do
      create(:project, :public, :repository, :wiki_repo, description: "Public project")
    end

    before do
      Elastic::ProcessInitialBookkeepingService.backfill_projects!(internal_project,
        private_project1, private_project2, public_project)

      ensure_elasticsearch_index!
    end

    describe 'issues' do
      shared_examples 'issues respect visibility' do
        it 'finds right set of issues' do
          issue_1 = create :issue, project: internal_project, title: "Internal project"
          create :issue, project: private_project1, title: "Private project"
          issue_3 = create :issue, project: private_project2, title: "Private project where I'm a member"
          issue_4 = create :issue, project: public_project, title: "Public project"

          ensure_elasticsearch_index!

          # Authenticated search
          results = described_class.new(user, 'project')
          issues = results.objects('issues')

          expect(issues).to include issue_1
          expect(issues).to include issue_3
          expect(issues).to include issue_4
          expect(results.issues_count).to eq 3

          # Unauthenticated search
          results = described_class.new(nil, 'project')
          issues = results.objects('issues')

          expect(issues).to include issue_4
          expect(results.issues_count).to eq 1
        end

        context 'when different issue descriptions', :aggregate_failures do
          let(:examples) do
            code_examples.merge(
              'screen' => 'Screenshots or screen recordings',
              'problem' => 'Problem to solve'
            )
          end

          include_context 'with code examples' do
            before do
              examples.values.uniq.each do |description|
                sha = Digest::SHA256.hexdigest(description)
                create :issue, project: private_project2, title: sha, description: description
              end

              ensure_elasticsearch_index!
            end

            it 'finds all examples' do
              examples.each do |search_term, description|
                sha = Digest::SHA256.hexdigest(description)

                results = described_class.new(user, search_term)
                issues = results.objects('issues')
                expect(issues.map(&:title)).to include(sha), "failed to find #{search_term}"
              end
            end
          end
        end
      end

      it_behaves_like 'issues respect visibility'
    end

    describe 'milestones' do
      let_it_be_with_reload(:milestone_1) { create(:milestone, project: internal_project, title: "Internal project") }
      let_it_be_with_reload(:milestone_2) { create(:milestone, project: private_project1, title: "Private project") }
      let_it_be_with_reload(:milestone_3) do
        create(:milestone, project: private_project2, title: "Private project which user is member")
      end

      let_it_be_with_reload(:milestone_4) { create(:milestone, project: public_project, title: "Public project") }

      before do
        Elastic::ProcessInitialBookkeepingService.track!(milestone_1, milestone_2, milestone_3, milestone_4)
        ensure_elasticsearch_index!
      end

      it_behaves_like 'a paginated object', 'milestones'
    end

    describe 'projects' do
      it_behaves_like 'a paginated object', 'projects'

      it 'finds right set of projects' do
        internal_project
        private_project1
        private_project2
        public_project

        ensure_elasticsearch_index!

        # Authenticated search
        results = described_class.new(user, 'project')
        milestones = results.objects('projects')

        expect(milestones).to include internal_project
        expect(milestones).to include private_project2
        expect(milestones).to include public_project
        expect(results.projects_count).to eq 3

        # Unauthenticated search
        results = described_class.new(nil, 'project')
        projects = results.objects('projects')

        expect(projects).to include public_project
        expect(results.projects_count).to eq 1
      end

      it 'returns 0 results for count only query' do
        public_project

        ensure_elasticsearch_index!

        results = described_class.new(user, '"noresults"')
        count = results.formatted_count('projects')
        expect(count).to eq('0')
      end
    end

    describe 'merge requests' do
      it 'finds right set of merge requests' do
        merge_request_1 = create :merge_request, target_project: internal_project, source_project: internal_project,
          title: "Internal project"
        create :merge_request, target_project: private_project1, source_project: private_project1,
          title: "Private project"
        merge_request_3 = create :merge_request, target_project: private_project2, source_project: private_project2,
          title: "Private project where I'm a member"
        merge_request_4 = create :merge_request, target_project: public_project, source_project: public_project,
          title: "Public project"

        ensure_elasticsearch_index!

        # Authenticated search
        results = described_class.new(user, 'project')
        merge_requests = results.objects('merge_requests')

        expect(merge_requests).to include merge_request_1
        expect(merge_requests).to include merge_request_3
        expect(merge_requests).to include merge_request_4
        expect(results.merge_requests_count).to eq 3

        # Unauthenticated search
        results = described_class.new(nil, 'project')
        merge_requests = results.objects('merge_requests')

        expect(merge_requests).to include merge_request_4
        expect(results.merge_requests_count).to eq 1
      end
    end

    describe 'wikis', :sidekiq_inline do
      before do
        [public_project, internal_project, private_project1, private_project2].each do |project|
          project.wiki.create_page('index_page', 'term')
          project.wiki.index_wiki_blobs
        end

        ensure_elasticsearch_index!
      end

      it 'finds the right set of wiki blobs' do
        # Authenticated search
        results = described_class.new(user, 'term')
        blobs = results.objects('wiki_blobs')

        expect(blobs.map(&:project)).to match_array [internal_project, private_project2, public_project]
        expect(results.wiki_blobs_count).to eq 3

        # Unauthenticated search
        results = described_class.new(nil, 'term')
        blobs = results.objects('wiki_blobs')

        expect(blobs.first.project).to eq public_project
        expect(results.wiki_blobs_count).to eq 1
      end
    end

    describe 'commits', :sidekiq_inline do
      it 'finds right set of commits' do
        [internal_project, private_project1, private_project2, public_project].each do |project|
          project.repository.create_file(
            user,
            'test-file-commits',
            'commits test',
            message: 'commits test',
            branch_name: 'master'
          )

          project.repository.index_commits_and_blobs
        end

        ensure_elasticsearch_index!

        # Authenticated search
        results = described_class.new(user, 'commits test')
        commits = results.objects('commits')

        expect(commits.map(&:project)).to match_array [internal_project, private_project2, public_project]
        expect(results.commits_count).to eq 3

        # Unauthenticated search
        results = described_class.new(nil, 'commits test')
        commits = results.objects('commits')

        expect(commits.first.project).to eq public_project
        expect(results.commits_count).to eq 1
      end
    end

    describe 'blobs', :sidekiq_inline do
      it 'finds right set of blobs' do
        [internal_project, private_project1, private_project2, public_project].each do |project|
          project.repository.create_file(
            user,
            'test-file-blobs',
            'blobs test',
            message: 'blobs test',
            branch_name: 'master'
          )

          project.repository.index_commits_and_blobs
        end

        ensure_elasticsearch_index!

        # Authenticated search
        results = described_class.new(user, 'blobs test')
        blobs = results.objects('blobs')

        expect(blobs.map(&:project)).to match_array [internal_project, private_project2, public_project]
        expect(results.blobs_count).to eq 3

        # Unauthenticated search
        results = described_class.new(nil, 'blobs test')
        blobs = results.objects('blobs')

        expect(blobs.first.project).to eq public_project
        expect(results.blobs_count).to eq 1
      end
    end
  end
end
