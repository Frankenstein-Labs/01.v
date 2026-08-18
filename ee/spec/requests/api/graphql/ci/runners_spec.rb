# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query', feature_category: :fleet_visibility do
  include GraphqlHelpers
  include RunnerReleasesHelper

  let_it_be(:current_user) { create_default(:user, :admin) }
  let_it_be(:project) { create(:project, :repository, :public) }

  subject(:request) do
    post_graphql(query, current_user: current_user)
  end

  shared_context 'when runners with builds exist' do
    let_it_be(:instance_runners) { create_list(:ci_runner, 4) }
    let_it_be(:group) { create(:group) }
    let_it_be(:group_runners) { create_list(:ci_runner, 3, :group, groups: [group]) }

    before_all do
      instance_runners.map.with_index do |runner, number_of_builds|
        create_list(:ci_build, number_of_builds, :picked, runner: runner, project: project)
      end

      group_runners.map.with_index do |runner, number_of_builds|
        create_list(:ci_build, 3 + number_of_builds, :picked, runner: runner, project: project)
      end
    end
  end

  # NOTE: No cross-organization isolation test for the admin path (`Query.runners`). It is cell-scoped
  # by design (admins see every runner on the cell, across all organizations), so a second-organization
  # runner is expected to be returned here, not filtered out.
  describe 'Query.runners' do
    let(:runners_graphql_data) { graphql_data['runners'] }
    let(:params) { {} }

    context 'with upgradeStatus argument' do
      let(:upgrade_statuses) { runners_graphql_data['nodes'].map { |n| n.fetch('upgradeStatus') } }
      let(:query) { "{ #{query_nodes(:runners, %i[id upgrade_status])} }" }

      let_it_be(:instance_runner) { create(:ci_runner, :instance) }
      let_it_be(:project_runner) { create(:ci_runner, :project, projects: [project]) }
      let_it_be(:instance_runner_manager) { create(:ci_runner_machine, version: '14.0.0') }
      let_it_be(:project_runner_manager) { create(:ci_runner_machine, version: '14.0.1') }

      before do
        stub_runner_releases(%w[14.0.0 14.0.1])
      end

      it 'returns nil upgradeStatus for all runners' do
        request

        expect(upgrade_statuses).to match_array([nil] * Ci::Runner.count)
      end
    end

    context 'when sorting by MOST_ACTIVE_DESC' do
      let(:sort_param) { :MOST_ACTIVE_DESC }
      let(:args) { { type: :INSTANCE_TYPE, sort: sort_param } }
      let(:query) { "{ #{query_nodes(:runners, :id, args: args)} }" }

      include_context 'when runners with builds exist'

      context 'when runner_performance_insights feature is available' do
        using RSpec::Parameterized::TableSyntax

        before do
          stub_licensed_features(runner_performance_insights: true)
        end

        it_behaves_like 'sorted paginated query' do
          def pagination_query(params)
            "{ #{query_nodes(:runners, :id, args: params.merge(type: :INSTANCE_TYPE), include_pagination_info: true)} }"
          end

          def pagination_results_data(runners)
            runners.map { |runner| GitlabSchema.parse_gid(runner['id'], expected_type: ::Ci::Runner).model_id.to_i }
          end

          let(:first_param) { 2 }
          let(:all_records) { instance_runners[1..3].reverse.map(&:id) }
          let(:data_path) { [:runners] }
        end

        context 'when requesting not runners without type' do
          let(:args) { { sort: :MOST_ACTIVE_DESC } }

          it 'returns error' do
            request

            expect(graphql_errors).to include(a_hash_including(
              'message' => 'MOST_ACTIVE_DESC sorting is only available for groups or when type is INSTANCE_TYPE'))
          end
        end

        context 'when requesting project runners' do
          let(:args) { { sort: :MOST_ACTIVE_DESC } }
          let(:query) do
            graphql_query_for(:project, { full_path: project.full_path }, query_nodes(:runners, :id, args: args))
          end

          it 'returns error' do
            request

            expect_graphql_errors_to_include(
              'MOST_ACTIVE_DESC sorting is only available for groups or when type is INSTANCE_TYPE')
          end
        end

        context 'with invalid type' do
          let(:args) { extra_args.merge(sort: sort_param) }

          where(:case_name, :extra_args) do
            'when requesting GROUP_TYPE runners' | { type: :GROUP_TYPE }
            'when requesting PROJECT_TYPE runners' | { type: :PROJECT_TYPE }
            'when requesting runners without type' | {}
          end

          with_them do
            it 'returns error' do
              request

              expect_graphql_errors_to_include(
                'MOST_ACTIVE_DESC sorting is only available for groups or when type is INSTANCE_TYPE')
            end
          end
        end
      end

      context 'when runner_performance_insights feature is not available' do
        it 'returns error' do
          request

          expect_graphql_errors_to_include(
            'runner_performance_insights feature is required for MOST_ACTIVE_DESC sorting')
        end
      end
    end
  end

  describe 'Query.group.runners' do
    let(:query) do
      graphql_query_for(:group, { full_path: group.full_path }, query_nodes(:runners, :id, args: args))
    end

    context 'with a runner outside the group' do
      let_it_be(:group) { create(:group) }
      let_it_be(:group_owner) { create_default(:user, owner_of: group) }
      let_it_be(:group_runner) { create(:ci_runner, :group, groups: [group]) }
      let_it_be(:other_organization) { create(:organization) }
      let_it_be(:other_org_group) { create(:group, organization: other_organization) }
      let_it_be(:other_org_runner) { create(:ci_runner, :group, groups: [other_org_group]) }

      let(:args) { {} }

      it 'does not return runners outside the group', :aggregate_failures do
        post_graphql(query, current_user: group_owner)

        returned_ids = graphql_data_at(:group, :runners, :nodes).pluck('id')
        expect(returned_ids).to include(group_runner.to_global_id.to_s)
        expect(returned_ids).not_to include(other_org_runner.to_global_id.to_s)
      end
    end

    context 'with membership argument' do
      let_it_be(:group) { create(:group) }
      let_it_be(:group2) { create(:group) }
      let_it_be(:sub_group) { create(:group, parent: group) }
      let_it_be(:group_runner) { create(:ci_runner, :group, groups: [group]) }
      let_it_be(:sub_group_runner) { create(:ci_runner, :group, groups: [sub_group]) }

      let(:args) { { membership: :DESCENDANTS } }
      let(:actual_runner_ids) { graphql_data_at(:group, :runners, :nodes).map { |r| r['id'] } }
      let(:expected_runner_ids) { [group_runner, sub_group_runner].map { |r| r.to_global_id.to_s } }

      it 'matches expected runner ids' do
        request

        expect(actual_runner_ids).to match_array(expected_runner_ids)
      end
    end

    context 'when sorting by MOST_ACTIVE_DESC' do
      let(:sort_param) { :MOST_ACTIVE_DESC }

      include_context 'when runners with builds exist'

      context 'when runner_performance_insights_for_namespace feature is available' do
        using RSpec::Parameterized::TableSyntax

        before do
          stub_licensed_features(runner_performance_insights_for_namespace: true)
        end

        context 'with direct membership' do
          let(:args) { { membership: :DIRECT, sort: sort_param } }

          it_behaves_like 'sorted paginated query' do
            def pagination_query(params)
              graphql_query_for(:group, { full_path: group.full_path },
                query_nodes(:runners, :id, args: params.merge(membership: :DIRECT), include_pagination_info: true))
            end

            def pagination_results_data(runners)
              runners.map { |runner| GitlabSchema.parse_gid(runner['id'], expected_type: ::Ci::Runner).model_id.to_i }
            end

            let(:first_param) { 2 }
            let(:all_records) { group_runners.reverse.map(&:id) }
            let(:data_path) { %i[group runners] }
          end

          it 'returns expected runners' do
            request

            expect_graphql_errors_to_be_empty
            expect(graphql_data_at(:group, :runners, :nodes)).to match(
              group_runners.reverse.map { |runner| a_graphql_entity_for(runner) }
            )
          end
        end

        context 'with invalid membership' do
          let(:args) { extra_args.merge(sort: :MOST_ACTIVE_DESC) }

          where(:case_name, :extra_args) do
            'when requesting all available group runners' | { membership: :ALL_AVAILABLE }
            'when requesting group descendant runners' | { membership: :DESCENDANTS }
            'when requesting group runners with unspecified membership' | {}
          end

          with_them do
            it 'returns error' do
              request

              expect_graphql_errors_to_include(
                'MOST_ACTIVE_DESC sorting is only supported on groups when membership is DIRECT')
            end
          end
        end

        context 'when requesting project runners' do
          let(:args) { { sort: :MOST_ACTIVE_DESC } }
          let(:query) do
            graphql_query_for(:project, { full_path: project.full_path }, query_nodes(:runners, :id, args: args))
          end

          it 'returns error' do
            request

            expect_graphql_errors_to_include(
              'MOST_ACTIVE_DESC sorting is only available for groups or when type is INSTANCE_TYPE')
          end
        end
      end

      context 'when runner_performance_insights_for_namespace feature is not available' do
        context 'with direct membership' do
          let(:args) { { membership: :DIRECT, sort: sort_param } }

          it 'returns error' do
            request

            expect_graphql_errors_to_include(
              'runner_performance_insights_for_namespace feature is required for MOST_ACTIVE_DESC sorting')
          end
        end
      end
    end
  end
end
