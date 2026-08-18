# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Import::PlaceholderUserLimit, :saas, :clean_gitlab_redis_shared_state, feature_category: :importers do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:namespace) { create(:group_with_plan, plan: :premium_plan) }

  before_all do
    create(:plan_limits, :premium_plan,
      import_placeholder_user_limit_tier_1: 1,
      import_placeholder_user_limit_tier_2: 2,
      import_placeholder_user_limit_tier_3: 3,
      import_placeholder_user_limit_tier_4: 4
    )
  end

  describe '#exceeded?' do
    subject(:exceeded) { described_class.new(namespace: namespace).exceeded? }

    before do
      allow(namespace.gitlab_subscription).to receive(:seats).and_return(seats)
      create_list(:import_source_user, expected_limit - 1, namespace: namespace)
    end

    where(:seats, :expected_limit) do
      100 | 1
      101 | 2
      500 | 2
      501 | 3
      1_000 | 3
      1_001 | 4
    end

    with_them do
      context 'when under the limit' do
        it { is_expected.to be(false) }
      end

      context 'when over the limit' do
        before do
          create(:import_source_user, namespace: namespace)
        end

        it { is_expected.to be(true) }
      end
    end
  end
end
