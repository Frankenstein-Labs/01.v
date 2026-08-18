# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Projects::ViolationDetectors::BaseDetector,
  feature_category: :compliance_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:control) { create(:compliance_requirements_control) }
  let_it_be(:audit_event) { create(:audit_event) }
  let_it_be(:detector) { described_class.new(project, control, audit_event) }

  describe '#detect_violations' do
    it 'raises NotImplementedError' do
      expect { detector.detect_violations }.to raise_error(
        NotImplementedError,
        "Subclasses must implement #detect_violations"
      )
    end
  end
end
