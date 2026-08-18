# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ComplianceRequirements::UpdateService,
  feature_category: :compliance_management do
  let_it_be_with_refind(:namespace) { create(:group) }
  let_it_be_with_refind(:framework) { create(:compliance_framework, namespace: namespace) }
  let_it_be_with_refind(:requirement) do
    create(:compliance_requirement, framework: framework)
  end

  let_it_be(:owner) { create(:user, owner_of: namespace) }
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:developer) { create(:user) }
  let_it_be(:guest) { create(:user) }
  let_it_be(:non_member) { create(:user) }

  let(:params) { { description: 'New Description', name: 'New Name' } }

  before_all do
    namespace.add_maintainer(maintainer)
    namespace.add_developer(developer)
    namespace.add_guest(guest)
  end

  shared_examples 'unsuccessful update' do |error_message|
    it 'does not update the compliance requirement' do
      expect { service.execute }.not_to change { requirement.reload.attributes }
    end

    it 'is unsuccessful' do
      result = service.execute

      expect(result.success?).to be false
      expect(result.message).to eq _(error_message)
    end

    it 'does not audit the changes' do
      service.execute

      expect(::Gitlab::Audit::Auditor).not_to have_received(:audit)
    end
  end

  shared_examples 'do not enqueue project compliance evaluation for framework' do
    it 'does not enqueue projects compliance evaluation for the framework' do
      expect(ComplianceManagement::ComplianceFramework::ProjectsComplianceEnqueueWorker)
        .not_to receive(:perform_async)
    end
  end

  context 'when feature is disabled' do
    before do
      stub_licensed_features(custom_compliance_frameworks: false)
      allow(::Gitlab::Audit::Auditor).to receive(:audit)
    end

    context 'when current user is namespace owner' do
      subject(:service) do
        described_class.new(requirement: requirement, current_user: owner, params: params, controls: nil)
      end

      it_behaves_like 'unsuccessful update', 'Not permitted to update requirement'
    end

    context 'when current user is maintainer' do
      subject(:service) do
        described_class.new(requirement: requirement, current_user: maintainer, params: params, controls: nil)
      end

      it_behaves_like 'unsuccessful update', 'Not permitted to update requirement'
    end

    context 'when current user is developer' do
      subject(:service) do
        described_class.new(requirement: requirement, current_user: developer, params: params, controls: nil)
      end

      it_behaves_like 'unsuccessful update', 'Not permitted to update requirement'
    end

    context 'when current user is guest' do
      subject(:service) do
        described_class.new(requirement: requirement, current_user: guest, params: params, controls: nil)
      end

      it_behaves_like 'unsuccessful update', 'Not permitted to update requirement'
    end

    context 'when current user is non-member' do
      subject(:service) do
        described_class.new(requirement: requirement, current_user: non_member, params: params, controls: nil)
      end

      it_behaves_like 'unsuccessful update', 'Not permitted to update requirement'
    end
  end

  context 'when feature is enabled' do
    before do
      stub_licensed_features(custom_compliance_frameworks: true)
      allow(::Gitlab::Audit::Auditor).to receive(:audit)
    end

    context 'when current user is namespace owner' do
      let(:controls) { nil }
      let_it_be(:external_control) do
        create(:compliance_requirements_control, :external, compliance_requirement: requirement)
      end

      let_it_be_with_refind(:other_requirement) do
        create(:compliance_requirement, framework: framework, name: 'other_requirement')
      end

      subject(:service) do
        described_class.new(requirement: requirement, current_user: owner, params: params, controls: controls)
      end

      before do
        create(:compliance_requirements_control, compliance_requirement: requirement)
        create(:compliance_requirements_control, :project_visibility_not_internal, compliance_requirement: requirement)

        create(:compliance_requirements_control, compliance_requirement: other_requirement)
      end

      context 'with valid params' do
        shared_examples 'updates requirement' do
          it 'updates the compliance requirement' do
            expect { service.execute }.to change { requirement.reload.name }.to('New Name')
                                                                            .and change {
                                                                              requirement.reload.description
                                                                            }.to('New Description')
          end
        end

        it_behaves_like 'updates requirement'

        it 'is successful' do
          result = service.execute

          expect(result.success?).to be true
          expect(result.payload[:requirement]).to eq(requirement)
        end

        it 'audits the changes' do
          old_values = {
            name: requirement.name,
            description: requirement.description
          }

          new_values = {
            name: 'New Name',
            description: 'New Description'
          }

          service.execute

          expect(::Gitlab::Audit::Auditor).to have_received(:audit).exactly(2).times

          old_values.each do |attribute, old_value|
            expect(::Gitlab::Audit::Auditor).to have_received(:audit).with(
              name: 'update_compliance_requirement',
              author: owner,
              scope: requirement.framework.namespace,
              target: requirement,
              message: "Changed compliance requirement's #{attribute} from #{old_value} to #{new_values[attribute]}"
            )
          end
        end

        context 'with nil controls param' do
          it_behaves_like 'updates requirement'

          it 'does not update existing control entries' do
            expect { service.execute }.not_to change { requirement.compliance_requirements_controls.to_a }
          end

          it_behaves_like 'do not enqueue project compliance evaluation for framework'
        end

        context 'with empty controls array param' do
          let(:controls) { [] }

          it_behaves_like 'updates requirement'

          it 'deletes all control entries for the requirement' do
            expect { service.execute }.to change { requirement.compliance_requirements_controls.count }.from(3).to(0)
          end

          it 'does not delete controls of other requirements' do
            expect { service.execute }.not_to change { other_requirement.compliance_requirements_controls.to_a }
          end

          it_behaves_like 'do not enqueue project compliance evaluation for framework'
        end

        context 'with controls that need update, delete, and add operations' do
          let(:controls) do
            [
              {
                name: 'scanner_sast_running',
                expression: { operator: "=", field: "scanner_sast_running", value: true }.to_json,
                control_type: 'internal'
              },
              {
                name: 'project_visibility_not_internal',
                expression: { operator: "=", field: "project_visibility_not_internal", value: true }.to_json,
                control_type: 'internal'
              },
              {
                name: 'default_branch_protected',
                expression: { operator: "=", field: "default_branch_protected", value: true }.to_json,
                control_type: 'internal'
              },
              {
                name: 'auth_sso_enabled',
                expression: { operator: "=", field: "auth_sso_enabled", value: true }.to_json,
                control_type: 'internal'
              }
            ]
          end

          it_behaves_like 'updates requirement'

          it 'correctly handles mixed update operations' do
            expect(requirement.compliance_requirements_controls.count).to eq(3)

            service.execute

            requirement_controls = requirement.compliance_requirements_controls.reload
            expect(requirement_controls.count).to eq(4)

            controls.each do |control_params|
              matching_control = requirement_controls.find { |control| control.name == control_params[:name] }

              expect(matching_control).to be_present
              expect(matching_control).to have_attributes(
                name: control_params[:name],
                expression: control_params[:expression],
                control_type: control_params[:control_type],
                external_control_name: control_params[:external_control_name],
                external_url: control_params[:external_url],
                secret_token: control_params[:secret_token]
              )
            end

            expect(requirement_controls.where(control_type: 'external').count).to eq(0)
          end

          it 'enqueues project framework evaluation for the framework' do
            expect(ComplianceManagement::ComplianceFramework::ProjectsComplianceEnqueueWorker)
              .to receive(:perform_async).with(framework.id).once

            service.execute
          end
        end

        context 'with external control matching by URL' do
          let(:external_url) { "http://external.test" }
          let(:controls) do
            [
              {
                name: 'external_control',
                control_type: 'external',
                external_control_name: 'new_external_name',
                external_url: external_url,
                secret_token: 'updated_token'
              }
            ]
          end

          before do
            external_control = requirement.compliance_requirements_controls.find_by(control_type: 'external')
            external_control.update!(external_url: external_url)
          end

          it 'matches and updates external control by URL' do
            expect { service.execute }.to change { requirement.compliance_requirements_controls.count }.from(3).to(1)

            updated_control = requirement.compliance_requirements_controls.reload.find_by(external_url: external_url)
            expect(updated_control.secret_token).to eq('updated_token')
            expect(updated_control.external_control_name).to eq('new_external_name')
          end
        end

        context 'when destroy service fails' do
          let(:controls) { [] }

          it 'returns an error response when destroy service fails' do
            service_class = ComplianceManagement::ComplianceFramework::ComplianceRequirementsControls::DestroyService
            allow_next_instance_of(service_class) do |service|
              allow(service).to receive(:execute).and_return(
                ServiceResponse.error(message: 'Destroy failed')
              )
            end

            result = service.execute

            expect(result).not_to be_success
            expect(result.message).to include("Destroy failed")
          end
        end
      end

      context 'with invalid params' do
        context 'with invalid name' do
          let(:params) { { name: '' } }

          it_behaves_like 'unsuccessful update', 'Failed to update compliance requirement'

          it 'returns validation errors' do
            result = service.execute

            expect(result.payload.full_messages).to include("Name can't be blank")
          end
        end

        context 'with invalid controls' do
          shared_examples 'invalid controls' do |error_message|
            it 'does not update the compliance requirement' do
              expect { service.execute }.not_to change { requirement.reload.attributes }
            end

            it 'responds with an error message' do
              expect(service.execute.message).to match(/#{Regexp.escape(error_message.split(':').first)}/)
            end

            it 'does not audit the compliance requirement updation' do
              expect { service.execute }
                .not_to change { AuditEventReader.where("details LIKE ?", "%update_compliance_requirement%").count }
            end
          end

          context 'when two controls have same name' do
            let_it_be(:controls) do
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

            it_behaves_like 'invalid controls', "Duplicate entries found for compliance controls for the requirement."
          end

          context 'when number of controls exceeds the allowed number' do
            before do
              constant_name = "ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl" \
                "::MAX_COMPLIANCE_CONTROLS_PER_REQUIREMENT_COUNT"
              stub_const(constant_name, 2)
            end

            let_it_be(:controls) do
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

            it_behaves_like 'invalid controls', 'More than 2 controls not allowed for a requirement.'
          end

          context 'when a new control has an invalid expression' do
            let_it_be(:controls) do
              [
                {
                  expression: { operator: ">=", field: "minimum_approvals_required", value: 2 }.to_json,
                  name: "minimum_approvals_required_2"
                },
                {
                  expression: { operator: "=", field: "project_visibility_not_internal", value: "private" }.to_json,
                  name: "project_visibility_not_internal"
                }
              ]
            end

            it_behaves_like 'invalid controls', "Control 'project_visibility_not_internal'"
          end

          context 'when a new control has invalid name' do
            let_it_be(:controls) do
              [
                {
                  expression: { operator: ">=", field: "minimum_approvals_required", value: 2 }.to_json,
                  name: "invalid_name"
                },
                {
                  expression: { operator: "=", field: "project_visibility_not_internal", value: true }.to_json,
                  name: "project_visibility_not_internal"
                }
              ]
            end

            it_behaves_like 'invalid controls', "Failed to add compliance requirement control invalid_name"
          end

          context 'when control type is unknown' do
            let_it_be(:controls) do
              [
                {
                  expression: { operator: "=", field: "project_visibility_not_internal", value: true }.to_json,
                  name: "project_visibility_not_internal",
                  control_type: "invalid"
                },
                {
                  expression: { operator: ">=", field: "minimum_approvals_required", value: 2 }.to_json,
                  name: "minimum_approvals_required_2"
                }
              ]
            end

            it_behaves_like 'invalid controls', "Control 'project_visibility_not_internal'"
          end
        end
      end
    end

    context 'when current user is maintainer' do
      subject(:service) do
        described_class.new(requirement: requirement, current_user: maintainer, params: params, controls: nil)
      end

      it_behaves_like 'unsuccessful update', 'Not permitted to update requirement'
    end

    context 'when current user is developer' do
      subject(:service) do
        described_class.new(requirement: requirement, current_user: developer, params: params, controls: nil)
      end

      it_behaves_like 'unsuccessful update', 'Not permitted to update requirement'
    end

    context 'when current user is guest' do
      subject(:service) do
        described_class.new(requirement: requirement, current_user: guest, params: params, controls: nil)
      end

      it_behaves_like 'unsuccessful update', 'Not permitted to update requirement'
    end

    context 'when current user is non-member' do
      subject(:service) do
        described_class.new(requirement: requirement, current_user: non_member, params: params, controls: nil)
      end

      it_behaves_like 'unsuccessful update', 'Not permitted to update requirement'
    end
  end
end
