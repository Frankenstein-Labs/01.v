# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountUsersAssignedToCustomAdminRoleMetric, feature_category: :permissions do
  let_it_be(:regular_user) { create(:user) }
  let_it_be(:user_with_admin_role) { create(:user) }
  let_it_be(:user_member_role) { create(:user_member_role, user: user_with_admin_role) }

  let(:expected_value) { 1 }
  let(:expected_query) { 'SELECT COUNT(DISTINCT "user_member_roles"."user_id") FROM "user_member_roles"' }

  it_behaves_like 'a correct instrumented metric value and query', { time_frame: 'all', data_source: 'database' }
end
