# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Setting Project Container Scanning for Registry', feature_category: :software_composition_analysis do
  using RSpec::Parameterized::TableSyntax
  include GraphqlHelpers

  before do
    stub_licensed_features(container_scanning_for_registry: true)
  end

  let(:current_user) { create(:user) }
  let(:security_setting) { create(:project_security_setting, container_scanning_for_registry_enabled: value_before) }
  let(:mutation_name) { :set_container_scanning_for_registry }

  let(:value_before) { false }
  let(:enable) { true }

  context 'with project' do
    let(:project) { security_setting.project }
    let(:mutation) do
      graphql_mutation(
        mutation_name,
        namespace_path: project.full_path,
        enable: enable
      )
    end

    context 'when the user does not have permission' do
      it_behaves_like 'a mutation that returns a top-level access error'

      it 'does not enable container scanning for registry' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .not_to change { security_setting.reload.container_scanning_for_registry_enabled }
      end
    end

    context 'when the user has permission' do
      before do
        project.add_maintainer(current_user)
      end

      where(:value_before, :enable, :value_after) do
        true  | false | false
        true  | true  | true
        false | true  | true
        false | false | false
      end

      with_them do
        it 'updates the namespace setting and returns the new value' do
          post_graphql_mutation(mutation, current_user: current_user)

          response = graphql_mutation_response(mutation_name)
          expect(response).to include({ 'containerScanningForRegistryEnabled' => value_after, 'errors' => [] })

          expect(security_setting.reload.container_scanning_for_registry_enabled).to eq(value_after)
        end
      end

      context 'when an invalid value is provided' do
        let(:enable) { true }
        let(:value_before) { false }

        before do
          allow(::Security::Configuration::SetContainerScanningForRegistryService).to receive(:execute).and_return(
            ServiceResponse.error(message: 'failed', payload: { enabled: nil })
          )
        end

        it 'returns an error' do
          post_graphql_mutation(mutation, current_user: current_user)

          response = graphql_mutation_response(mutation_name)
          expect(response).to include({ 'containerScanningForRegistryEnabled' => nil, 'errors' => be_present })

          expect(security_setting.reload.container_scanning_for_registry_enabled).to be(false)
        end
      end

      context 'when a project is archived' do
        before do
          project.update!(archived: true)
        end

        it_behaves_like 'a mutation that returns a top-level access error'

        it 'does not enable container scanning for registry' do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .not_to change { security_setting.reload.secret_push_protection_enabled }
        end
      end

      context 'when projects group is archived' do
        let(:group) { create(:group, :archived) }
        let(:project) { create(:project, group: group) }

        it_behaves_like 'a mutation that returns a top-level access error'

        it 'does not enable container scanning for registry' do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .not_to change { security_setting.reload.secret_push_protection_enabled }
        end
      end
    end
  end
end
