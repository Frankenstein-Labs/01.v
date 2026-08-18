# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Elastic::SearchResults, 'commits', feature_category: :global_search do
  let(:query) { 'hello world' }
  let_it_be(:user) { create(:user) }
  let_it_be(:project_1) { create(:project, :public, :repository, :wiki_repo) }
  let_it_be(:project_2) { create(:project, :public, :repository, :wiki_repo) }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  describe 'commits', :elastic_delete_by_query, :sidekiq_inline do
    before do
      project_1.repository.index_commits_and_blobs
      ensure_elasticsearch_index!
    end

    it_behaves_like 'a paginated object', 'commits'

    it 'finds commits' do
      results = described_class.new(user, 'add')
      commits = results.objects('commits')

      expect(commits.first.message.downcase).to include("add")
      expect(results.commits_count).to eq 21
    end

    context 'with a private project' do
      let_it_be(:private_project) { create(:project, :private, :repository) }

      before do
        private_project.repository.index_commits_and_blobs
        ensure_elasticsearch_index!
      end

      it 'does not return commits from private projects the user is not a member of' do
        results = described_class.new(user, 'add')
        expect(results.commits_count).to eq 21
      end

      it 'returns commits from private projects the user is a member of' do
        private_project.add_reporter(user)

        results = described_class.new(user, 'add')
        expect(results.commits_count).to eq 42
      end
    end

    it 'returns zero when commits are not found' do
      results = described_class.new(user, 'asdfg')

      expect(results.commits_count).to eq 0
    end
  end
end
