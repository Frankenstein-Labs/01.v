# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['DastProfileCadenceInput'], feature_category: :dynamic_application_security_testing do
  include GraphqlHelpers

  specify { expect(described_class.graphql_name).to eq('DastProfileCadenceInput') }

  it 'has the correct arguments' do
    expect(described_class.arguments.keys).to match_array(%w[unit duration])
  end
end
