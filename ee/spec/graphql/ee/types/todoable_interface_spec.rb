# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::TodoableInterface, feature_category: :notifications do
  let(:extended_class) { described_class }

  describe ".resolve_type" do
    it 'knows the correct type for EE-only objects' do
      expect(extended_class.resolve_type(build(:epic), {})).to eq(Types::EpicType)
      expect(extended_class.resolve_type(build(:vulnerability), {})).to eq(Types::VulnerabilityType)
      expect(extended_class.resolve_type(build(:project_compliance_violation), {}))
        .to eq(Types::ComplianceManagement::Projects::ComplianceViolationType)
      expect(extended_class.resolve_type(build(:duo_workflows_workflow), {}))
        .to eq(Types::Ai::DuoWorkflows::WorkflowType)
    end
  end
end
