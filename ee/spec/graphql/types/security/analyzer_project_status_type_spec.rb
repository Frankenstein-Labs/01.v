# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AnalyzerProjectStatusType'], feature_category: :security_asset_inventories do
  let(:expected_fields) { %i[projectId analyzerType status lastCall buildId updatedAt source] }

  subject { described_class }

  it { is_expected.to have_graphql_fields(expected_fields) }
end
