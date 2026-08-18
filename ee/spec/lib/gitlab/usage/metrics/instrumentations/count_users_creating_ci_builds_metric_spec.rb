# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountUsersCreatingCiBuildsMetric, feature_category: :product_analytics do
  builds_table_name = Ci::Build.table_name
  colname = 'user_id'

  RSpec.shared_examples 'a correct secure type instrumented metric value' do |params|
    let(:expected_value) { params[:expected_value] }

    before_all do
      user = create(:user)
      user2 = create(:user)

      described_class::SECURE_PRODUCT_TYPES.each do |secure_type|
        create(:ci_build, name: secure_type, user: user, created_at: 3.days.ago)
        create(:ci_build, name: secure_type, user: user)
        create(:ci_build, name: secure_type, user: user2, created_at: 31.days.ago)
      end
    end

    it_behaves_like "with secure type all", described_class, builds_table_name, colname, params

    described_class::SECURE_PRODUCT_TYPES.each do |secure_type|
      it_behaves_like "with secure type", secure_type, params
    end
  end

  it_behaves_like "with time_frame all", builds_table_name, colname

  it_behaves_like 'with time_frame 28d', builds_table_name, colname, :db

  it_behaves_like 'with exception handling'

  it_behaves_like 'with cache', described_class, 'count_users_creating_ci_builds', ::User
end
