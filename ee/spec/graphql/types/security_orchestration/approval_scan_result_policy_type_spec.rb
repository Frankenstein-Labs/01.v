# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ApprovalScanResultPolicy'], feature_category: :security_policy_management do
  let(:fields) { %i[report_type name approvals_required] }

  it { expect(described_class).to have_graphql_fields(fields) }
end
