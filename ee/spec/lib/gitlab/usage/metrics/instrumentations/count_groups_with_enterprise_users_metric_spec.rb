# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountGroupsWithEnterpriseUsersMetric, feature_category: :user_management do
  let_it_be(:group1) { create(:group) }
  let_it_be(:group2) { create(:group) }

  let_it_be(:enterprise_user1_of_group1) { create(:enterprise_user, enterprise_group: group1) }
  let_it_be(:enterprise_user2_of_group2) { create(:enterprise_user, enterprise_group: group2) }
  let_it_be(:enterprise_user3_of_group2) { create(:enterprise_user, enterprise_group: group2) }

  let_it_be(:user1) { create(:user) }
  let_it_be(:user2) { create(:user) }
  let_it_be(:user3) { create(:user) }

  it_behaves_like 'a correct instrumented metric value and query', { time_frame: 'all', data_source: 'database' } do
    let(:expected_value) { 2 }

    let(:expected_query) do
      'SELECT COUNT(DISTINCT "user_details"."enterprise_group_id") FROM "user_details" ' \
        'WHERE "user_details"."enterprise_group_id" IS NOT NULL'
    end
  end
end
