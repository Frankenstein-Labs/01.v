# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ApiFuzzingScanMode'], feature_category: :fuzz_testing do
  it 'exposes all API fuzzing scan modes' do
    expect(described_class.values.keys).to match_array(%w[HAR OPENAPI POSTMAN])
  end
end
