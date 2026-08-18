# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Frameworks::JsonImportService, feature_category: :compliance_management do
  let(:json_payload) do
    ::Gitlab::Json.parse(
      <<~JSON
        {
          "name": "SOC 2",
          "description": "SOC 2 Template",
          "color": "#808080",
          "requirements": [
            {
              "name": "CC1.1.1 - Control Environment - Integrity and Ethical Values",
              "description": "The organization demonstrates a commitment to integrity and ethical values",
              "controls": [
                {
                  "name": "minimum_approvals_required_2",
                  "control_type": "internal",
                  "expression": {
                    "operator": ">=",
                    "field": "minimum_approvals_required",
                    "value": 2
                  }
                }
              ]
            },
            {
              "name": "CC1.1.2 - Control Environment - Integrity and Ethical Values",
              "description": "Established standards of conduct are communicated and enforced",
              "controls": []
            }
          ]
        }
      JSON
    )
  end

  let_it_be(:group) { create :group, name: 'parent' }

  let_it_be(:user) { create(:user) }

  before do
    stub_licensed_features(custom_compliance_frameworks: true)
  end

  before_all do
    group.add_owner(user)
  end

  describe "#execute" do
    context "when using invalid parameters" do
      subject(:service) { described_class.new(user: user, group: group, json_payload: "hello world") }

      it "returns an error" do
        expect(service.execute.error?).to be true
      end

      it "returns 'invalid json' error" do
        expect(service.execute.message).to include("invalid json")
      end
    end

    context "when the user does not have permissions" do
      let(:stranger) { create :user }

      subject(:service) { described_class.new(user: stranger, group: group, json_payload: json_payload) }

      it "returns an error" do
        expect(service.execute.error?).to be true
      end

      it "returns Access denied error" do
        expect(service.execute.message).to include("Not permitted to create framework")
      end
    end

    context "when there is an error creating a framework" do
      subject(:service) { described_class.new(user: user, group: group, json_payload: json_payload) }

      before do
        error_response = ServiceResponse.error(message: _('Failed to create framework'), payload: ["didn't work"])

        allow_next_instance_of(ComplianceManagement::Frameworks::CreateService) do |service|
          allow(service).to receive(:execute).and_return(error_response)
        end
      end

      it "returns the error" do
        expect(service.execute.error?).to be true
      end

      it "tells the user what went wrong" do
        expect(service.execute.message).to include("Failed to create framework")
      end
    end

    context 'when using parameters for a valid compliance framework' do
      subject(:service) { described_class.new(user: user, group: group, json_payload: json_payload) }

      it 'creates a new compliance framework' do
        expect { service.execute }.to change { ComplianceManagement::Framework.count }.by(1)
      end

      it 'has the expected attributes' do
        framework = service.execute.payload[:framework]

        expect(framework.name).to eq('SOC 2')
        expect(framework.description).to eq('SOC 2 Template')
        expect(framework.color).to eq('#808080')
      end

      context 'when template_id and template_version are present' do
        before do
          json_payload['template_id'] = 'soc2'
          json_payload['template_version'] = 1
        end

        it 'passes template fields to the framework' do
          framework = service.execute.payload[:framework]

          expect(framework.template_id).to eq('soc2')
          expect(framework.template_version).to eq(1)
        end
      end

      context 'when requirements are empty' do
        it 'skips creating requirments' do
          json_payload["requirements"] = nil

          expect { service.execute }.not_to change {
            ComplianceManagement::ComplianceFramework::ComplianceRequirement.count
          }
        end
      end

      it 'creates the requirements' do
        expect { service.execute }.to change {
          ComplianceManagement::ComplianceFramework::ComplianceRequirement.count
        }.by(2)
      end

      it 'creates the requirements with the expected attributes' do
        framework = service.execute.payload[:framework]
        requirement = framework.compliance_requirements.first

        expect(requirement.attributes).to include(
          "name" => "CC1.1.1 - Control Environment - Integrity and Ethical Values",
          "description" => "The organization demonstrates a commitment to integrity and ethical values"
        )

        requirement = framework.compliance_requirements.last

        expect(requirement.attributes).to include(
          "name" => "CC1.1.2 - Control Environment - Integrity and Ethical Values",
          "description" => "Established standards of conduct are communicated and enforced"
        )
      end

      context 'when controls are empty' do
        it 'skips creating controls' do
          json_payload["requirements"].first["controls"] = nil

          expect { service.execute }.not_to change {
            ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl.count
          }
        end
      end

      it 'creates the controls' do
        expect { service.execute }.to change {
          ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl.count
        }.by(1)
      end

      it 'creates the control with the expected attributes' do
        control = service.execute.payload[:framework]
        .compliance_requirements.first.compliance_requirements_controls.first

        expect(control.attributes).to include(
          "name" => 'minimum_approvals_required_2',
          "control_type" => 'internal',
          "expression" => {
            "operator" => ">=",
            "field" => "minimum_approvals_required",
            "value" => 2
          }.to_json
        )
      end

      it 'responds with a successful service response' do
        expect(service.execute.success?).to be true
      end
    end

    context 'when using valid framework parameters with invalid controls' do
      subject(:service) { described_class.new(user: user, group: group, json_payload: json_payload) }

      it 'bubbles up the errors' do
        json_payload["requirements"].first["controls"].first["expression"] = "this is invalid"
        json_payload["requirements"].first["controls"] << { name: "hello world" }

        json_payload["requirements"] << { name: nil }

        result = service.execute.message

        expect(result).to match(/Name can't be blank/)
      end
    end

    context 'when using valid framework parameters with invalid requirements' do
      subject(:service) { described_class.new(user: user, group: group, json_payload: json_payload) }

      it 'bubbles up the errors' do
        json_payload["requirements"].first["controls"].first["expression"] = "this is invalid"
        json_payload["requirements"].first["controls"] << { name: "hello world" }

        result = service.execute
        message = result.message
        framework = result.payload[:framework]

        expect(message).to match(/Expression should be a valid json object/)
        expect(message).to match(/'hello world' is not a valid name/)

        expect(framework.name).to eq('SOC 2')
        expect(framework.description).to eq('SOC 2 Template')
        expect(framework.color).to eq('#808080')
      end
    end
  end
end
