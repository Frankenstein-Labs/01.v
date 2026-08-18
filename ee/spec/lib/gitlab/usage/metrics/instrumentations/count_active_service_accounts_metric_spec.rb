# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountActiveServiceAccountsMetric, feature_category: :service_ping do
  context 'when the time_frame is 28 days' do
    let_it_be(:service_account_created_within_28d) { create(:user, :service_account, updated_at: 3.days.ago) }

    let_it_be(:expected_value) { 1 }

    let(:old_time) { 30.days.ago.to_fs(:db) }
    let(:recent_time) { 2.days.ago.to_fs(:db) }
    let(:expected_query) do
      <<~SQL.squish
        SELECT COUNT(DISTINCT "users"."id")
        FROM "users"
        WHERE "users"."user_type" = 13
        AND "users"."state" = 'active'
        AND "users"."updated_at" BETWEEN '#{old_time}' AND '#{recent_time}'
      SQL
    end

    it_behaves_like 'a correct instrumented metric value and query', { time_frame: '28d', data_source: 'database' }
  end
end
