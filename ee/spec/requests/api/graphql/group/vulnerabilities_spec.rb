# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Vulnerabilities through GroupQuery', feature_category: :vulnerability_management do
  include GraphqlHelpers

  describe 'Querying vulnerabilities with `archivalInformation` field' do
    let_it_be(:current_user) { create(:user) }
    let_it_be(:top_level_group) { create(:group) }
    let_it_be(:sub_group_1) { create(:group, parent: top_level_group) }
    let_it_be(:sub_group_2) { create(:group, parent: top_level_group) }

    let_it_be(:project_1) { create(:project, :public, group: top_level_group) }
    let_it_be(:project_2) { create(:project, :public, group: sub_group_1) }
    let_it_be(:project_3) { create(:project, :public, group: sub_group_2) }

    let!(:vulnerability_1) { create(:vulnerability, :with_read, project: project_1) }
    let!(:vulnerability_2) { create(:vulnerability, :with_read, project: project_2, updated_at: 14.months.ago) }
    let!(:vulnerability_3) { create(:vulnerability, :with_read, project: project_3) }

    let(:vulnerabilities_returned) { graphql_data.dig('group', 'vulnerabilities', 'nodes') }

    let(:fields) do
      <<~QUERY
        nodes {
          id
          archivalInformation {
            aboutToBeArchived
            expectedToBeArchivedOn
          }
        }
      QUERY
    end

    let(:query) do
      graphql_query_for(
        :group,
        { full_path: top_level_group.full_path },
        query_graphql_field(:vulnerabilities, fields)
      )
    end

    def execute_graphql_query
      post_graphql(query, current_user: current_user)
    end

    subject(:execute) { execute_graphql_query }

    before do
      stub_licensed_features(security_dashboard: true)

      stub_feature_flags(vulnerability_archival: true)
    end

    context 'when the user is not member of the group' do
      it 'does not return any data' do
        execute_graphql_query

        expect(vulnerabilities_returned).to be_empty
      end
    end

    context 'when the user is a member of the group' do
      before_all do
        top_level_group.add_maintainer(current_user)
      end

      describe 'archival' do
        around do |example|
          travel_to('2025-04-02') { example.run }
        end

        it 'returns the `aboutToBeArchived` information' do
          execute_graphql_query

          expect(vulnerabilities_returned).to match_array([
            {
              'id' => vulnerability_1.to_global_id.to_s,
              'archivalInformation' => { 'aboutToBeArchived' => false, 'expectedToBeArchivedOn' => '2026-05-01' }
            },
            {
              'id' => vulnerability_2.to_global_id.to_s,
              'archivalInformation' => { 'aboutToBeArchived' => true, 'expectedToBeArchivedOn' => '2025-05-01' }
            },
            {
              'id' => vulnerability_3.to_global_id.to_s,
              'archivalInformation' => { 'aboutToBeArchived' => false, 'expectedToBeArchivedOn' => '2026-05-01' }
            }
          ])
        end
      end

      describe 'trackedRefIds filter', :elastic do
        let_it_be(:tracked_ref) { create(:security_project_tracked_context, project: project_1) }
        let_it_be(:vulnerability_read) do
          create(:vulnerability_read, project: project_1, tracked_context: tracked_ref)
        end

        let_it_be(:tracked_ref_on_different_project) { create(:security_project_tracked_context, project: project_2) }
        let_it_be(:vulnerability_read_on_different_project) do
          create(:vulnerability_read, project: project_2, tracked_context: tracked_ref_on_different_project)
        end

        let_it_be(:out_of_scope_ref) { create(:security_project_tracked_context, project: project_1) }
        let_it_be(:out_of_scope_read) do
          create(:vulnerability_read, project: project_1, tracked_context: out_of_scope_ref)
        end

        let(:query) do
          %(
            query {
              group(fullPath: "#{top_level_group.full_path}") {
                vulnerabilities(trackedRefIds: [
                  "#{tracked_ref.to_global_id}",
                  "#{tracked_ref_on_different_project.to_global_id}"
                ]) {
                  nodes {
                    id
                  }
                }
              }
            }
          )
        end

        before do
          stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)

          Elastic::ProcessBookkeepingService.track!(
            vulnerability_read,
            vulnerability_read_on_different_project,
            out_of_scope_read
          )

          ensure_elasticsearch_index!

          allow(current_user)
            .to receive(:can?)
                  .with(:access_advanced_vulnerability_management, top_level_group)
                  .and_return(true)
        end

        it 'returns vulnerabilities from the tracked ref' do
          execute_graphql_query

          expected_gids = [vulnerability_read, vulnerability_read_on_different_project].map do |read|
            read.vulnerability.to_global_id.to_s
          end

          expect(vulnerabilities_returned.pluck('id')).to match_array(expected_gids)
        end

        it_behaves_like 'validates tracked ref filters' do
          let(:user) { current_user }
          let(:actor) { top_level_group }
        end
      end

      describe 'trackedRefsScope filter', :elastic do
        let_it_be(:default_branch_ref) { create(:security_project_tracked_context, :default, project: project_1) }
        let_it_be(:default_read) do
          create(:vulnerability_read, project: project_1, tracked_context: default_branch_ref)
        end

        let_it_be(:tracked_ref_on_different_project) { create(:security_project_tracked_context, project: project_2) }
        let_it_be(:vulnerability_read_on_different_project) do
          create(:vulnerability_read, project: project_2, tracked_context: tracked_ref_on_different_project)
        end

        let_it_be(:feature_ref) { create(:security_project_tracked_context, project: project_1) }
        let_it_be(:feature_read) do
          create(:vulnerability_read, project: project_1, tracked_context: feature_ref)
        end

        let(:scope_value) { 'DEFAULT_BRANCHES' }

        let(:query) do
          %(
            query {
              group(fullPath: "#{top_level_group.full_path}") {
                vulnerabilities(trackedRefsScope: #{scope_value}) {
                  nodes {
                    id
                  }
                }
              }
            }
          )
        end

        before do
          stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)

          Elastic::ProcessBookkeepingService.track!(
            default_read,
            vulnerability_read_on_different_project,
            feature_read
          )

          ensure_elasticsearch_index!

          allow(current_user)
            .to receive(:can?)
                  .with(:access_advanced_vulnerability_management, top_level_group)
                  .and_return(true)
        end

        it_behaves_like 'validates tracked ref filters' do
          let(:user) { current_user }
          let(:actor) { top_level_group }
        end

        where(:scope_value, :expected_reads) do
          'DEFAULT_BRANCHES' | [ref(:default_read)]
          'ALL_REFS'         | [ref(:default_read), ref(:vulnerability_read_on_different_project), ref(:feature_read)]
        end

        using RSpec::Parameterized::TableSyntax

        with_them do
          it 'returns vulnerabilities as expected' do
            execute_graphql_query

            expected_gids = expected_reads.map do |read|
              read.vulnerability.to_global_id.to_s
            end

            expect(vulnerabilities_returned.pluck('id')).to match_array(expected_gids)
          end
        end

        context 'with no filter' do
          let(:query) do
            %(
            query {
              group(fullPath: "#{top_level_group.full_path}") {
                vulnerabilities {
                  nodes {
                    id
                  }
                }
              }
            }
          )
          end

          it 'returns vulnerabilities as expected' do
            execute_graphql_query

            default_gid = default_read.vulnerability.to_global_id.to_s
            expect(vulnerabilities_returned.pluck('id')).to contain_exactly(default_gid)
          end
        end
      end

      it 'does not cause N+1 query issue' do
        execute_graphql_query

        queries_recorded = ActiveRecord::QueryRecorder.new(skip_cached: false) { execute_graphql_query }

        new_project = create(:project, group: sub_group_2)
        create(:vulnerability, :with_read, project: new_project)

        expect { execute_graphql_query }.to issue_same_number_of_queries_as(queries_recorded).with_threshold(4)
      end
    end
  end
end
