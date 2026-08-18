# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Elastic::Latest::ProjectClassProxy, feature_category: :global_search do
  include AdminModeHelper

  subject(:proxy) { described_class.new(Project, use_separate_indices: true) }

  let_it_be(:current_user) { create(:user) }
  let(:query) { 'foo' }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  describe '#elastic_search', :elastic_delete_by_query do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    let(:result) { proxy.elastic_search(query, options: options) }

    before do
      Elastic::ProcessInitialBookkeepingService.backfill_projects!(project)
      ensure_elasticsearch_index!
    end

    where(:search_level, :projects, :groups) do
      'global' | :any | []
      'global' | [] | []
      'group' | :any | [ref(:group)]
      'group' | [] | [ref(:group)]
    end

    with_them do
      let(:project_ids) { projects.eql?(:any) ? projects : projects.map(&:id) }
      let(:group_ids) { groups.map(&:id) }

      let(:options) do
        {
          current_user: current_user,
          search_level: search_level,
          project_ids: project_ids,
          group_ids: group_ids
        }
      end

      it 'has the correct named queries' do
        admin_mode = project_ids == :any
        enable_admin_mode!(current_user) if admin_mode
        allow(current_user).to receive(:can_read_all_resources?).and_return(admin_mode)

        expected_queries = %w[project:multi_match:and:search_terms project:multi_match_phrase:search_terms
          filters:doc:is_a:project]

        expected_queries.concat(%W[filters:level:#{search_level}]) unless search_level == 'global'

        if projects != :any
          expected_queries.concat(%W[filters:permissions:#{search_level}:visibility_level:public_and_internal])
        end

        result.response

        assert_named_queries(
          *expected_queries
        )
      end

      context 'when advanced search syntax is used' do
        let(:query) { 'test*' }

        it 'uses simple_query_string in query' do
          result.response

          assert_named_queries('project:match:search_terms',
            without: %w[project:multi_match:and:search_terms project:multi_match_phrase:search_terms])
        end
      end

      context 'when include_archived is set' do
        it 'does not have a filter for archived' do
          options[:include_archived] = true

          result.response

          assert_named_queries(
            'project:multi_match:and:search_terms', 'project:multi_match_phrase:search_terms',
            'filters:doc:is_a:project',
            without: %w[filters:archived filters:non_archived]
          )
        end
      end
    end
  end

  describe '#routing_options' do
    let(:options) do
      {
        current_user: current_user,
        search_level: :global
      }
    end

    subject(:routing_options) { described_class.new(Project).routing_options(options) }

    context 'when the reindex_projects_to_apply_routing migration has finished' do
      before do
        allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?)
          .with(:reindex_projects_to_apply_routing).and_return(true)
      end

      it 'is empty' do
        expect(routing_options).to eq({})
      end

      context 'for group level' do
        let_it_be(:parent) { create(:group) }
        let_it_be(:group) { create(:group, parent: parent) }
        let(:options) { { group_id: group.id } }

        it 'routes to the group ancestor id' do
          expect(routing_options).to eq({ routing: "n_#{parent.id}" })
        end

        context 'when the group is not found' do
          let(:options) { { group_id: non_existing_record_id } }

          it 'is empty' do
            expect(routing_options).to eq({})
          end
        end
      end
    end

    context 'when the migration is not finished' do
      before do
        allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?)
          .with(:reindex_projects_to_apply_routing).and_return(false)
      end

      it 'is empty' do
        expect(routing_options).to eq({})
      end
    end
  end
end
