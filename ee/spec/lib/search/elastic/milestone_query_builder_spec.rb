# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::MilestoneQueryBuilder, :elastic_helpers, feature_category: :global_search do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:private_project) { create(:project, :private) }
  let_it_be(:authorized_project) { create(:project, developers: [user]) }

  let(:base_options) do
    {
      current_user: user,
      project_ids: project_ids,
      group_ids: [],
      search_level: 'global',
      public_and_internal_projects: true
    }
  end

  let(:query) { 'foo' }
  let(:project_ids) { [] }
  let(:options) { base_options }

  subject(:build) { described_class.build(query: query, options: options) }

  it 'contains all expected filters' do
    assert_names_in_query(build, with: %w[
      milestone:multi_match:and:search_terms
      milestone:multi_match_phrase:search_terms
      filters:doc:is_a:milestone
      filters:permissions:global:visibility_level:public_and_internal
      filters:non_archived
    ])
  end

  context 'when advanced query syntax is used' do
    let(:query) { 'foo -default' }

    it 'uses simple_query_string in query' do
      assert_names_in_query(build, with: %w[milestone:match:search_terms],
        without: %w[milestone:multi_match:and:search_terms milestone:multi_match_phrase:search_terms])
    end
  end

  describe 'fields' do
    it 'defaults to title and description' do
      assert_fields_in_query(build, with: %w[title^2 description])
    end

    context 'when fields option is provided' do
      let(:options) { base_options.merge(fields: ['title']) }

      it 'uses the provided fields' do
        assert_fields_in_query(build, with: %w[title], without: %w[title^2 description])
      end
    end
  end

  describe 'filters' do
    let(:project_ids) { [authorized_project.id, private_project.id] }

    it_behaves_like 'a query filtered by archived'

    describe 'authorization' do
      it 'uses the new authorization filter' do
        assert_names_in_query(build,
          with: %w[filters:permissions:global:visibility_level:public_and_internal],
          without: %w[filters:project])
      end

      context 'when current_user is nil' do
        let(:base_options) do
          {
            current_user: nil,
            project_ids: project_ids,
            group_ids: [],
            search_level: 'global',
            public_and_internal_projects: true
          }
        end

        it 'restricts the authorization filter to public projects only' do
          assert_names_in_query(build,
            with: %w[filters:permissions:global:visibility_level:public],
            without: %w[filters:permissions:global:visibility_level:public_and_internal])
        end
      end

      context 'when search_level is group' do
        let(:base_options) do
          {
            current_user: user,
            project_ids: [authorized_project.id],
            group_ids: [group.id],
            search_level: 'group',
            public_and_internal_projects: true
          }
        end

        it 'applies group-level authorization filters' do
          assert_names_in_query(build, with: %w[filters:level:group])
        end
      end

      context 'when search_level is project' do
        let(:base_options) do
          {
            current_user: user,
            project_ids: [authorized_project.id],
            group_ids: [],
            search_level: 'project',
            public_and_internal_projects: false
          }
        end

        it 'applies project-level authorization filters' do
          assert_names_in_query(build, with: %w[filters:level:project])
        end
      end
    end
  end

  describe 'formats' do
    it_behaves_like 'a query that sets source_fields'
    it_behaves_like 'a query formatted for size'
  end
end
