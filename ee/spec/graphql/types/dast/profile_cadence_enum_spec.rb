# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['DastProfileCadenceUnit'], feature_category: :dynamic_application_security_testing do
  it 'exposes all alert field names' do
    expect(described_class.values.keys).to match_array(
      %w[DAY WEEK MONTH YEAR]
    )
  end
end
