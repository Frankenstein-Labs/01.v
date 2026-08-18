# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountEnterpriseUsersMetric, feature_category: :user_management do
  let_it_be(:user_detail_with_enterprise_group) { create(:enterprise_user) }
  let_it_be(:user_details_without_enterprise_group) { create_list(:user, 3, enterprise_group: nil) }

  it_behaves_like 'a correct instrumented metric value and query', { time_frame: 'all', data_source: 'database' } do
    let(:expected_value) { 1 }

    let(:expected_query) do
      'SELECT COUNT("user_details"."user_id") FROM "user_details" ' \
        'WHERE "user_details"."enterprise_group_id" IS NOT NULL'
    end
  end
end
