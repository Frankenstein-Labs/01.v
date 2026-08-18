# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ComplianceRequirementsControls::CreateService,
  feature_category: :compliance_management do
  let_it_be_with_refind(:namespace) { create(:group) }
  let_it_be(:current_user) { create(:user, owner_of: namespace) }
  let_it_be(:requirement) do
    create(:compliance_requirement, framework: create(:compliance_framework, namespace: namespace))
  end

  let(:params) do
    {
      name: 'minimum_approvals_required_2',
      expression: control_expression
    }
  end

  context 'when custom_compliance_frameworks is disabled' do
    before do
      stub_licensed_features(custom_compliance_frameworks: false)
    end

    subject(:control_creator) do
      described_class.new(requirement: requirement, params: params, current_user: current_user)
    end

    it 'does not create a new compliance control' do
      expect { control_creator.execute }.not_to change { requirement.compliance_requirements_controls.count }
    end

    it 'responds with an error message' do
      expect(control_creator.execute.message).to eq('Not permitted to create compliance control')
    end
  end

  context 'when custom_compliance_frameworks is enabled' do
    before do
      stub_licensed_features(custom_compliance_frameworks: true)
    end

    context 'when using invalid parameters' do
      subject(:control_creator) do
        described_class.new(requirement: requirement, params: params.except(:name), current_user: current_user)
      end

      let(:response) { control_creator.execute }

      it 'responds with an error service response' do
        expect(response.success?).to be_falsey
        expect(response.payload.messages[:name]).to contain_exactly "can't be blank"
      end
    end

    context 'when creating a compliance control for a namespace that current_user is not the owner of' do
      subject(:control_creator) do
        described_class.new(requirement: requirement, params: params, current_user: create(:user))
      end

      it 'responds with an error service response' do
        expect(control_creator.execute.success?).to be false
      end

      it 'does not create a new compliance control' do
        expect { control_creator.execute }.not_to change { requirement.compliance_requirements_controls.count }
      end
    end

    context 'when using parameters for a valid compliance control' do
      subject(:control_creator) do
        described_class.new(requirement: requirement, params: params, current_user: current_user)
      end

      it 'audits the changes' do
        expect { control_creator.execute }
          .to change {
            AuditEventReader.where("details LIKE ?", "%created_compliance_requirement_control%").count
          }.by(1)
      end

      it 'creates a new compliance control' do
        expect { control_creator.execute }.to change { requirement.compliance_requirements_controls.count }.by(1)
      end

      it 'responds with a successful service response' do
        expect(control_creator.execute.success?).to be true
      end

      it 'has the expected attributes' do
        control = control_creator.execute.payload[:control]

        expect(control.attributes).to include(
          "name" => "minimum_approvals_required_2",
          "compliance_requirement_id" => requirement.id,
          "namespace_id" => namespace.id,
          "expression" => control_expression,
          "control_type" => "internal"
        )
      end

      it 'defaults ping_enabled to true when not specified' do
        control = control_creator.execute.payload[:control]

        expect(control.ping_enabled).to be(true)
      end

      context 'when ping_enabled is explicitly set to true' do
        let(:params_with_ping_enabled) { params.merge(ping_enabled: true) }

        subject(:control_creator) do
          described_class.new(requirement: requirement, params: params_with_ping_enabled, current_user: current_user)
        end

        it 'sets ping_enabled to true' do
          control = control_creator.execute.payload[:control]

          expect(control.ping_enabled).to be(true)
        end
      end

      context 'when ping_enabled is explicitly set to false' do
        let(:params_with_ping_disabled) { params.merge(ping_enabled: false) }

        subject(:control_creator) do
          described_class.new(requirement: requirement, params: params_with_ping_disabled, current_user: current_user)
        end

        it 'sets ping_enabled to false' do
          control = control_creator.execute.payload[:control]

          expect(control.ping_enabled).to be(false)
        end
      end

      context 'when using parameters for a valid external compliance control' do
        let(:external_params) do
          {
            external_control_name: 'external control',
            external_url: 'https://www.external.control.com',
            secret_token: '123456789'
          }.merge(params)
        end

        subject(:control_creator) do
          described_class.new(requirement: requirement, params: external_params, current_user: current_user)
        end

        it 'has the expected attributes' do
          control = control_creator.execute.payload[:control]

          expect(control.attributes).to include(
            "external_control_name" => "external control",
            "external_url" => "https://www.external.control.com",
            "name" => "minimum_approvals_required_2",
            "compliance_requirement_id" => requirement.id,
            "namespace_id" => namespace.id,
            "expression" => control_expression,
            "control_type" => "internal"
          )
        end

        it 'defaults ping_enabled to true for external controls' do
          control = control_creator.execute.payload[:control]

          expect(control.ping_enabled).to be(true)
        end

        context 'when ping_enabled is set to false for external control' do
          let(:external_params_ping_disabled) { external_params.merge(ping_enabled: false) }

          subject(:control_creator) do
            described_class.new(
              requirement: requirement,
              params: external_params_ping_disabled,
              current_user: current_user
            )
          end

          it 'sets ping_enabled to false' do
            control = control_creator.execute.payload[:control]

            expect(control.ping_enabled).to be(false)
          end
        end
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
