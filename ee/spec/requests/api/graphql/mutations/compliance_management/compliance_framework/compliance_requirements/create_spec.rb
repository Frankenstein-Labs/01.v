# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create a Compliance Requirement', feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:namespace) { create(:group) }
  let_it_be(:framework) { create(:compliance_framework, namespace: namespace) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:controls) do
    [
      {
        expression: "{\"operator\":\"=\",\"field\":\"project_visibility_not_internal\",\"value\":true}",
        name: "project_visibility_not_internal",
        control_type: 'internal'
      },
      {
        expression: "{\"operator\":\">=\",\"field\":\"minimum_approvals_required\",\"value\":2}",
        name: "minimum_approvals_required_2",
        control_type: 'internal'
      }
    ]
  end

  let(:mutation_params) do
    {
      name: 'Custom framework requirement',
      description: 'Example Description'
    }
  end

  let(:mutation) do
    graphql_mutation(
      :create_compliance_requirement,
      compliance_framework_id: framework.to_gid,
      params: mutation_params,
      controls: controls
    )
  end

  subject(:mutate) { post_graphql_mutation(mutation, current_user: current_user) }

  def mutation_response
    graphql_mutation_response(:create_compliance_requirement)
  end

  shared_examples 'a mutation that creates a compliance requirement' do
    it 'creates a new compliance requirement' do
      expect { mutate }.to change { framework.compliance_requirements.count }.by 1
    end

    it 'returns the newly created requirement', :aggregate_failures do
      mutate

      expect(mutation_response['requirement']['name']).to eq 'Custom framework requirement'
      expect(mutation_response['requirement']['description']).to eq 'Example Description'
    end

    it 'returns an empty array of errors' do
      mutate

      expect(mutation_response['errors']).to be_empty
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

      it_behaves_like 'authorizing granular token permissions for GraphQL', :create_compliance_requirement do
        let(:user) { current_user }
        let(:boundary_object) { namespace }
        let(:mutation) do
          graphql_mutation(
            :create_compliance_requirement,
            {
              compliance_framework_id: framework.to_gid,
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
          it_behaves_like 'a mutation that creates a compliance requirement'

          it 'creates compliance requirements controls' do
            expect { mutate }
              .to change { ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl.count }.by 2

            requirement = GlobalID::Locator.locate(mutation_response['requirement']['id'])

            requirement_controls = requirement.compliance_requirements_controls.order(id: :asc)

            requirement_controls.each_with_index do |control, i|
              expect(control).to have_attributes(
                name: controls[i][:name],
                expression: controls[i][:expression],
                control_type: controls[i][:control_type],
                external_url: controls[i][:external_url],
                secret_token: controls[i][:secret_token]
              )
            end
          end
        end

        context 'when controls param is missing' do
          let_it_be(:controls) { nil }

          it_behaves_like 'a mutation that creates a compliance requirement'

          it 'does not create controls' do
            expect { mutate }.not_to change {
              ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl.count
            }
          end
        end

        context 'when controls param is an empty array' do
          let(:controls) { [] }

          it_behaves_like 'a mutation that creates a compliance requirement'

          it 'does not create compliance requirements controls' do
            expect { mutate }
              .not_to change { ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl.count }
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
              "Failed to create compliance requirement"
          end

          it 'does not create the requirement' do
            expect { mutate }.to not_change { framework.compliance_requirements.count }
          end
        end

        context 'with invalid controls param' do
          let(:controls) do
            [
              {
                expression:
                  "{\"operator\":\">=\",\"field\":\"minimum_approvals_required\",\"value\":\"invalid_number\"}",
                name: "minimum_approvals_required_2"
              }
            ]
          end

          it 'returns an array of errors' do
            mutate

            expect(mutation_response['errors'])
              .to contain_exactly "Failed to add compliance requirement control minimum_approvals_required_2: " \
                "Validation failed: Expression property '/value' is not of type: number"
          end

          it 'does not create the requirement' do
            expect { mutate }.to not_change { framework.compliance_requirements.count }
          end
        end
      end
    end

    context 'when current_user is not a group owner' do
      context 'when current_user is group owner' do
        before_all do
          namespace.add_maintainer(current_user)
        end

        it 'does not create a new compliance requirement' do
          expect { mutate }.not_to change { framework.compliance_requirements.count }
        end

        it_behaves_like 'a mutation that returns a top-level access error'
      end
    end
  end
end
