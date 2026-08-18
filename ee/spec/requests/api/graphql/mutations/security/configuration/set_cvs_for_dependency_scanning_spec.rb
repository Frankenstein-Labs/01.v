# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Setting CVS for Dependency Scanning', feature_category: :software_composition_analysis do
  using RSpec::Parameterized::TableSyntax
  include GraphqlHelpers

  let(:current_user) { create(:user) }
  let(:security_setting) { create(:project_security_setting, cvs_for_dependency_scanning_enabled: value_before) }
  let(:project) { security_setting.project }
  let(:mutation_name) { :set_cvs_for_dependency_scanning }
  let(:value_before) { false }
  let(:enable) { true }

  let(:mutation) do
    graphql_mutation(
      mutation_name,
      project_path: project.full_path,
      enable: enable
    )
  end

  context 'when the user does not have permission' do
    it_behaves_like 'a mutation that returns a top-level access error'

    it 'does not change the setting' do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .not_to change { security_setting.reload.cvs_for_dependency_scanning_enabled }
    end
  end

  context 'when the user has permission' do
    before do
      project.add_maintainer(current_user)
      stub_licensed_features(dependency_scanning: true)
    end

    where(:value_before, :enable, :value_after) do
      true  | false | false
      true  | true  | true
      false | true  | true
      false | false | false
    end

    with_them do
      it 'updates the setting and returns the new value' do
        post_graphql_mutation(mutation, current_user: current_user)

        response = graphql_mutation_response(mutation_name)
        expect(response).to include({ 'cvsForDependencyScanningEnabled' => value_after, 'errors' => [] })
        expect(security_setting.reload.cvs_for_dependency_scanning_enabled).to eq(value_after)
      end
    end

    context 'when the service returns an error' do
      before do
        allow(::Security::Configuration::SetCvsForScannerTypeService).to receive(:execute).and_return(
          ServiceResponse.error(message: 'failed', payload: { enabled: nil })
        )
      end

      it 'returns an error' do
        post_graphql_mutation(mutation, current_user: current_user)

        response = graphql_mutation_response(mutation_name)
        expect(response).to include({ 'cvsForDependencyScanningEnabled' => nil, 'errors' => be_present })
        expect(security_setting.reload.cvs_for_dependency_scanning_enabled).to be(false)
      end
    end

    context 'when the project is archived' do
      before do
        project.update!(archived: true)
      end

      it_behaves_like 'a mutation that returns a top-level access error'

      it 'does not change the setting' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .not_to change { security_setting.reload.cvs_for_dependency_scanning_enabled }
      end
    end

    context 'when the project group is archived' do
      let(:group) { create(:group, :archived) }
      let(:project) { create(:project, group: group) }

      it_behaves_like 'a mutation that returns a top-level access error'

      it 'does not change the setting' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .not_to change { security_setting.reload.cvs_for_dependency_scanning_enabled }
      end
    end
  end
end
