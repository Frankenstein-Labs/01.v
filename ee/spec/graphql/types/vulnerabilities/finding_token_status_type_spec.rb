# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Vulnerabilities::FindingTokenStatusType, feature_category: :secret_detection do
  let(:expected_fields) do
    %w[id status createdAt updatedAt lastVerifiedAt]
  end

  subject { described_class }

  it { is_expected.to have_graphql_fields(expected_fields) }
end
