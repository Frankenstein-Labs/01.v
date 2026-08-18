# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Security::NamespaceSecurityProjectsResolver, feature_category: :security_asset_inventories do
  include GraphqlHelpers

  describe '#resolve' do
    subject(:resolved) do
      resolve(described_class, args: params.merge({ namespace_id: namespace_global_id }),
        ctx: { current_user: current_user },
        arg_style: :internal,
        field_opts: {
          connection_extension: Gitlab::Graphql::Extensions::ExternallyPaginatedArrayExtension
        }
      )
    end

    let_it_be(:current_user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:project1) { create(:project, name: 'Michael scott', namespace: group) }
    let_it_be(:project2) { create(:project, name: 'Jim Halpert', namespace: group) }
    let_it_be(:project3) { create(:project, name: 'Dwight Schrute', namespace: group) }
    let_it_be(:archived_project) { create(:project, :archived, namespace: group) }
    let_it_be(:other_group_project) { create(:project) }

    let_it_be(:inventory_filter1) do
      create(:security_inventory_filters,
        project: project1,
        critical: 5,
        high: 10,
        sast: :success,
        secret_detection: :failed
      )
    end

    let_it_be(:inventory_filter2) do
      create(:security_inventory_filters,
        project: project2,
        critical: 0,
        high: 2,
        sast: :failed,
        secret_detection: :success
      )
    end

    let_it_be(:inventory_filter3) do
      create(:security_inventory_filters,
        project: project3,
        critical: 3,
        high: 7,
        sast: :not_configured,
        secret_detection: :success
      )
    end

    let_it_be(:project4) { create(:project, name: 'stale-project', namespace: group) }
    let_it_be(:inventory_filter4) do
      create(:security_inventory_filters, project: project4, sast: :stale)
    end

    let(:namespace) { group }
    let(:namespace_global_id) { namespace.to_global_id }
    let(:params) { { namespace_id: namespace_global_id } }

    before_all do
      group.add_developer(current_user)
    end

    before do
      stub_licensed_features(security_inventory: true)
    end

    context 'when user does not have read_security_inventory permission' do
      let_it_be(:guest_user) { create(:user) }
      let(:current_user) { guest_user }

      before_all do
        group.add_guest(guest_user)
      end

      it 'raises an authorization error' do
        expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ResourceNotAvailable) do
          resolved
        end
      end
    end

    context 'when user has proper permissions' do
      context 'without filters' do
        it 'returns all non-archived projects in the namespace' do
          expect(resolved.nodes).to contain_exactly(project1, project2, project3, project4)
          expect(resolved.nodes).not_to include(archived_project)
        end

        it 'does not include projects from other namespaces' do
          expect(resolved.nodes).not_to include(other_group_project)
        end
      end

      context 'with search filter' do
        let(:params) { { search: 'Halpert' } }

        it 'returns projects matching the search term' do
          expect(resolved.nodes).to contain_exactly(project2)
        end
      end

      context 'with single vulnerability count filter' do
        let(:params) do
          {
            vulnerability_count_filters: [
              { severity: 'critical', operator: 'greater_than_or_equal_to', count: 3 }
            ]
          }
        end

        it 'returns projects matching the vulnerability count criteria' do
          expect(resolved.nodes).to contain_exactly(project1, project3)
        end
      end

      context 'with single security analyzer filter' do
        let(:params) do
          {
            security_analyzer_filters: [
              { analyzer_type: 'sast', status: 'success' }
            ]
          }
        end

        it 'returns projects matching the analyzer status' do
          expect(resolved.nodes).to contain_exactly(project1)
        end
      end

      context 'with stale security analyzer filter' do
        let(:params) do
          {
            security_analyzer_filters: [
              { analyzer_type: 'sast', status: 'stale' }
            ]
          }
        end

        it 'returns projects with stale analyzer status' do
          expect(resolved.nodes).to contain_exactly(project4)
        end
      end

      context 'with multiple vulnerability count filters' do
        let(:params) do
          {
            vulnerability_count_filters: [
              { severity: 'critical', operator: 'greater_than_or_equal_to', count: 3 },
              { severity: 'high', operator: 'less_than_or_equal_to', count: 7 }
            ]
          }
        end

        it 'applies all filters (AND condition)' do
          expect(resolved.nodes).to contain_exactly(project3)
        end
      end

      context 'with multiple security analyzer filters' do
        let(:params) do
          {
            security_analyzer_filters: [
              { analyzer_type: 'sast', status: 'failed' },
              { analyzer_type: 'secret_detection', status: 'success' }
            ]
          }
        end

        it 'applies all filters (AND condition)' do
          expect(resolved.nodes).to contain_exactly(project2)
        end
      end

      context 'with combined vulnerability and analyzer filters' do
        let(:params) do
          {
            vulnerability_count_filters: [
              { severity: 'critical', operator: 'greater_than_or_equal_to', count: 3 }
            ],
            security_analyzer_filters: [
              { analyzer_type: 'secret_detection', status: 'success' }
            ]
          }
        end

        it 'applies all filters together' do
          expect(resolved.nodes).to contain_exactly(project3)
        end
      end

      context 'with security attribute filters' do
        let_it_be(:security_category) { create(:security_category, namespace: group, name: 'Environment') }
        let_it_be(:attribute1) do
          create(:security_attribute, security_category: security_category, namespace: group, name: 'Production')
        end

        let_it_be(:attribute2) do
          create(:security_attribute, security_category: security_category, namespace: group, name: 'Staging')
        end

        let_it_be(:project1_attribute1) do
          create(:project_to_security_attribute, project: project1, security_attribute: attribute1,
            traversal_ids: project1.namespace.traversal_ids)
        end

        let_it_be(:project2_attribute2) do
          create(:project_to_security_attribute, project: project2, security_attribute: attribute2,
            traversal_ids: project2.namespace.traversal_ids)
        end

        context 'with is_one_of filter' do
          let(:params) do
            {
              attribute_filters: [
                {
                  operator: 'is_one_of',
                  attributes: [attribute1.id]
                }
              ]
            }
          end

          it 'returns projects with the specified attribute' do
            expect(resolved.nodes).to contain_exactly(project1)
          end
        end

        context 'with is_not_one_of filter' do
          let(:params) do
            {
              attribute_filters: [
                {
                  operator: 'is_not_one_of',
                  attributes: [attribute1.id]
                }
              ]
            }
          end

          it 'returns projects without the specified attribute' do
            expect(resolved.nodes).to contain_exactly(project2, project3, project4)
          end
        end

        context 'with empty attributes array' do
          let(:params) do
            {
              attribute_filters: [
                {
                  operator: 'is_one_of',
                  attributes: []
                }
              ]
            }
          end

          it 'returns no results' do
            expect(resolved.nodes).to be_empty
          end
        end

        context 'with attributes from different namespace' do
          let(:params) do
            {
              attribute_filters: [
                {
                  operator: 'is_one_of',
                  attributes: [non_existing_record_id]
                }
              ]
            }
          end

          it 'returns no results (attributes not in scope)' do
            expect(resolved.nodes).to be_empty
          end
        end

        context 'with combined filters including security attributes' do
          let(:params) do
            {
              vulnerability_count_filters: [
                { severity: 'critical', operator: 'greater_than_or_equal_to', count: 3 }
              ],
              attribute_filters: [
                {
                  operator: 'is_one_of',
                  attributes: [attribute1.id]
                }
              ]
            }
          end

          it 'applies all filters together' do
            expect(resolved.nodes).to contain_exactly(project1)
          end
        end
      end

      context 'with first parameter for pagination' do
        let(:params) { { first: 2 } }

        it 'returns the first N projects' do
          expect(resolved.nodes.size).to eq(2)
        end

        it 'has correct pagination info' do
          expect(resolved).to have_attributes(
            has_next_page: true,
            has_previous_page: false
          )
        end

        it 'has start and end cursors' do
          expect(resolved.start_cursor).to be_present
          expect(resolved.end_cursor).to be_present
        end
      end

      context 'with last parameter for pagination' do
        let(:params) { { last: 2 } }

        it 'returns the last N projects' do
          expect(resolved.nodes.size).to eq(2)
        end

        it 'has correct pagination info' do
          expect(resolved).to have_attributes(
            has_next_page: false,
            has_previous_page: true
          )
        end
      end

      context 'with after cursor for pagination' do
        let(:cursor) do
          Base64.strict_encode64({
            'project_id' => project1.id,
            'traversal_ids' => inventory_filter1.traversal_ids
          }.to_json)
        end

        let(:params) { { first: 2, after: cursor } }

        it 'returns projects after the cursor' do
          expect(resolved.nodes).to contain_exactly(project2, project3)
        end

        it 'indicates previous page exists' do
          expect(resolved.has_previous_page).to be true
        end
      end

      context 'with before cursor for pagination' do
        let(:cursor) do
          Base64.strict_encode64({
            'project_id' => project3.id,
            'traversal_ids' => inventory_filter3.traversal_ids
          }.to_json)
        end

        let(:params) { { last: 2, before: cursor } }

        it 'returns projects before the cursor' do
          expect(resolved.nodes).to contain_exactly(project1, project2)
        end

        it 'indicates next page exists' do
          expect(resolved.has_next_page).to be true
        end
      end

      context 'with pagination and filters combined' do
        let(:params) do
          {
            first: 1,
            vulnerability_count_filters: [
              { severity: 'critical', operator: 'greater_than_or_equal_to', count: 3 }
            ]
          }
        end

        it 'applies filters before pagination' do
          # Should only return one of project1 or project3
          expect(resolved.nodes.size).to eq(1)
          expect([project1, project3]).to include(resolved.nodes.first)
          expect(resolved.has_next_page).to be true
        end
      end

      context 'when no projects match filters' do
        let(:params) do
          {
            vulnerability_count_filters: [
              { severity: 'critical', operator: 'greater_than_or_equal_to', count: 100 }
            ]
          }
        end

        it 'returns an empty connection with no pagination' do
          expect(resolved.nodes).to be_empty
          expect(resolved).to have_attributes(
            has_next_page: false,
            has_previous_page: false,
            start_cursor: nil,
            end_cursor: nil
          )
        end
      end

      context 'with sort_by argument' do
        context 'when sort_by is provided' do
          let(:params) { { sort_by: 'sast' } }

          it 'forwards sort_by to the projects finder service' do
            expect(::Security::InventoryFilters::ProjectsFinderService)
              .to receive(:new)
              .with(namespace: group, params: hash_including(sort_by: 'sast'))
              .and_call_original

            resolved
          end
        end

        context 'when sorting by analyzer status' do
          def create_project_with_sast(status)
            create(:project, namespace: sort_group).tap do |project|
              create(:security_inventory_filters, project: project, sast: status)
            end
          end

          let_it_be(:sort_group) { create(:group) }
          let_it_be(:success_project) { create_project_with_sast(:success) }
          let_it_be(:not_configured_project) { create_project_with_sast(:not_configured) }
          let_it_be(:stale_project) { create_project_with_sast(:stale) }
          let_it_be(:failed_projects) { Array.new(2) { create_project_with_sast(:failed) } }

          let(:namespace) { sort_group }
          let(:params) { { sort_by: 'sast' } }

          before_all do
            sort_group.add_developer(current_user)
          end

          it 'returns projects ordered by analyzer status, ascending project id within a status' do
            ordered_failed_projects = failed_projects.sort_by(&:id)

            expect(resolved.nodes).to eq(
              [*ordered_failed_projects, stale_project, not_configured_project, success_project]
            )
          end
        end
      end

      context 'with subgroup projects' do
        let_it_be(:subgroup) { create(:group, parent: group) }
        let_it_be(:subgroup_project) { create(:project, namespace: subgroup) }
        let_it_be(:subgroup_inventory_filter) do
          create(:security_inventory_filters, project: subgroup_project)
        end

        it 'does not include subgroup projects by default' do
          expect(resolved.nodes).not_to include(subgroup_project)
        end

        context 'when include_subgroups is true' do
          let(:params) { { include_subgroups: true } }

          it 'include subgroup projects' do
            expect(resolved.nodes).to include(subgroup_project)
          end
        end
      end
    end
  end
end
