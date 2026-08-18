# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Elastic::SearchResults, 'query performance', feature_category: :global_search do
  let(:query) { 'hello world' }
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :public, :repository, :wiki_repo) }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  describe 'query performance' do
    let(:results) { described_class.new(user, query) }

    allowed_scopes = %w[projects notes blobs wiki_blobs issues commits merge_requests epics milestones notes users]
    scopes_with_notes_query = %w[issues merge_requests]

    include_examples 'calls Elasticsearch the expected number of times',
      scopes: (allowed_scopes - scopes_with_notes_query), scopes_with_multiple: scopes_with_notes_query

    allowed_scopes_and_index_names = [
      %W[projects #{Project.index_name}],
      %W[notes #{Note.index_name}],
      %W[blobs #{Repository.index_name}],
      %W[wiki_blobs #{Wiki.index_name}],
      %W[commits #{Elastic::Latest::CommitConfig.index_name}],
      %W[issues #{::Search::Elastic::References::WorkItem.index}],
      %W[merge_requests #{MergeRequest.index_name}],
      %W[epics #{::Search::Elastic::References::WorkItem.index}],
      %W[milestones #{Milestone.index_name}],
      %W[users #{User.index_name}]
    ]
    include_examples 'does not load results for count only queries', allowed_scopes_and_index_names
  end
end
