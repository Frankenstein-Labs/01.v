# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ExclusionScannerEnum'], feature_category: :secret_detection do
  it { expect(described_class.graphql_name).to eq('ExclusionScannerEnum') }
  it { expect(described_class.values.keys).to include(*%w[SECRET_PUSH_PROTECTION]) }
end
