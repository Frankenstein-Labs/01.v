# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Destroy a Compliance Requirement Control', feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:namespace) { create(:group) }
  let_it_be(:requirement) do
    create(:compliance_requirement, framework: create(:compliance_framework, namespace: namespace))
  end

  let_it_be(:control) { create(:compliance_requirements_control, compliance_requirement: requirement) }

  let_it_be(:current_user) { create(:user) }
  let(:mutation) { graphql_mutation(:destroy_compliance_requirements_control, { id: global_id_of(control) }) }

  subject(:mutate) { post_graphql_mutation(mutation, current_user: current_user) }

  def mutation_response
    graphql_mutation_response(:destroy_compliance_requirements_control)
  end

  context 'when feature is unlicensed' do
    before do
      stub_licensed_features(custom_compliance_frameworks: false)
    end

    it 'does not destroy a compliance requirement control' do
      expect { mutate }.not_to change { ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl.count }
    end

    it_behaves_like 'a mutation that returns top-level errors',
      errors: [Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR]
  end

  context 'when licensed' do
    before do
      stub_licensed_features(custom_compliance_frameworks: true)
    end

    context 'when current_user is namespace owner' do
      before_all do
        namespace.add_owner(current_user)
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL', :delete_compliance_requirements_control do
        let(:user) { current_user }
        let(:boundary_object) { namespace }
        let(:mutation) do
          graphql_mutation(:destroy_compliance_requirements_control, { id: global_id_of(control) }, 'errors')
        end

        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end

      it 'has no errors' do
        mutate

        expect(mutation_response['errors']).to be_empty
      end

      it 'destroys a compliance requirement control' do
        expect { mutate }.to change {
          ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl.exists?(id: control.id)
        }.from(true).to(false)
      end
    end

    context 'when current_user is not namespace owner' do
      it_behaves_like 'a mutation that returns top-level errors',
        errors: [Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR]

      it 'does not destroy a compliance requirement control' do
        expect { mutate }
          .not_to change { ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl.count }
      end
    end
  end
end
