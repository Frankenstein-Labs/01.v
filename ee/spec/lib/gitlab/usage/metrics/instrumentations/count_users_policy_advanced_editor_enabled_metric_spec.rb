# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountUsersPolicyAdvancedEditorEnabledMetric, feature_category: :security_policy_management do
  let_it_be(:user_with_policy_advanced_editor_enabled) { create(:user) }
  let!(:user_preference) do
    create(:user_preference, user: user_with_policy_advanced_editor_enabled, policy_advanced_editor: true)
  end

  let_it_be(:other_user) { create(:user) }

  let(:expected_value) { 1 }
  let(:expected_query) do
    <<~SQL.squish
      SELECT
          COUNT("user_preferences"."id")
      FROM
          "user_preferences"
          INNER JOIN "users" ON "users"."id" = "user_preferences"."user_id"
      WHERE
          "user_preferences"."policy_advanced_editor" = TRUE
          AND "users"."state" = 'active'
          AND "users"."user_type" IN (0, 6, 4, 13)
    SQL
  end

  it_behaves_like 'a correct instrumented metric value and query', { time_frame: 'all' }
end
