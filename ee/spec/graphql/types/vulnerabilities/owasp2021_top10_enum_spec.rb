# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Vulnerabilities::Owasp2021Top10Enum,
  feature_category: :vulnerability_management do
  it 'exposes all owasp_top_10_2021 values' do
    expect(described_class.values.values.flat_map(&:value)).to match_array(
      Enums::Vulnerability::OWASP_TOP_10_BY_YEAR["2021"].keys + ['none'])
  end
end
