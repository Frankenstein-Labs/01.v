# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountUsersWithMinimalAccessMetric, feature_category: :service_ping do
  let_it_be(:user_with_minimal_access) { create(:user) }
  let_it_be(:user_with_guest_access) { create(:user) }
  let_it_be(:deactivated_user_with_minimal_access) { create(:user, state: :deactivated) }

  let(:expected_value) { 1 }
  let(:time_frame) { 'all' }
  let(:expected_query) do
    <<~SQL.squish
      SELECT COUNT("users"."id") FROM "users"
      INNER JOIN "user_highest_roles" ON "user_highest_roles"."user_id" = "users"."id"
      WHERE "users"."state" = 'active' AND "users"."user_type" IN (0, 6, 4, 13)
      AND "user_highest_roles"."highest_access_level" = #{Gitlab::Access::MINIMAL_ACCESS}
    SQL
  end

  before_all do
    create(:user_highest_role, user: user_with_minimal_access, highest_access_level: Gitlab::Access::MINIMAL_ACCESS)
    create(:user_highest_role, user: user_with_guest_access, highest_access_level: Gitlab::Access::GUEST)
    create(:user_highest_role, user: deactivated_user_with_minimal_access,
      highest_access_level: Gitlab::Access::MINIMAL_ACCESS)
  end

  it_behaves_like 'a correct instrumented metric value and query', { time_frame: 'all', data_source: 'database' }
end
