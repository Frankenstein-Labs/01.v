# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'project.licensedFeatureAvailability', feature_category: :subscription_management do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, developers: user) }

  let(:parent_key) { :project }
  let(:parent) { project }
  let(:feature_name) { 'SECURITY_DASHBOARD' }
  let(:feature_sym) { :security_dashboard }
  let(:licensable) { Project }

  it_behaves_like 'licensed feature availability query'

  context 'when unauthenticated' do
    let(:query) do
      <<~GQL
        query {
          project(fullPath: "#{project.full_path}") {
            licensedFeatureAvailability(feature: SECURITY_DASHBOARD) {
              available
              requiredPlan
            }
          }
        }
      GQL
    end

    before do
      post_graphql(query, current_user: nil)
    end

    it_behaves_like 'a working graphql query that returns no data'
  end
end
