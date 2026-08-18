# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['EpicDescendantWeights'], feature_category: :portfolio_management do
  it { expect(described_class.graphql_name).to eq('EpicDescendantWeights') }

  it 'has specific fields' do
    %i[opened_issues closed_issues opened_issues_total closed_issues_total].each do |field_name|
      expect(described_class).to have_graphql_field(field_name)
    end
  end
end
