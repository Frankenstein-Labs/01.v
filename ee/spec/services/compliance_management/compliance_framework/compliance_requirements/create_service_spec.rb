# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ComplianceRequirements::CreateService,
  feature_category: :compliance_management do
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_refind(:namespace) { create(:group) }
  let_it_be(:current_user) { create(:user, owner_of: namespace) }
  let_it_be(:framework) { create(:compliance_framework, namespace: namespace) }
  let_it_be(:controls) do
    [
      {
        expression: { operator: "=", field: "project_visibility_not_internal", value: true }.to_json,
        name: "project_visibility_not_internal"
      },
      {
        expression: "{\"operator\":\">=\",\"field\":\"minimum_approvals_required\",\"value\":2}",
        name: "minimum_approvals_required_2"
      },
      {
        name: "external_control",
        external_control_name: 'external_name',
        external_url: 'https://www.compliance-url.com',
        secret_token: 'token123',
        control_type: "external"
      }
    ]
  end

  let(:params) do
    {
      name: 'Custom framework requirement',
      description: 'Description about the requirement'
    }
  end

  subject(:requirement_creator_response) do
    described_class.new(framework: framework, params: params, current_user: current_user, controls: controls).execute
  end

  context 'when custom_compliance_frameworks is disabled' do
    before do
      stub_licensed_features(custom_compliance_frameworks: false)
    end

    it 'does not create a new compliance requirement' do
      expect { requirement_creator_response }.not_to change { framework.compliance_requirements.count }
    end

    it 'responds with an error message' do
      expect(requirement_creator_response.message).to eq('Not permitted to create requirement')
    end
  end

  context 'when custom_compliance_frameworks is enabled' do
    before do
      stub_licensed_features(custom_compliance_frameworks: true)
    end

    context 'when using invalid parameters' do
      context 'when name is missing' do
        let(:params) do
          {
            description: 'Description about the requirement'
          }
        end

        it 'responds with an error service response' do
          expect(requirement_creator_response.success?).to be_falsey
          expect(requirement_creator_response.payload.messages[:name]).to contain_exactly "can't be blank"
        end
      end

      context 'when one of the controls is invalid' do
        context 'when the expression is invalid' do
          let(:controls) do
            [
              {
                expression: "{\"operator\":\">=\",\"field\":\"minimum_approvals_required\",\"value\":2}",
                name: "minimum_approvals_required_2"
              },
              {
                expression: { operator: "=", field: "project_visibility_not_internal", value: "invalid_value" }.to_json,
                name: "project_visibility_not_internal"
              }
            ]
          end

          it 'responds with an error message matching the field validation pattern' do
            expect(requirement_creator_response.message)
              .to match(%r{project_visibility_not_internal.*Expression property '/value'})
          end
        end

        context 'when the control type is unknown' do
          let(:controls) do
            [
              {
                expression: { operator: "=", field: "project_visibility_not_internal", value: true }.to_json,
                name: "project_visibility_not_internal",
                control_type: "invalid"
              },
              {
                expression: "{\"operator\":\">=\",\"field\":\"minimum_approvals_required\",\"value\":2}",
                name: "minimum_approvals_required_2"
              }
            ]
          end

          it 'responds with an error message' do
            expect(requirement_creator_response.message)
              .to include("Failed to add compliance requirement control project_visibility_not_internal: " \
                "'invalid' is not a valid control_type")
          end
        end
      end

      context 'when two controls have same name' do
        let(:controls) do
          [
            {
              expression: { operator: ">=", field: "minimum_approvals_required", value: 2 }.to_json,
              name: "minimum_approvals_required_2"
            },
            {
              expression: { operator: ">=", field: "minimum_approvals_required", value: 2 }.to_json,
              name: "minimum_approvals_required_2"
            }
          ]
        end

        it 'responds with an error message' do
          expect(requirement_creator_response.message).to include(
            "Duplicate entries found for compliance controls for the requirement."
          )
        end
      end

      context 'when number of controls exceeds the allowed number' do
        before do
          constant_name = "ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl" \
            "::MAX_COMPLIANCE_CONTROLS_PER_REQUIREMENT_COUNT"
          stub_const(constant_name, 2)
        end

        let(:controls) do
          [
            {
              expression: { operator: ">=", field: "minimum_approvals_required", value: 2 }.to_json,
              name: "minimum_approvals_required_2"
            },
            {
              expression: { operator: "=", field: "project_visibility_not_internal", value: true }.to_json,
              name: "project_visibility_not_internal"
            },
            {
              expression: { operator: "=", field: "scanner_sast_running", value: true }.to_json,
              name: "scanner_sast_running"
            }
          ]
        end

        it 'does not create a new compliance requirement' do
          expect { requirement_creator_response }.not_to change { framework.compliance_requirements.count }
        end

        it 'responds with an error message' do
          expect(requirement_creator_response.message).to eq('More than 2 controls not allowed for a requirement.')
        end

        it 'does not audit the compliance requirement creation' do
          expect { requirement_creator_response }
            .not_to change { AuditEventReader.where("details LIKE ?", "%created_compliance_requirement%").count }
        end
      end
    end

    context 'when creating a compliance requirement for a namespace that current_user is not the owner of' do
      let_it_be(:current_user) { create(:user) }

      it 'responds with an error service response' do
        expect(requirement_creator_response.success?).to be false
      end

      it 'does not create a new compliance requirement' do
        expect { requirement_creator_response }.not_to change { framework.compliance_requirements.count }
      end
    end

    context 'when using parameters for a valid compliance requirement' do
      it 'audits the changes' do
        expect { requirement_creator_response }
          .to change { AuditEventReader.where("details LIKE ?", "%created_compliance_requirement%").count }.by(1)
      end

      it 'creates a new compliance requirement' do
        expect { requirement_creator_response }.to change { framework.compliance_requirements.count }.by(1)
      end

      it 'responds with a successful service response' do
        expect(requirement_creator_response.success?).to be true
      end

      it 'has the expected attributes' do
        requirement = requirement_creator_response.payload[:requirement]

        expect(requirement.attributes).to include(
          "name" => "Custom framework requirement",
          "description" => "Description about the requirement",
          "framework_id" => framework.id,
          "namespace_id" => namespace.id
        )
      end

      it 'creates a requirement control for each control provided' do
        requirement = requirement_creator_response.payload[:requirement]
        compliance_requirements_controls = requirement.compliance_requirements_controls

        expect(compliance_requirements_controls.count).to eq(3)

        compliance_requirements_controls.first(2).each_with_index do |control, index|
          expect(control.name).to eq(controls[index][:name])
          expect(control.expression).to eq(controls[index][:expression])
          expect(control.control_type).to eq('internal')
        end

        compliance_requirements_controls.last.tap do |external_control|
          expect(external_control.external_control_name).to eq "external_name"
          expect(external_control.external_url).to eq "https://www.compliance-url.com"
          expect(external_control.secret_token).to eq('token123')
          expect(external_control.control_type).to eq("external")
          expect(external_control.ping_enabled).to be true
        end
      end

      context 'when a control specifies ping_enabled' do
        where(:ping_enabled_param, :persisted_ping_enabled) do
          false | false
          nil   | true
        end

        with_them do
          let(:controls) do
            [
              {
                name: "external_control",
                external_control_name: 'external_name',
                external_url: 'https://www.compliance-url.com',
                secret_token: 'token123',
                control_type: "external",
                ping_enabled: ping_enabled_param
              }
            ]
          end

          it 'creates the control with the expected ping_enabled value' do
            requirement = requirement_creator_response.payload[:requirement]

            expect(requirement.compliance_requirements_controls.sole.ping_enabled).to be(persisted_ping_enabled)
          end
        end
      end

      it 'enqueues project framework evaluation for the framework' do
        expect(ComplianceManagement::ComplianceFramework::ProjectsComplianceEnqueueWorker)
          .to receive(:perform_async).with(framework.id).once

        requirement_creator_response
      end

      shared_examples 'creates requirement without controls' do |controls_value|
        let(:controls) { controls_value }

        it 'creates a new compliance requirement' do
          expect { requirement_creator_response }.to change { framework.compliance_requirements.count }.by(1)
        end

        it 'responds with a successful service response' do
          expect(requirement_creator_response.success?).to be true
        end

        it 'does not change the compliance requirement controls count' do
          expect { requirement_creator_response }.not_to change {
            ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl.count
          }
        end

        it 'does not enqueue projects compliance evaluation for the framework' do
          expect(ComplianceManagement::ComplianceFramework::ProjectsComplianceEnqueueWorker)
            .not_to receive(:perform_async)
        end
      end

      context 'when controls is empty' do
        include_examples 'creates requirement without controls', []
      end

      context 'when controls is nil' do
        include_examples 'creates requirement without controls', nil
      end
    end
  end
end
