# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::RunnersAvailability::AllowedPlans, :saas, feature_category: :continuous_integration do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:ultimate_plan) { create(:ultimate_plan) }
  let_it_be(:premium_plan) { create(:premium_plan) }
  let_it_be(:namespace) { create(:namespace) }
  let_it_be(:project, freeze: false) { create(:project, namespace: namespace) }

  let(:build) { build_stubbed(:ci_build, project: project) }
  let(:allowed_plans_checker) { described_class.new(project, project.all_runners.active.online.runner_matchers) }

  describe '#available?', :saas, :freeze_time do
    context 'when runners are available' do
      where(:shared_runners_enabled, :plan_name, :instance_runner_restricts_plan,
        :private_runner_available, :expected_result) do
        true  | :premium  | true | false | false
        true  | :premium  | true | true  | true
        true  | :ultimate | true | false | true
        true  | :ultimate | true | true  | true
        false | :premium  | true | false | true
        false | :premium  | true | true  | true
        false | :ultimate | true | false | true
        false | :ultimate | true | true  | true

        true  | :premium  | false | false | true
        true  | :premium  | false | true  | true
        true  | :ultimate | false | false | true
        true  | :ultimate | false | true  | true
        false | :premium  | false | false | true
        false | :premium  | false | true  | true
        false | :ultimate | false | false | true
        false | :ultimate | false | true  | true
      end

      with_them do
        subject { allowed_plans_checker.available?(build.build_matcher) }

        let!(:instance_runner_with_plan_restriction) do
          create(:ci_runner, :instance, :online,
            allowed_plan_name_uids: [Plan::PLAN_NAME_UID_LIST[:ultimate]], active: instance_runner_restricts_plan)
        end

        let!(:instance_runner_without_plan_restriction) do
          create(:ci_runner, :instance, :online, active: !instance_runner_restricts_plan)
        end

        let!(:private_runner) do
          create(:ci_runner, :project, :online, projects: [project], active: private_runner_available)
        end

        before do
          namespace.gitlab_subscription.update!(hosted_plan: Plan.find_by_name(plan_name))
          project.update!(shared_runners_enabled: shared_runners_enabled)
        end

        it { is_expected.to eq(expected_result) }
      end
    end

    context 'when no runners are available' do
      subject { allowed_plans_checker.available?(build.build_matcher) }

      before do
        project.update!(shared_runners_enabled: true)
      end

      it { is_expected.to be(true) }
    end
  end

  describe 'database queries', :request_store, :freeze_time do
    let_it_be(:private_runner) do
      create(:ci_runner, :project, :online, projects: [project])
    end

    it 'caches records loaded from database' do
      ActiveRecord::QueryRecorder.new(skip_cached: false) do
        allowed_plans_checker.available?(build.build_matcher)
      end

      expect { allowed_plans_checker.available?(build.build_matcher) }.not_to exceed_all_query_limit(0)
    end

    it 'does not join across databases' do
      with_cross_joins_prevented do
        allowed_plans_checker.available?(build.build_matcher)
      end
    end
  end
end
