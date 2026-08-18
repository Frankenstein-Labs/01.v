# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update a compliance requirement control', feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:namespace) { create(:group) }
  let_it_be(:requirement) do
    create(:compliance_requirement, framework: create(:compliance_framework, namespace: namespace))
  end

  let_it_be(:control) { create(:compliance_requirements_control, compliance_requirement: requirement) }

  let_it_be(:owner) { create(:user) }
  let_it_be(:maintainer) { create(:user) }

  let(:mutation) do
    graphql_mutation(:update_compliance_requirements_control, { id: global_id_of(control), **mutation_params })
  end

  let_it_be(:control_expression) do
    {
      operator: '=',
      field: 'project_visibility_not_internal',
      value: true
    }.to_json
  end

  let(:mutation_params) do
    {
      params: {
        name: 'project_visibility_not_internal',
        expression: control_expression
      }
    }
  end

  subject(:mutate) { post_graphql_mutation(mutation, current_user: current_user) }

  def mutation_response
    graphql_mutation_response(:update_compliance_requirements_control)
  end

  shared_examples 'a mutation that updates a compliance requirement control' do
    it 'updates the requirement control' do
      expect { mutate }.to change { control.reload.name }.to('project_visibility_not_internal')
                                                         .and change {
                                                           control.reload.expression
                                                         }.to(control_expression)
    end

    it 'returns the updated requirement control', :aggregate_failures do
      mutate

      expect(mutation_response['requirementsControl']['name']).to eq 'project_visibility_not_internal'
      expect(mutation_response['requirementsControl']['expression']).to eq control_expression
    end

    it 'returns an empty array of errors' do
      mutate

      expect(mutation_response['errors']).to be_empty
    end
  end

  shared_examples 'a mutation that returns unauthorized error' do
    it 'does not update the compliance requirement control' do
      expect { mutate }.not_to change { control.reload.attributes }
    end

    it_behaves_like 'a mutation that returns top-level errors',
      errors: [Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR]
  end

  context 'when framework feature is unlicensed' do
    let(:current_user) { owner }

    before do
      stub_licensed_features(custom_compliance_frameworks: false)
    end

    it_behaves_like 'a mutation that returns top-level errors',
      errors: [Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR]
  end

  context 'when feature is licensed' do
    before do
      stub_licensed_features(custom_compliance_frameworks: true)
    end

    before_all do
      namespace.add_owner(owner)
      namespace.add_maintainer(maintainer)
    end

    context 'when current_user is group owner' do
      let(:current_user) { owner }

      it_behaves_like 'authorizing granular token permissions for GraphQL', :update_compliance_requirements_control do
        let(:user) { current_user }
        let(:boundary_object) { namespace }
        let(:mutation) do
          graphql_mutation(:update_compliance_requirements_control, { id: global_id_of(control), **mutation_params },
            'errors')
        end

        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end

      it_behaves_like 'a mutation that updates a compliance requirement control'

      context 'with invalid params' do
        let(:mutation_params) do
          {
            params: {
              name: 'invalid_name',
              expression: 'invalid_expression'
            }
          }
        end

        it 'returns an array of errors' do
          mutate

          expect(mutation_response['errors']).to contain_exactly(
            _("Failed to update compliance requirement control. " \
              "Error: 'invalid_name' is not a valid name")
          )
        end

        it 'does not update the requirement control' do
          expect { mutate }.to not_change { control.reload.attributes }
        end
      end

      context "when updating an external control" do
        let(:mutation_params) do
          {
            params: {
              name: 'external_control',
              control_type: 'external',
              external_control_name: 'external_name',
              external_url: 'https://example.com',
              secret_token: 'secret_token',
              expression: ""
            }
          }
        end

        it 'updates the requirement control' do
          expect { mutate }.to change { control.reload.control_type }.to('external').and change {
            control.reload.external_url
          }.to('https://example.com')
          .and change {
            control.reload.secret_token
          }.to('secret_token')
          .and change {
            control.reload.external_control_name
          }.to('external_name')
        end

        it 'returns the updated requirement control', :aggregate_failures do
          mutate

          expect(mutation_response['requirementsControl']['name']).to eq 'external_control'
          expect(mutation_response['requirementsControl']['expression']).to be_empty
          expect(mutation_response['requirementsControl']['controlType']).to eq 'external'
          expect(mutation_response['requirementsControl']['externalControlName']).to eq 'external_name'
          expect(mutation_response['requirementsControl']['externalUrl']).to eq 'https://example.com'
          expect(mutation_response['requirementsControl']['secretToken']).to be_nil
        end

        it 'returns an empty array of errors' do
          mutate

          expect(mutation_response['errors']).to be_empty
        end
      end
    end

    context 'when current_user is a maintainer' do
      let(:current_user) { maintainer }

      it_behaves_like 'a mutation that returns unauthorized error'
    end
  end
end
