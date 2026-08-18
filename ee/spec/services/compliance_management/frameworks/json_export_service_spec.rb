# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Frameworks::JsonExportService, feature_category: :compliance_management do
  subject(:service) { described_class.new user:, group:, framework: }

  let_it_be(:user) { create :user, name: 'Rick Sanchez' }
  let_it_be(:group) { create :group, name: 'parent' }

  let_it_be(:framework) do
    create(:compliance_framework, name: 'ISO 27001',
      description: 'International standard to manage information security.',
      color: '#808080')
  end

  let_it_be(:requirement) do
    create(:compliance_requirement,
      name: 'A.6.1.2 Segregation of duties',
      description: "Conflicting duties and areas of responsibility shall be segregated to reduce opportunities for " \
        "unauthorized or unintentional modification or misuse of the organization's assets",
      framework: framework)
  end

  let_it_be(:expression) do
    {
      operator: ">=",
      field: "minimum_approvals_required",
      value: 2
    }.to_json
  end

  let_it_be(:control) do
    create(:compliance_requirements_control, :minimum_approvals_required_2,
      compliance_requirement: requirement)
  end

  before do
    stub_licensed_features(group_level_compliance_dashboard: true)
  end

  describe "#execute" do
    before_all do
      group.add_owner user
    end

    context 'when group_level_compliance_dashboard is disabled' do
      before do
        stub_licensed_features(group_level_compliance_dashboard: false)
      end

      context 'when user is an owner' do
        before_all do
          group.add_owner(user)
        end

        it 'returns an access denied error' do
          result = service.execute

          expect(result).to be_error
          expect(result.message).to eq("Access to group denied for user with ID: #{user.id}")
        end

        it 'returns the expected JSON structure' do
          result = ::Gitlab::Json.parse(service.execute.payload)

          expect(result).to match({})
        end
      end
    end

    context 'when namespace is not a group' do
      let_it_be(:group) { create(:project) }

      it 'returns an error' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('namespace must be a group')
      end
    end

    context 'when user is owner of namespace' do
      it { expect(service.execute).to be_success }

      it 'returns a valid JSON payload' do
        result = service.execute
        expect { ::Gitlab::Json.parse(result.payload) }.not_to raise_error
      end

      it 'returns the expected JSON structure' do
        result = ::Gitlab::Json.parse(service.execute.payload)

        expect(result).to match({
          'name' => 'ISO 27001',
          'description' => 'International standard to manage information security.',
          'color' => '#808080',
          'requirements' => [
            {
              'name' => 'A.6.1.2 Segregation of duties',
              'description' => "Conflicting duties and areas of responsibility shall be segregated to reduce " \
                "opportunities for unauthorized or unintentional modification or misuse of the organization's assets",
              'controls' => [{
                "control_type" => "internal",
                "expression" => { "field" => "minimum_approvals_required", "operator" => ">=", "value" => 2 },
                "name" => "minimum_approvals_required_2"
              }]
            }
          ]
        })
      end
    end

    context 'when user is a maintainer' do
      before_all do
        group.add_maintainer(user)
      end

      it 'returns an access denied error' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq("Access to group denied for user with ID: #{user.id}")
      end

      it 'returns an empty JSON structure' do
        result = ::Gitlab::Json.parse(service.execute.payload)
        expect(result).to match({})
      end
    end

    context 'when an unexpected error occurs' do
      before do
        allow(service).to receive(:payload).and_raise(StandardError.new('Unexpected error'))
      end

      it 'tracks the exception and returns an error response' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          instance_of(StandardError),
          group_id: group.id,
          user_id: user.id,
          framework_id: framework.id
        )

        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('Failed to export framework')
      end
    end
  end
end
