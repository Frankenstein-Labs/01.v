# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['PolicyViolationDetails'], feature_category: :security_policy_management do
  let(:fields) do
    %i[
      policies new_scan_finding previous_scan_finding license_scanning any_merge_request errors
      comparison_pipelines violations_count
    ]
  end

  it { expect(described_class).to have_graphql_fields(fields) }
end
