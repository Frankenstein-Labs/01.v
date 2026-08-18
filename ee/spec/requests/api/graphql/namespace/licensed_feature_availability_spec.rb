# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'namespace.licensedFeatureAvailability', feature_category: :subscription_management do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:group, :public, developers: user) }

  let(:parent_key) { :namespace }
  let(:parent) { namespace }
  let(:feature_name) { 'EPICS' }
  let(:feature_sym) { :epics }
  let(:licensable) { Group }

  it_behaves_like 'licensed feature availability query'

  context 'when unauthenticated' do
    let(:query) do
      <<~GQL
        query {
          namespace(fullPath: "#{namespace.full_path}") {
            licensedFeatureAvailability(feature: EPICS) {
              available
              requiredPlan
            }
          }
        }
      GQL
    end

    subject(:result) { graphql_data_at(:namespace, :licensed_feature_availability) }

    before do
      stub_licensed_features(epics: false)
      post_graphql(query, current_user: nil)
    end

    it 'still returns data since namespace queries are public' do
      expect(result).to be_present
    end
  end
end
