# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::MergeRequestQueryBuilder, :elastic_helpers, feature_category: :global_search do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:private_project) { create(:project, :private) }
  let_it_be(:authorized_project) { create(:project, developers: [user]) }
  let_it_be(:label) { create(:label, project: authorized_project) }

  let(:base_options) do
    {
      current_user: user,
      search_level: 'global',
      project_ids: project_ids,
      group_ids: [],
      public_and_internal_projects: true
    }
  end

  let(:query) { 'foo' }
  let(:project_ids) { [] }
  let(:options) { base_options }

  subject(:build) { described_class.build(query: query, options: options) }

  it 'contains all expected filters' do
    assert_names_in_query(build, with: %w[
      merge_request:multi_match:and:search_terms
      merge_request:multi_match_phrase:search_terms
      filters:not_hidden
      filters:non_archived
    ])
  end

  describe 'query' do
    context 'when query is an iid' do
      let(:query) { '!1' }

      it 'returns the expected query' do
        assert_names_in_query(build, with: %w[merge_request:related:iid doc:is_a:merge_request])
      end
    end

    context 'when query is text' do
      it 'returns the expected query' do
        assert_names_in_query(build,
          with: %w[
            merge_request:multi_match:and:search_terms
            merge_request:multi_match_phrase:search_terms
          ],
          without: %w[merge_request:match:search_terms])
      end

      context 'when advanced query syntax is used' do
        let(:query) { 'foo -default' }

        it 'returns the expected query' do
          assert_names_in_query(build, with: %w[merge_request:match:search_terms],
            without: %w[merge_request:multi_match:and:search_terms merge_request:multi_match_phrase:search_terms])
        end
      end
    end
  end

  describe 'fields' do
    it 'defaults to iid, title, and description' do
      assert_fields_in_query(build, with: %w[iid^3 title^2 description])
    end

    context 'when fields option is provided' do
      let(:options) { base_options.merge(fields: ['title']) }

      it 'uses the provided fields' do
        assert_fields_in_query(build, with: %w[title], without: %w[iid^3 title^2 description])
      end
    end
  end

  describe 'filters' do
    let(:project_ids) { [authorized_project.id, private_project.id] }

    it_behaves_like 'a query filtered by archived'
    it_behaves_like 'a query filtered by hidden'
    it_behaves_like 'a query filtered by state'
    it_behaves_like 'a query filtered by author'
    it_behaves_like 'a query filtered by labels'

    describe 'authorization' do
      it 'uses the new authorization filter' do
        assert_names_in_query(build,
          with: %w[filters:permissions:global:visibility_level:public_and_internal],
          without: %w[filters:project:membership:id])
      end

      context 'when current_user is nil' do
        let(:base_options) do
          {
            current_user: nil,
            search_level: 'global',
            project_ids: project_ids,
            group_ids: [],
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
            search_level: 'group',
            project_ids: [authorized_project.id],
            group_ids: [group.id],
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
            search_level: 'project',
            project_ids: [authorized_project.id],
            group_ids: [],
            public_and_internal_projects: false
          }
        end

        it 'applies project-level authorization filters' do
          assert_names_in_query(build, with: %w[filters:level:project])
        end
      end
    end

    describe 'source_branch' do
      it 'does not apply filters by default' do
        assert_names_in_query(build, without: %w[filters:source_branch filters:not_source_branch])
      end

      context 'when source_branch option is provided' do
        let(:options) { base_options.merge(source_branch: 'hello') }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:source_branch])
        end
      end

      context 'when not_source_branch option is provided' do
        let(:options) { base_options.merge(not_source_branch: 'world') }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:not_source_branch])
        end
      end
    end

    describe 'target_branch' do
      it 'does not apply filters by default' do
        assert_names_in_query(build, without: %w[filters:target_branch filters:not_target_branch])
      end

      context 'when target_branch option is provided' do
        let(:options) { base_options.merge(target_branch: 'hello') }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:target_branch])
        end
      end

      context 'when not_target_branch option is provided' do
        let(:options) { base_options.merge(not_target_branch: 'world') }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:not_target_branch])
        end
      end
    end
  end

  describe 'related ids' do
    let(:base_options) do
      {
        current_user: user,
        search_level: 'global',
        project_ids: [authorized_project.id],
        group_ids: [],
        public_and_internal_projects: true,
        related_ids: [42]
      }
    end

    context 'for global search' do
      context 'when on saas', :saas do
        it 'does not query by related ids' do
          assert_names_in_query(build, without: %w[merge_request:related:ids])
        end
      end

      context 'when not on saas' do
        it 'queries by related ids' do
          assert_names_in_query(build, with: %w[merge_request:related:ids])
        end
      end
    end

    context 'for group search' do
      let(:options) { base_options.merge(search_level: :group, group_ids: [group.id]) }

      it 'queries by related ids' do
        assert_names_in_query(build, with: %w[merge_request:related:ids])
      end
    end

    context 'for project search' do
      let(:options) { base_options.merge(search_level: :project) }

      it 'queries by related ids' do
        assert_names_in_query(build, with: %w[merge_request:related:ids])
      end
    end

    context 'when options[:related_ids] is not provided' do
      let(:base_options) do
        {
          current_user: user,
          search_level: 'global',
          project_ids: [authorized_project.id],
          group_ids: [],
          public_and_internal_projects: true
        }
      end

      it 'does not query by related ids' do
        assert_names_in_query(build, without: %w[merge_request:related:ids])
      end
    end
  end

  describe 'aggregations' do
    let(:options) { base_options.merge(aggregation: true) }

    it 'includes the labels aggregation' do
      expect(build[:aggs]).to have_key('labels')
    end

    it 'sets size to 0' do
      expect(build[:size]).to eq(0)
    end

    it 'does not apply sort or source_fields when aggregating' do
      expect(build).not_to have_key(:sort)
      expect(build).not_to have_key(:_source)
    end
  end

  it_behaves_like 'a sorted query'

  describe 'formats' do
    it_behaves_like 'a query that sets source_fields'
    it_behaves_like 'a query formatted for size'
  end
end
