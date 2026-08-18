# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Security::VulnerabilitiesByIdentifierType, feature_category: :vulnerability_management do
  let(:expected_fields) { %i[name url count by_severity] }

  subject { described_class }

  it { is_expected.to have_graphql_fields(expected_fields) }
end
