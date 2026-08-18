# frozen_string_literal: true

# Shared examples for testing the licensedFeatureAvailability GraphQL field.
#
# Required let bindings:
#   - `parent_key`    - GraphQL parent type key (e.g., :project, :namespace)
#   - `parent`        - the parent object (project or group)
#   - `user`          - authenticated user with access
#   - `feature_name`  - licensed feature enum value string (e.g., 'EPICS')
#   - `feature_sym`   - licensed feature name symbol (e.g., :epics)
#   - `licensable`    - the object class to stub (e.g., Project, Group)
#
RSpec.shared_examples 'licensed feature availability query' do
  include GraphqlHelpers

  let(:query) do
    <<~GQL
      query {
        #{parent_key}(fullPath: "#{parent.full_path}") {
          licensedFeatureAvailability(feature: #{feature_name}) {
            available
            requiredPlan
          }
        }
      }
    GQL
  end

  subject(:result) { graphql_data_at(parent_key, :licensed_feature_availability) }

  context 'when the feature is available' do
    before do
      stub_licensed_features(feature_sym => true)
      post_graphql(query, current_user: user)
    end

    it 'returns available true and the required plan' do
      expected_plan = ::GitlabSubscriptions::Features.plans_with_feature(feature_sym).first

      expect(result).to eq('available' => true, 'requiredPlan' => expected_plan)
    end
  end

  context 'when the feature is not available' do
    before do
      stub_licensed_features(feature_sym => false)
      post_graphql(query, current_user: user)
    end

    it 'returns available false and the required plan' do
      expected_plan = ::GitlabSubscriptions::Features.plans_with_feature(feature_sym).first

      expect(result).to eq('available' => false, 'requiredPlan' => expected_plan)
    end
  end
end
