# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AnalyzerGroupStatusType'], feature_category: :security_asset_inventories do
  include GraphqlHelpers

  let(:expected_fields) do
    %i[namespace_id analyzer_type success failure stale not_configured total_projects_count updatedAt]
  end

  subject { described_class }

  it { is_expected.to have_graphql_fields(expected_fields) }

  describe '#stale' do
    let_it_be(:group) { create(:group) }
    let_it_be(:user) { create(:user, owner_of: group) }
    let_it_be(:namespace_status) { create(:analyzer_namespace_status, namespace: group, stale: 3) }

    before do
      stub_licensed_features(security_inventory: true)
    end

    it 'returns the stale count' do
      expect(resolve_field(:stale, namespace_status, current_user: user)).to eq(3)
    end
  end
end
