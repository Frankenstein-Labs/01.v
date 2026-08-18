# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::NoteableType, feature_category: :team_planning do
  describe '#possible_types' do
    it 'adds exactly the EE noteables to the union', :aggregate_failures do
      expect(described_class.possible_types).to include(
        ::Types::VulnerabilityType,
        ::Types::EpicType,
        ::Types::ComplianceManagement::Projects::ComplianceViolationType
      )

      # Upper-bound guard: 7 CE noteables (see spec/graphql/types/noteable_type_spec.rb)
      # plus the 3 EE noteables above. The CE spec switched from `match_array` to
      # `include` and gave up its check that no unexpected type joins the union, so
      # assert the total here -- a stray addition fails instead of passing silently.
      expect(described_class.possible_types.size).to eq(10)
    end
  end

  describe '.resolve_type' do
    it 'maps each EE noteable to its type', :aggregate_failures do
      expect(described_class.resolve_type(build_stubbed(:vulnerability), {}))
        .to eq(::Types::VulnerabilityType)
      expect(described_class.resolve_type(build_stubbed(:epic), {}))
        .to eq(::Types::EpicType)
      expect(described_class.resolve_type(build_stubbed(:project_compliance_violation), {}))
        .to eq(::Types::ComplianceManagement::Projects::ComplianceViolationType)
    end
  end
end
