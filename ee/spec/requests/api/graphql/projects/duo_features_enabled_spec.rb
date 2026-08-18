# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'querying duoFeaturesEnabled', feature_category: :duo_code_review do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project) }

  describe 'duoFeaturesEnabled' do
    before_all do
      project.add_maintainer(current_user)
    end

    it 'is available to query' do
      result = GitlabSchema.execute(%(
          query {
            project(fullPath: "#{project.full_path}") {
              duoFeaturesEnabled
            }
          }
        ), context: { current_user: current_user }).as_json

      expect(result.dig('data', 'project', 'duoFeaturesEnabled')).to eq(project.duo_features_enabled)
    end
  end
end
