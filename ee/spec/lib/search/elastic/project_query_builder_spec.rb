# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::ProjectQueryBuilder, :elastic_helpers, feature_category: :global_search do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, developers: [user]) }

  let(:base_options) do
    {
      current_user: user,
      project_ids: [],
      group_ids: [],
      search_level: 'global'
    }
  end

  let(:query) { 'foo' }
  let(:options) { base_options }

  subject(:build) { described_class.build(query: query, options: options) }

  it 'contains all expected filters' do
    assert_names_in_query(build,
      with: %w[project:multi_match_phrase:search_terms
        project:multi_match:and:search_terms
        filters:doc:is_a:project
        filters:non_archived],
      without: %w[project:match:search_terms])
  end

  context 'when advanced search syntax is used' do
    let(:query) { '*' }

    it 'uses simple_query_string in query' do
      assert_names_in_query(build,
        with: %w[project:match:search_terms
          filters:doc:is_a:project
          filters:non_archived],
        without: %w[project:multi_match_phrase:search_terms
          project:multi_match:and:search_terms])
    end
  end

  describe 'fields' do
    def multi_match_fields(result)
      bool_query = result.dig(:query, :function_score, :query) || result[:query]
      bool_query.dig(:bool, :must, 0, :bool, :should, 0, :multi_match, :fields)
    end

    it 'defaults to the project field list' do
      expect(multi_match_fields(build)).to include('name^10', 'name_with_namespace^2',
        'path_with_namespace', 'path^9', 'description')
    end

    context 'when fields option is provided' do
      let(:options) { base_options.merge(fields: ['name']) }

      it 'uses the provided fields' do
        fields = multi_match_fields(build)
        expect(fields).to include('name')
        expect(fields).not_to include('name^10', 'description')
      end
    end
  end

  describe 'filters' do
    it_behaves_like 'a query filtered by archived'

    describe 'authorization' do
      using RSpec::Parameterized::TableSyntax

      # rubocop:disable Layout/LineLength -- keep the table intact
      where(:search_level, :projects, :groups, :admin_mode_enabled, :expected_filter) do
        'global'  | :any              | []              | false | %w[filters:permissions:global:visibility_level:public_and_internal]
        'global'  | :any              | []              | true  | %w[]
        'global'  | []                | []              | false | %w[filters:permissions:global:visibility_level:public_and_internal]
        'group'   | :any              | [ref(:group)]   | false | %w[filters:level:group filters:permissions:group:visibility_level:public_and_internal]
        'group'   | :any              | [ref(:group)]   | true  | %w[filters:level:group]
        'group'   | []                | [ref(:group)]   | false | %w[filters:level:group filters:permissions:group:visibility_level:public_and_internal]
        'project' | [ref(:project)]   | []              | false | %w[filters:level:project]
      end
      # rubocop:enable Layout/LineLength

      with_them do
        let(:project_ids) { projects.eql?(:any) ? projects : projects.map(&:id) }
        let(:group_ids) { groups.map(&:id) }

        let(:base_options) do
          {
            current_user: user,
            project_ids: project_ids,
            group_ids: group_ids,
            search_level: search_level
          }
        end

        it 'applies authorization filters' do
          allow(user).to receive(:can_read_all_resources?).and_return(admin_mode_enabled)

          assert_names_in_query(build, with: expected_filter)
        end
      end

      context 'when current_user is nil' do
        let(:base_options) do
          {
            current_user: nil,
            project_ids: [],
            group_ids: [],
            search_level: 'global'
          }
        end

        it 'restricts the authorization filter to public projects only' do
          assert_names_in_query(build,
            with: %w[filters:permissions:global:visibility_level:public],
            without: %w[filters:permissions:global:visibility_level:public_and_internal])
        end
      end
    end
  end

  describe 'autocomplete' do
    let(:options) do
      {
        current_user: user,
        project_ids: [],
        group_ids: [],
        search_level: 'global',
        autocomplete: true
      }
    end

    let(:query) { 'foo' }

    subject(:build) { described_class.build(query: query, options: options) }

    it 'does not include the public and internal visibility filter' do
      assert_names_in_query(build,
        without: %w[filters:permissions:global:visibility_level:public_and_internal
          filters:permissions:global:visibility_level:public])
    end

    it 'still includes the base doc type and archived filters' do
      assert_names_in_query(build,
        with: %w[filters:doc:is_a:project filters:non_archived])
    end

    context 'when current_user is nil' do
      let(:options) do
        {
          current_user: nil,
          project_ids: [],
          group_ids: [],
          search_level: 'global',
          autocomplete: true
        }
      end

      it 'does not apply membership filter' do
        assert_names_in_query(build,
          without: %w[filters:permissions:membership_and_membership_locked])
      end
    end

    context 'when current_user is an admin with admin mode enabled' do
      let(:admin) { create(:admin) }
      let(:options) do
        {
          current_user: admin,
          project_ids: [],
          group_ids: [],
          search_level: 'global',
          autocomplete: true
        }
      end

      before do
        allow(admin).to receive(:can_read_all_resources?).and_return(true)
      end

      it 'does not include the public and internal visibility filter' do
        assert_names_in_query(build,
          without: %w[filters:permissions:global:visibility_level:public_and_internal
            filters:permissions:global:visibility_level:public])
      end
    end
  end

  describe 'scoring' do
    it 'wraps the query in a function_score with star_count boost and fork demotion', :aggregate_failures do
      function_score = build.dig(:query, :function_score)

      expect(function_score).to be_present
      expect(function_score[:score_mode]).to eq('multiply')
      expect(function_score[:boost_mode]).to eq('multiply')
      expect(function_score[:functions]).to include(
        { field_value_factor: { field: 'star_count', modifier: 'ln2p', missing: 0 } },
        { filter: { term: { forked: true } }, weight: 0.5 }
      )
    end

    it 'preserves the original bool query inside function_score' do
      expect(build.dig(:query, :function_score, :query, :bool)).to be_present
    end

    context 'when count_only is true' do
      let(:options) { base_options.merge(count_only: true) }

      it 'does not apply function_score' do
        expect(build.dig(:query, :function_score)).to be_nil
      end
    end

    context 'when a non-relevance sort is requested' do
      let(:options) { base_options.merge(order_by: 'created_at', sort: 'desc') }

      it 'does not apply function_score' do
        expect(build.dig(:query, :function_score)).to be_nil
      end
    end
  end

  it_behaves_like 'a sorted query'

  describe 'formats' do
    it_behaves_like 'a query that sets source_fields'
    it_behaves_like 'a query formatted for size'
    it_behaves_like 'a query that is paginated'
  end

  describe 'SCORE_COMPONENTS' do
    it 'declares Scores in SCORE_COMPONENTS instead of QUERY_COMPONENTS', :aggregate_failures do
      expect(described_class::SCORE_COMPONENTS).to eq(
        ::Search::Elastic::Scores => [:wrap]
      )

      expect(described_class::QUERY_COMPONENTS).not_to have_key(::Search::Elastic::Scores)
    end
  end
end
