# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::RunnersAvailabilityChecker, :request_store, :saas,
  feature_category: :continuous_integration do
  let(:checker) { described_class.instance_for(project) }

  describe '#self.instance_for' do
    let_it_be(:project) { create(:project) }

    it 'creates instance for the project' do
      expect(checker).to be_instance_of ::Gitlab::Ci::RunnersAvailabilityChecker
    end

    context 'when more projects are using the builder' do
      let_it_be(:project2) { create(:project) }

      it 'caches instance for a specific project' do
        checker2 = described_class.instance_for(project)
        checker3 = described_class.instance_for(project2)

        expect(checker).to be_instance_of ::Gitlab::Ci::RunnersAvailabilityChecker
        expect(checker2).to be_instance_of ::Gitlab::Ci::RunnersAvailabilityChecker
        expect(checker3).to be_instance_of ::Gitlab::Ci::RunnersAvailabilityChecker

        expect(checker2).to eq checker
        expect(checker3).not_to eq checker
      end
    end
  end

  describe '#check', :freeze_time do
    let_it_be(:ultimate_plan) { create(:ultimate_plan) }

    let(:pipeline) { create(:ci_pipeline, project: project) }
    let(:build) { create(:ci_build, :success, pipeline: pipeline) }

    subject(:result) { checker.check(build.build_matcher) }

    context 'when job is executable' do
      let_it_be(:namespace) { create(:namespace_with_plan, plan: :premium_plan) }
      let_it_be(:project) { create(:project, namespace: namespace) }
      let_it_be(:runner) { create(:ci_runner, :instance, :online) }

      it { expect(result.available?).to be_truthy }
      it { expect(result.drop_reason).to be_nil }
    end

    context 'when CI quota is exceeded' do
      let_it_be(:namespace) { create(:namespace_with_plan, :with_used_build_minutes_limit, plan: :premium_plan) }
      let_it_be(:project) { create(:project, namespace: namespace) }
      let_it_be(:runner) { create(:ci_runner, :instance, :online) }

      it { expect(result.available?).to be_falsey }
      it { expect(result.drop_reason).to eq(:ci_quota_exceeded) }
    end

    context 'when allowed_plans are not matched' do
      let_it_be(:namespace) { create(:namespace_with_plan, plan: :premium_plan) }
      let_it_be(:project) { create(:project, namespace: namespace) }
      let_it_be(:runner) do
        create(:ci_runner, :instance, :online, allowed_plan_name_uids: [Plan::PLAN_NAME_UID_LIST[:ultimate]])
      end

      it { expect(result.available?).to be_falsey }
      it { expect(result.drop_reason).to eq(:no_matching_runner) }
    end

    context 'when both CI quota and allowed_plans are violated' do
      let_it_be(:namespace) { create(:namespace_with_plan, :with_used_build_minutes_limit, plan: :premium_plan) }
      let_it_be(:project) { create(:project, namespace: namespace) }
      let_it_be(:runner) do
        create(:ci_runner, :instance, :online, allowed_plan_name_uids: [Plan::PLAN_NAME_UID_LIST[:ultimate]])
      end

      it { expect(result.available?).to be_falsey }
      it { expect(result.drop_reason).to eq(:ci_quota_exceeded) }
    end
  end
end
