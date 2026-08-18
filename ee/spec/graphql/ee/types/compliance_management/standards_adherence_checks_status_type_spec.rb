# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['StandardsAdherenceChecksStatus'], feature_category: :compliance_management do
  subject { described_class }

  fields = %w[started_at checks_completed total_checks]

  it 'has the correct fields' do
    is_expected.to have_graphql_fields(fields)
  end
end
