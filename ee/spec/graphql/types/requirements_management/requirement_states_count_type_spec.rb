# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['RequirementStatesCount'], feature_category: :requirements_management do
  it { expect(described_class.graphql_name).to eq('RequirementStatesCount') }

  it 'has specific fields' do
    %i[opened archived].each do |field_name|
      expect(described_class).to have_graphql_field(field_name)
    end
  end
end
