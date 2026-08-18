# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['PolicyError'], feature_category: :security_policy_management do
  let(:fields) { %i[error report_type message data] }

  it { expect(described_class).to have_graphql_fields(fields) }
end
