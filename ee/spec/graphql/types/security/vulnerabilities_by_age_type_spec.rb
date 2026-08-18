# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Security::VulnerabilitiesByAgeType, feature_category: :vulnerability_management do
  let(:expected_fields) { %i[name count by_severity by_report_type] }

  subject { described_class }

  it { is_expected.to have_graphql_fields(expected_fields) }
end
