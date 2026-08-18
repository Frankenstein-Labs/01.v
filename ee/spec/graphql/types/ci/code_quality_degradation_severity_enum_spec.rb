# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['CodeQualityDegradationSeverity'], feature_category: :code_quality do
  it 'exposes all code quality degradation severity types' do
    expect(described_class.values.keys).to eq(
      ::Gitlab::Ci::Reports::CodequalityReports::SEVERITY_PRIORITIES.keys.map(&:upcase)
    )
  end
end
