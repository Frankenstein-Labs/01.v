# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiXrayReport'], feature_category: :code_suggestions do
  it { expect(described_class.graphql_name).to eq('AiXrayReport') }

  it 'exposes the expected fields' do
    expected_fields = %i[
      language
    ]

    expect(described_class).to have_graphql_fields(*expected_fields)
  end
end
