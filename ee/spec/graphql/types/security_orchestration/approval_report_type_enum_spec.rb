# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ApprovalReportType'], feature_category: :security_policy_management do
  specify { expect(described_class.graphql_name).to eq('ApprovalReportType') }

  it 'exposes all policy relation types' do
    expect(described_class.values.keys).to match_array(%w[SCAN_FINDING LICENSE_SCANNING ANY_MERGE_REQUEST])
  end
end
