# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ExclusionTypeEnum'], feature_category: :secret_detection do
  it { expect(described_class.graphql_name).to eq('ExclusionTypeEnum') }
  it { expect(described_class.values.keys).to include(*%w[PATH REGEX_PATTERN RAW_VALUE RULE]) }
end
