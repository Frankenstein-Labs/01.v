# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Elastic::Latest::MilestoneClassProxy, :elastic, :sidekiq_inline, feature_category: :global_search do
  include AdminModeHelper

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  subject(:proxy) { described_class.new(Milestone, use_separate_indices: false) }

  describe '#elastic_search' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:query) { 'Foo' }
    let_it_be(:admin_user) { create(:admin) }
    let_it_be(:current_user) { create(:user) }
    let(:options) { { current_user: current_user, project_ids: [project.id] } }
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, :public, group: group) }
    let_it_be(:project_milestone) { create(:milestone, project: project, title: 'Foo') }
    let_it_be(:group_milestone) { create(:milestone, group: group, title: 'Foo Bar') }

    let(:result) { proxy.elastic_search(query, options: options) }

    before do
      Elastic::ProcessInitialBookkeepingService.backfill_projects!(project)
      ensure_elasticsearch_index!
    end

    where(:search_level, :projects, :groups, :is_admin) do
      'global'  | []              | []              | true
      'global'  | []              | []              | false
      'group'   | []              | [ref(:group)]   | true
      'group'   | []              | [ref(:group)]   | false
      'group'   | []              | [ref(:group)]   | true
      'group'   | []              | [ref(:group)]   | false
      'project' | [ref(:project)] | []              | true
      'project' | [ref(:project)] | []              | false
      'project' | [ref(:project)] | [ref(:group)]   | true
      'project' | [ref(:project)] | [ref(:group)]   | false
    end

    with_them do
      let(:project_ids) { projects.map(&:id) }
      let(:group_ids) { groups.map(&:id) }

      let(:options) do
        {
          search_level: search_level,
          project_ids: project_ids,
          group_ids: group_ids,
          order_by: nil,
          sort: nil
        }.tap do |base_options|
          base_options[:current_user] = is_admin ? admin_user : current_user
        end
      end

      shared_examples 'correctly names queries' do
        it 'has the correct named queries' do
          enable_admin_mode!(admin_user) if is_admin
          result.response

          expected_queries = %w[filters:doc:is_a:milestone]
          expected_queries.concat(match_queries)
          expected_queries.concat(%w[filters:non_archived]) if search_level != 'project'

          unless is_admin
            expected_queries.concat(%W[
              filters:permissions:#{search_level}:visibility_level:public_and_internal
              filters:permissions:#{search_level}:issues_access_level:enabled
              filters:permissions:#{search_level}:merge_requests_access_level:enabled
            ])
          end

          assert_named_queries(
            *expected_queries
          )
        end
      end

      it_behaves_like 'correctly names queries' do
        let(:match_queries) { %w[milestone:multi_match:and:search_terms milestone:multi_match_phrase:search_terms] }
      end

      context 'when advanced search syntax is used in the query' do
        let_it_be(:query) { 'Foo*' }

        it_behaves_like 'correctly names queries' do
          let(:match_queries) { %w[milestone:match:search_terms] }
        end
      end
    end
  end
end
