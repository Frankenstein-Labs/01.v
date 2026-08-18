# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['EnabledSecurityScans'], feature_category: :vulnerability_management do
  let(:expected_fields) { Security::Scan.scan_types.keys + [:ready] }

  it { expect(described_class).to have_graphql_fields(*expected_fields) }
end
