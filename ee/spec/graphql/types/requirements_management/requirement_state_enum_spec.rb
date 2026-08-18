# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['RequirementState'], feature_category: :requirements_management do
  it { expect(described_class.graphql_name).to eq('RequirementState') }

  it 'exposes all the existing requirement states' do
    expect(described_class.values.keys).to include(*%w[OPENED ARCHIVED])
  end
end
