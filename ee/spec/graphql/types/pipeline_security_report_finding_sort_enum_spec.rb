# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['PipelineSecurityReportFindingSort'], feature_category: :vulnerability_management do
  it { expect(described_class.graphql_name).to eq('PipelineSecurityReportFindingSort') }

  it 'exposes all the existing security findings sort orders' do
    expect(described_class.values.keys).to include(*%w[severity_desc severity_asc])
  end
end
