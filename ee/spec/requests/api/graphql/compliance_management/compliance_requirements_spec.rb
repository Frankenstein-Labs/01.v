# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Getting list of all requirement controls', feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }

  let(:query) do
    <<~GQL
      query {
        complianceRequirementControls {
          controlExpressions {
            id
            name
            expression {
              ... on BooleanExpression {
                field
                operator
                value
              }
              ... on IntegerExpression {
                field
                operator
                value
              }
              ... on StringExpression {
                field
                operator
                value
              }
            }
          }
        }
      }
    GQL
  end

  let(:controls_data) { graphql_data['complianceRequirementControls'] }

  it 'returns available slash commands' do
    post_graphql(query, current_user: user)

    expect(response).to have_gitlab_http_status(:success)
    expect(controls_data['controlExpressions']).to match_array(
      Gitlab::Json.parse(File.read(Rails.root.join('ee/config/compliance_management/requirement_controls.json'))))
  end
end
