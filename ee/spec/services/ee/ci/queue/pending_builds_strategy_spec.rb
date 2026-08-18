# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Queue::PendingBuildsStrategy, :freeze_time, feature_category: :continuous_integration do
  let(:runner) { create(:ci_runner, :instance, :online) }
  let(:relation) { Ci::PendingBuild.all }
  let(:pending_build) { create(:ci_pending_build) }

  subject(:service) { described_class.new(runner) }

  describe '.enforce_minutes_limit' do
    it 'restricts to the with_ci_minutes_available scope' do
      expect(relation).to receive(:with_ci_minutes_available).and_return([pending_build])
      expect(service.enforce_minutes_limit(relation)).to include(pending_build)
    end
  end

  describe '.enforce_allowed_plan_name_uids' do
    let(:allowed_plan_name_uids) { [Plan::PLAN_NAME_UID_LIST[:premium], Plan::PLAN_NAME_UID_LIST[:ultimate]] }

    it 'restricts to the with_allowed_plan_name_uids scope' do
      expect(relation).to receive(:with_allowed_plan_name_uids)
        .with(allowed_plan_name_uids).and_return([pending_build])

      expect(service.enforce_allowed_plan_name_uids(relation, allowed_plan_name_uids)).to include(pending_build)
    end
  end
end
