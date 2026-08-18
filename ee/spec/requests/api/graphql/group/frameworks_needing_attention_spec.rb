# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting frameworks needing attention for a group', feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }

  let(:fields) do
    <<~GRAPHQL
      nodes {
        id
        framework {
          id
          name
          color
        }
        projectsCount
        requirementsCount
        requirementsWithoutControls {
          id
          name
          description
        }
      }
    GRAPHQL
  end

  let(:frameworks_needing_attention) { graphql_data_at(:group, :compliance_frameworks_needing_attention, :nodes) }

  def query
    graphql_query_for(
      :group, { full_path: group.full_path },
      query_graphql_field("complianceFrameworksNeedingAttention", {}, fields)
    )
  end

  before do
    stub_licensed_features(group_level_compliance_dashboard: true)
  end

  shared_examples 'returns nil' do
    it 'returns nil' do
      post_graphql(query, current_user: current_user)

      expect(frameworks_needing_attention).to be_nil
    end
  end

  context 'when the user is unauthorized' do
    context 'when not part of the group' do
      it_behaves_like 'returns nil'
    end

    context 'with maintainer access' do
      before_all do
        group.add_maintainer(current_user)
      end

      it_behaves_like 'returns nil'
    end
  end

  context 'when the user is authorized' do
    before_all do
      group.add_owner(current_user)
    end

    it_behaves_like 'a working graphql query' do
      before do
        post_graphql(query, current_user: current_user)
      end
    end

    context 'when group has no frameworks' do
      it 'returns empty array' do
        post_graphql(query, current_user: current_user)

        expect(frameworks_needing_attention).to eq([])
      end
    end

    context 'when framework is complete (has projects, requirements with controls)' do
      let_it_be(:complete_framework) { create(:compliance_framework, namespace: group, name: 'Complete Framework') }
      let_it_be(:project) { create(:project, group: group) }
      let_it_be(:requirement) { create(:compliance_requirement, framework: complete_framework) }

      before_all do
        create(:compliance_framework_project_setting,
          compliance_management_framework: complete_framework,
          project: project)
        create(:compliance_requirements_control, compliance_requirement: requirement)
      end

      it 'does not return the complete framework' do
        post_graphql(query, current_user: current_user)

        framework_names = frameworks_needing_attention.map { |f| f.dig('framework', 'name') }
        expect(framework_names).not_to include('Complete Framework')
      end
    end

    context 'when framework is missing projects' do
      let_it_be(:framework_without_projects) do
        create(:compliance_framework, namespace: group, name: 'No Projects Framework')
      end

      let_it_be(:requirement) { create(:compliance_requirement, framework: framework_without_projects) }

      before_all do
        create(:compliance_requirements_control, compliance_requirement: requirement)
      end

      it 'returns the framework' do
        post_graphql(query, current_user: current_user)

        framework = frameworks_needing_attention.find { |f| f.dig('framework', 'name') == 'No Projects Framework' }

        expect(framework).not_to be_nil
        expect(framework['projectsCount']).to eq(0)
        expect(framework['requirementsCount']).to eq(1)
        expect(framework['requirementsWithoutControls']).to eq([])
      end
    end

    context 'when framework is missing requirements' do
      let_it_be(:framework_without_requirements) do
        create(:compliance_framework, namespace: group, name: 'No Requirements Framework')
      end

      let_it_be(:project) { create(:project, group: group) }

      before_all do
        create(:compliance_framework_project_setting,
          compliance_management_framework: framework_without_requirements,
          project: project)
      end

      it 'returns the framework' do
        post_graphql(query, current_user: current_user)

        framework = frameworks_needing_attention.find { |f| f.dig('framework', 'name') == 'No Requirements Framework' }

        expect(framework).not_to be_nil
        expect(framework['projectsCount']).to eq(1)
        expect(framework['requirementsCount']).to eq(0)
        expect(framework['requirementsWithoutControls']).to eq([])
      end
    end

    context 'when framework has requirements without controls' do
      let_it_be(:framework_with_requirements_without_controls) do
        create(:compliance_framework, namespace: group, name: 'Requirements Without Controls Framework')
      end

      let_it_be(:project) { create(:project, group: group) }
      let_it_be(:requirement_with_control) do
        create(:compliance_requirement,
          framework: framework_with_requirements_without_controls,
          name: 'Requirement with Control')
      end

      let_it_be(:requirement_without_control_1) do
        create(:compliance_requirement,
          framework: framework_with_requirements_without_controls,
          name: 'Requirement without Control 1',
          description: 'First requirement needing controls')
      end

      let_it_be(:requirement_without_control_2) do
        create(:compliance_requirement,
          framework: framework_with_requirements_without_controls,
          name: 'Requirement without Control 2',
          description: 'Second requirement needing controls')
      end

      before_all do
        create(:compliance_framework_project_setting,
          compliance_management_framework: framework_with_requirements_without_controls,
          project: project)
        create(:compliance_requirements_control, compliance_requirement: requirement_with_control)
      end

      it 'returns the framework with requirements without controls' do
        post_graphql(query, current_user: current_user)

        framework = frameworks_needing_attention.find do |f|
          f.dig('framework', 'name') == 'Requirements Without Controls Framework'
        end

        expect(framework).not_to be_nil
        expect(framework['projectsCount']).to eq(1)
        expect(framework['requirementsCount']).to eq(3)

        requirements_without_controls = framework['requirementsWithoutControls']
        expect(requirements_without_controls.size).to eq(2)

        names = requirements_without_controls.pluck('name')
        expect(names).to contain_exactly('Requirement without Control 1', 'Requirement without Control 2')
        expect(names).not_to include('Requirement with Control')

        req1 = requirements_without_controls.find { |r| r['name'] == 'Requirement without Control 1' }
        expect(req1['description']).to eq('First requirement needing controls')

        req2 = requirements_without_controls.find { |r| r['name'] == 'Requirement without Control 2' }
        expect(req2['description']).to eq('Second requirement needing controls')
      end
    end

    context 'when framework is missing both projects and requirements' do
      let_it_be(:empty_framework) { create(:compliance_framework, namespace: group, name: 'Empty Framework') }

      it 'returns the framework' do
        post_graphql(query, current_user: current_user)

        framework = frameworks_needing_attention.find { |f| f.dig('framework', 'name') == 'Empty Framework' }

        expect(framework).not_to be_nil
        expect(framework['projectsCount']).to eq(0)
        expect(framework['requirementsCount']).to eq(0)
        expect(framework['requirementsWithoutControls']).to eq([])
      end
    end

    context 'when multiple frameworks need attention' do
      let_it_be(:framework_no_projects) do
        create(:compliance_framework, namespace: group, name: 'Framework A - No Projects')
      end

      let_it_be(:framework_no_requirements) do
        create(:compliance_framework, namespace: group, name: 'Framework B - No Requirements')
      end

      let_it_be(:framework_empty) do
        create(:compliance_framework, namespace: group, name: 'Framework C - Empty')
      end

      let_it_be(:project) { create(:project, group: group) }

      before_all do
        requirement = create(:compliance_requirement, framework: framework_no_projects)
        create(:compliance_requirements_control, compliance_requirement: requirement)

        create(:compliance_framework_project_setting,
          compliance_management_framework: framework_no_requirements,
          project: project)
      end

      it 'returns all frameworks needing attention' do
        post_graphql(query, current_user: current_user)

        framework_names = frameworks_needing_attention.map { |f| f.dig('framework', 'name') }

        expect(framework_names).to contain_exactly(
          'Framework A - No Projects',
          'Framework B - No Requirements',
          'Framework C - Empty'
        )
      end
    end
  end
end
