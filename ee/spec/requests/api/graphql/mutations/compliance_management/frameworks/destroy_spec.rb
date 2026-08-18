# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Delete a compliance framework', feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:namespace) { create(:group) }
  let_it_be(:framework) { create(:compliance_framework, namespace: namespace) }

  let(:current_user) { create(:user) }
  let(:mutation) { graphql_mutation(:destroy_compliance_framework, { id: global_id_of(framework) }) }

  subject { post_graphql_mutation(mutation, current_user: current_user) }

  def mutation_response
    graphql_mutation_response(:destroy_compliance_framework)
  end

  context 'feature is unlicensed' do
    before do
      stub_licensed_features(custom_compliance_frameworks: false)
    end

    it 'does not destroy a compliance framework' do
      expect { subject }.not_to change { ComplianceManagement::Framework.count }
    end

    it_behaves_like 'a mutation that returns top-level errors',
      errors: [Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR]
  end

  context 'when licensed' do
    before do
      stub_licensed_features(custom_compliance_frameworks: true)
    end

    context 'current_user is namespace owner' do
      before do
        namespace.add_owner(current_user)
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL', :delete_compliance_framework do
        let(:user) { current_user }
        let(:boundary_object) { namespace }
        let(:mutation) do
          graphql_mutation(:destroy_compliance_framework, { id: global_id_of(framework) }, 'errors')
        end

        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end

      it 'has no errors' do
        subject

        expect(mutation_response['errors']).to be_empty
      end

      it 'destroys a compliance framework' do
        expect { subject }.to change { ComplianceManagement::Framework.count }.by(-1)
      end

      context 'when the framework is referenced by a security policy' do
        before do
          create(:compliance_framework_security_policy, framework: framework)
        end

        it 'does not destroy the framework and returns the linked-policy error', :aggregate_failures do
          expect { subject }.not_to change { ComplianceManagement::Framework.count }

          expect(mutation_response['errors']).to contain_exactly(
            'Cannot delete the compliance framework because it is referenced by a security policy. ' \
              'Remove it from the policy scope first.'
          )
        end
      end
    end

    context 'current_user is not namespace owner' do
      it_behaves_like 'a mutation that returns top-level errors',
        errors: [Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR]

      it 'does not destroy a compliance framework' do
        expect { subject }.not_to change { ComplianceManagement::Framework.count }
      end
    end
  end
end
