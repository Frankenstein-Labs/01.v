# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['SecurityTrainingUrl'], feature_category: :vulnerability_management do
  let(:fields) { %i[name url status identifier] }

  it { expect(described_class).to have_graphql_fields(fields) }
end
