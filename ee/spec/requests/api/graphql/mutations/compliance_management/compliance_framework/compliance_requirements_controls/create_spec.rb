# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create a Compliance Requirement Control', feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:namespace) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:requirement) do
    create(:compliance_requirement, framework: create(:compliance_framework, namespace: namespace))
  end

  let(:mutation) do
    graphql_mutation(
      :create_compliance_requirements_control,
      compliance_requirement_id: requirement.to_gid,
      params: {
        name: 'minimum_approvals_required_2',
        expression: control_expression
      }
    )
  end

  subject(:mutate) { post_graphql_mutation(mutation, current_user: current_user) }

  def mutation_response
    graphql_mutation_response(:create_compliance_requirements_control)
  end

  shared_examples 'a mutation that creates a compliance requirement control' do
    it 'creates a new compliance requirement control' do
      expect { mutate }.to change { requirement.compliance_requirements_controls.count }.by 1
    end

    it 'returns the newly created requirement control', :aggregate_failures do
      mutate

      expect(mutation_response['requirementsControl']['name']).to eq 'minimum_approvals_required_2'
      expect(mutation_response['requirementsControl']['expression']).to eq control_expression
      expect(mutation_response['requirementsControl']['controlType']).to eq 'internal'
    end
  end

  context 'when framework feature is unlicensed' do
    before do
      stub_licensed_features(custom_compliance_frameworks: false)
      post_graphql_mutation(mutation, current_user: current_user)
    end

    it_behaves_like 'a mutation that returns a top-level access error'
  end

  context 'when feature is licensed' do
    before do
      stub_licensed_features(custom_compliance_frameworks: true, evaluate_group_level_compliance_pipeline: true)
    end

    context 'when current_user is group owner' do
      before_all do
        namespace.add_owner(current_user)
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL', :create_compliance_requirements_control do
        let(:user) { current_user }
        let(:boundary_object) { namespace }
        let(:mutation) do
          graphql_mutation(
            :create_compliance_requirements_control,
            {
              compliance_requirement_id: requirement.to_gid,
              params: {
                name: 'minimum_approvals_required_2',
                expression: control_expression
              }
            },
            'errors'
          )
        end

        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end

      it_behaves_like 'a mutation that creates a compliance requirement control'

      context "when creating an external control" do
        let(:mutation) do
          graphql_mutation(
            :create_compliance_requirements_control,
            compliance_requirement_id: requirement.to_gid,
            params: {
              name: 'external_control',
              control_type: 'external',
              external_control_name: 'external_name',
              external_url: 'https://example.com',
              secret_token: 'secret_token',
              expression: ""
            }
          )
        end

        subject(:mutate) { post_graphql_mutation(mutation, current_user: current_user) }

        it 'creates a new external compliance requirement control', :aggregate_failures do
          expect { mutate }.to change { requirement.compliance_requirements_controls.count }.by(1)

          control = requirement.compliance_requirements_controls.last
          expect(control.name).to eq('external_control')
          expect(control.control_type).to eq('external')
          expect(control.external_control_name).to eq('external_name')
          expect(control.external_url).to eq('https://example.com')
          expect(control.secret_token).to eq('secret_token')
          expect(control.expression).to be_empty
        end

        it 'returns the correct response', :aggregate_failures do
          mutate

          expect(mutation_response['requirementsControl']['name']).to eq('external_control')
          expect(mutation_response['requirementsControl']['controlType']).to eq('external')
          expect(mutation_response['requirementsControl']['externalControlName']).to eq('external_name')
          expect(mutation_response['requirementsControl']['externalUrl']).to eq('https://example.com')
          expect(mutation_response['requirementsControl']['expression']).to be_empty
          expect(mutation_response['requirementsControl']['secretToken']).to be_nil
          expect(mutation_response['requirementsControl'].keys).not_to include('secretToken')
        end
      end
    end

    context 'when current_user is not a group owner' do
      context 'when current_user is group owner' do
        before_all do
          namespace.add_maintainer(current_user)
        end

        it 'does not create a new compliance requirement control' do
          expect { mutate }.not_to change { requirement.compliance_requirements_controls.count }
        end

        it_behaves_like 'a mutation that returns a top-level access error'
      end
    end
  end

  def control_expression
    {
      operator: ">=",
      field: "minimum_approvals_required",
      value: 2
    }.to_json
  end
end
