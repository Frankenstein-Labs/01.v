# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ComparedSecurityReportScanner'], feature_category: :vulnerability_management do
  let(:expected_fields) { %i[name external_id vendor] }

  it { expect(described_class).to have_graphql_fields(expected_fields) }
end
