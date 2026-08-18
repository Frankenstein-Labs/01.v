# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting a compliance frameworks list for a project', feature_category: :compliance_management do
  using RSpec::Parameterized::TableSyntax
  include GraphqlHelpers

  let_it_be(:project_member) { create(:project_member, :maintainer) }
  let_it_be(:project) { project_member.project }
  let_it_be(:current_user) { project_member.user }

  let(:query) do
    graphql_query_for(
      :project, { full_path: project.full_path }, query_nodes(:compliance_frameworks)
    )
  end

  let(:compliance_framework_names_list) { graphql_data_at(:project, :complianceFrameworks, :nodes).pluck('name') }

  context 'when the project has no compliance framework assigned' do
    it 'is an empty array' do
      post_graphql(query, current_user: current_user)

      expect(compliance_framework_names_list).to be_empty
    end
  end

  context 'when the project has compliance frameworks assigned' do
    let_it_be(:framework_1) { create(:compliance_framework, name: 'Framework A', updated_at: 1.day.ago) }
    let_it_be(:framework_2) { create(:compliance_framework, name: 'Framework B', updated_at: 5.days.ago) }
    let_it_be(:framework_settings_1) do
      create(:compliance_framework_project_setting, project: project, compliance_management_framework: framework_1)
    end

    let_it_be(:framework_settings_2) do
      create(:compliance_framework_project_setting, project: project, compliance_management_framework: framework_2)
    end

    it 'returns their names' do
      post_graphql(query, current_user: current_user)

      expect(compliance_framework_names_list).to contain_exactly('Framework A', 'Framework B')
    end

    context 'when sorting' do
      where(:sort_enum, :expected_order) do
        :NAME_ASC        | ['Framework A', 'Framework B']
        :NAME_DESC       | ['Framework B', 'Framework A']
        :UPDATED_AT_ASC  | ['Framework B', 'Framework A']
        :UPDATED_AT_DESC | ['Framework A', 'Framework B']
      end

      with_them do
        let(:query) do
          graphql_query_for(
            :project, { full_path: project.full_path },
            query_nodes(:compliance_frameworks, nil, args: {
              sort: sort_enum
            })
          )
        end

        it "sorts frameworks by #{params[:sort_enum]}" do
          post_graphql(query, current_user: current_user)

          expect(compliance_framework_names_list).to eq(expected_order)
        end
      end
    end
  end
end
