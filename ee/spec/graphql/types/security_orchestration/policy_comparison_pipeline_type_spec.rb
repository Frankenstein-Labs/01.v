# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['PolicyComparisonPipeline'], feature_category: :security_policy_management do
  let(:fields) { %i[report_type source target] }

  it { expect(described_class).to have_graphql_fields(fields) }
end
