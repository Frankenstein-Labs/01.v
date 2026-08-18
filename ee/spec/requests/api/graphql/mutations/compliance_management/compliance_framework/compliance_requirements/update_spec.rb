# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update a compliance requirement', feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:namespace) { create(:group) }
  let_it_be(:framework) { create(:compliance_framework, namespace: namespace) }
  let_it_be(:requirement) do
    create(:compliance_requirement, framework: framework)
  end

  let_it_be(:owner) { create(:user) }
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:developer) { create(:user) }
  let_it_be(:guest) { create(:user) }

  let(:controls) do
    [
      {
        name: 'minimum_approvals_required_2',
        expression: { operator: ">=", field: "minimum_approvals_required", value: 2 }.to_json,
        control_type: 'internal'
      },
      {
        name: 'scanner_sast_running',
        expression: { operator: "=", field: "scanner_sast_running", value: true }.to_json,
        control_type: 'internal'
      },
      {
        name: 'default_branch_protected',
        expression: { operator: "=", field: "default_branch_protected", value: true }.to_json,
        control_type: 'internal'
      },
      {
        name: 'external_control',
        control_type: 'external',
        external_url: "https://external.test",
        secret_token: 'token123'
      }
    ]
  end

  let(:mutation) do
    graphql_mutation(:update_compliance_requirement,
      id: global_id_of(requirement),
      params: mutation_params,
      controls: controls
    )
  end

  let(:mutation_params) do
    {
      name: 'New Name',
      description: 'New Description'
    }
  end

  subject(:mutate) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    stub_licensed_features(custom_compliance_frameworks: true, evaluate_group_level_compliance_pipeline: true)

    create(:compliance_requirements_control, compliance_requirement: requirement)
    create(:compliance_requirements_control, :project_visibility_not_internal, compliance_requirement: requirement)
  end

  def mutation_response
    graphql_mutation_response(:update_compliance_requirement)
  end

  shared_examples 'a mutation that updates a compliance requirement' do
    it 'updates the requirement' do
      expect { mutate }.to change { requirement.reload.name }.to('New Name')
                                                             .and change {
                                                               requirement.reload.description
                                                             }.to('New Description')
    end

    it 'returns the updated requirement', :aggregate_failures do
      mutate

      expect(mutation_response['requirement']['name']).to eq 'New Name'
      expect(mutation_response['requirement']['description']).to eq 'New Description'
    end

    it 'returns an empty array of errors' do
      mutate

      expect(mutation_response['errors']).to be_empty
    end
  end

  shared_examples 'a mutation that returns unauthorized error' do
    it 'does not update the compliance requirement' do
      expect { mutate }.not_to change { requirement.reload.attributes }
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
    before_all do
      namespace.add_owner(owner)
      namespace.add_maintainer(maintainer)
      namespace.add_developer(developer)
      namespace.add_guest(guest)
    end

    context 'when current_user is group owner' do
      let(:current_user) { owner }

      it_behaves_like 'authorizing granular token permissions for GraphQL', :update_compliance_requirement do
        let(:user) { current_user }
        let(:boundary_object) { namespace }
        let(:mutation) do
          graphql_mutation(
            :update_compliance_requirement,
            {
              id: global_id_of(requirement),
              params: mutation_params,
              controls: controls
            },
            'errors'
          )
        end

        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end

      context 'with valid params' do
        context 'when controls are also passed' do
          it_behaves_like 'a mutation that updates a compliance requirement'

          it 'adds new compliance controls' do
            mutate

            requirement_controls = requirement.compliance_requirements_controls.order(id: :asc)

            expect(requirement_controls.count).to eq(controls.count)
            controls.each do |expected_control|
              control = requirement_controls.find { |c| c.name == expected_control[:name] }
              expect(control).to have_attributes(
                name: expected_control[:name],
                expression: expected_control[:expression],
                control_type: expected_control[:control_type],
                external_url: expected_control[:external_url],
                secret_token: expected_control[:secret_token]
              )
            end
          end
        end

        context 'when controls param is missing' do
          let(:mutation) do
            graphql_mutation(:update_compliance_requirement,
              id: global_id_of(requirement),
              params: mutation_params
            )
          end

          it_behaves_like 'a mutation that updates a compliance requirement'

          it 'does not update existing controls' do
            expect { mutate }.not_to change { requirement.compliance_requirements_controls.to_a }
          end
        end

        context 'when controls param is an empty array' do
          let(:controls) { [] }

          it_behaves_like 'a mutation that updates a compliance requirement'

          it 'deletes all control entries for the requirement' do
            expect { mutate }.to change { requirement.compliance_requirements_controls.count }.from(2).to(0)
          end
        end
      end

      context 'with invalid params' do
        context 'with invalid name' do
          let(:mutation_params) do
            {
              name: '',
              description: ''
            }
          end

          it 'returns an array of errors' do
            mutate

            expect(mutation_response['errors']).to contain_exactly "Description can't be blank", "Name can't be blank",
              "Failed to update compliance requirement"
          end

          it 'does not update the requirement' do
            expect { mutate }.to not_change { requirement.reload.attributes }
          end
        end

        context 'with invalid controls param' do
          let(:controls) do
            [
              {
                name: "minimum_approvals_required_2",
                expression: { operator: "<=", field: "minimum_approvals_required", value: "invalid_number" }.to_json,
                control_type: 'internal'
              }
            ]
          end

          it 'returns an array of errors' do
            mutate

            expect(mutation_response['errors'])
              .to contain_exactly(
                "Failed to add compliance requirement control minimum_approvals_required_2: " \
                  "Validation failed: Expression property '/value' is not of type: number"
              )
          end

          it 'does not update the requirement' do
            expect { mutate }.to not_change { requirement.reload.attributes }
          end
        end
      end
    end

    context 'when current_user is a maintainer' do
      let(:current_user) { maintainer }

      it_behaves_like 'a mutation that returns unauthorized error'
    end

    context 'when current_user is a developer' do
      let(:current_user) { developer }

      it_behaves_like 'a mutation that returns unauthorized error'
    end

    context 'when current_user is a guest' do
      let(:current_user) { guest }

      it_behaves_like 'a mutation that returns unauthorized error'
    end
  end
end
