# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Types::Analytics::Dora::GroupDoraType, feature_category: :dora_metrics do
  it 'has the expected fields' do
    expect(described_class).to have_graphql_fields(:metrics, :projects)
  end

  describe 'metrics field' do
    subject { described_class.fields['metrics'] }

    it { is_expected.to have_graphql_resolver(Resolvers::Analytics::Dora::DoraMetricsResolver) }
  end

  describe 'projects field' do
    subject { described_class.fields['projects'] }

    it { is_expected.to have_graphql_resolver(Resolvers::Analytics::Dora::DoraProjectsResolver) }
  end
end
