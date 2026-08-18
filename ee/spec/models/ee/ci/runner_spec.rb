# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Runner, feature_category: :hosted_runners do
  let_it_be(:namespace) { create(:group, created_at: Date.new(2021, 7, 16)) }
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:admin_bot) { create(:user, :admin_bot) }

  let(:shared_runners_minutes) { 400 }

  before do
    allow(::Gitlab::CurrentSettings).to receive(:shared_runners_minutes) { shared_runners_minutes }
  end

  it do
    is_expected.to have_many(:instance_runner_monthly_usages)
    .class_name('Ci::Minutes::InstanceRunnerMonthlyUsage')
    .inverse_of(:runner)
  end

  it do
    is_expected.to have_many(:hosted_runner_monthly_usages)
    .class_name('Ci::Minutes::GitlabHostedRunnerMonthlyUsage')
    .inverse_of(:runner)
  end

  describe 'ci associations' do
    it 'has one cost setting' do
      is_expected.to have_one(:cost_settings)
      .inverse_of(:runner)
      .class_name('Ci::Minutes::CostSetting')
      .with_foreign_key(:runner_id)
    end

    it { is_expected.to have_one(:hosted_registration).class_name('Ci::HostedRunner').inverse_of(:runner) }

    it 'have many runner_controller_runner_level_scopings' do
      is_expected.to have_many(:runner_controller_runner_level_scopings)
                       .class_name('Ci::RunnerControllerRunnerLevelScoping').inverse_of(:runner)
    end
  end

  describe '#dedicated_gitlab_hosted?' do
    context 'when on dedicated installation' do
      before do
        allow(Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(true)
      end

      context 'with an admin bot created runner' do
        let_it_be_with_reload(:runner) { create(:ci_runner, creator: admin_bot) }

        it 'returns true' do
          expect(runner.dedicated_gitlab_hosted?).to be_truthy
        end
      end

      context 'without an admin_bot created runner' do
        let(:runner) { create(:ci_runner, creator: create(:user)) }

        it 'returns false' do
          expect(runner.dedicated_gitlab_hosted?).to be_falsey
        end
      end

      context 'without a runner creator' do
        let(:runner) { create(:ci_runner) }

        it 'returns false' do
          expect(runner.dedicated_gitlab_hosted?).to be_falsey
        end
      end
    end

    context 'when not on dedicated installation' do
      let_it_be_with_reload(:runner) { create(:ci_runner, creator: admin_bot) }

      before do
        allow(Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(false)
      end

      it 'returns false regardless of user' do
        expect(runner.dedicated_gitlab_hosted?).to be_falsey
      end
    end
  end

  describe '#cost_factor_for_project' do
    subject { runner.cost_factor_for_project(project) }

    context 'with group type runner' do
      let_it_be_with_reload(:runner) { create(:ci_runner, :group, groups: [namespace]) }

      ::Gitlab::VisibilityLevel.options.each do |level_name, level_value|
        context "with #{level_name}" do
          before do
            project.update!(visibility_level: level_value)
          end

          it { is_expected.to eq(0.0) }
        end
      end
    end

    context 'with project type runner' do
      let_it_be_with_reload(:runner) { create(:ci_runner, :project, projects: [project]) }

      ::Gitlab::VisibilityLevel.options.each do |level_name, level_value|
        context "with #{level_name}" do
          before do
            project.update!(visibility_level: level_value)
          end

          it { is_expected.to eq(0.0) }
        end
      end
    end

    context 'with instance type runner' do
      let(:runner) do
        create(
          :ci_runner,
          :instance,
          private_projects_minutes_cost_factor: 1.1,
          public_projects_minutes_cost_factor: 0.008
        )
      end

      context 'with private visibility level' do
        let(:project) { create(:project, :private) }

        it { is_expected.to eq(1.1) }

        context 'with unlimited minutes' do
          let(:shared_runners_minutes) { 0 }

          it { is_expected.to eq(0) }
        end
      end

      context 'with public visibility level' do
        let(:project) { create(:project, :public) }

        it { is_expected.to eq(0.008) }
      end

      context 'with internal visibility level' do
        let(:project) { create(:project, :internal) }

        it { is_expected.to eq(1.1) }
      end
    end
  end

  describe '#cost_factor_enabled?' do
    let_it_be_with_reload(:project) do
      create(:project, namespace: namespace)
    end

    context 'when the project has any cost factor' do
      let(:runner) do
        create(:ci_runner, :instance,
          private_projects_minutes_cost_factor: 1,
          public_projects_minutes_cost_factor: 0)
      end

      subject { runner.cost_factor_enabled?(project) }

      it { is_expected.to be_truthy }

      context 'with unlimited minutes' do
        let(:shared_runners_minutes) { 0 }

        it { is_expected.to be_falsy }
      end
    end

    context 'when the project has no cost factor' do
      it 'returns false' do
        runner = create(
          :ci_runner, :instance,
          private_projects_minutes_cost_factor: 0,
          public_projects_minutes_cost_factor: 0
        )

        expect(runner.cost_factor_enabled?(project)).to be_falsy
      end
    end
  end

  describe '.any_shared_runners_with_enabled_cost_factor' do
    subject(:runners) { described_class.any_shared_runners_with_enabled_cost_factor?(project) }

    let_it_be(:namespace) { create(:group) }

    context 'when project is public' do
      let_it_be_with_reload(:project) { create(:project, :public, namespace: namespace) }
      let_it_be_with_reload(:runner) { create(:ci_runner, :instance, public_projects_minutes_cost_factor: 0.0) }

      context 'when public cost factor is greater than zero' do
        before do
          runner.update!(public_projects_minutes_cost_factor: 0.008)
        end

        it 'returns true' do
          expect(runners).to be_truthy
        end
      end

      context 'when public cost factor is zero' do
        it 'returns false' do
          expect(runners).to be_falsey
        end
      end
    end

    context 'when project is private' do
      let_it_be_with_reload(:project) { create(:project, :private, namespace: namespace) }
      let_it_be_with_reload(:runner) { create(:ci_runner, :instance, private_projects_minutes_cost_factor: 1.0) }

      context 'when private cost factor is greater than zero' do
        it 'returns true' do
          expect(runners).to be_truthy
        end
      end

      context 'when private cost factor is zero' do
        before do
          runner.update!(private_projects_minutes_cost_factor: 0.0)
        end

        it 'returns false' do
          expect(runners).to be_falsey
        end
      end
    end
  end

  describe '.order_most_active_desc' do
    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, group: group) }
    let_it_be(:instance_runners) { create_list(:ci_runner, 2) }
    let_it_be(:group_runners) { create_list(:ci_runner, 3, :group, groups: [group]) }

    let(:child_scope) { described_class.all }

    subject(:scope) { child_scope.order_most_active_desc.pluck(:id) }

    describe '.with_top_running_builds_of_runner_type' do
      let(:child_scope) { described_class.with_top_running_builds_of_runner_type(runner_type) }

      context 'with no running builds' do
        context 'when runner_type is instance_type' do
          let(:runner_type) { :instance_type }

          it { is_expected.to be_empty }
        end

        context 'when runner_type is group_type' do
          let(:runner_type) { :group_type }

          it { is_expected.to be_empty }
        end
      end

      context 'with running builds' do
        before_all do
          # Create builds for each runner
          instance_runners.map.with_index do |runner, idx|
            create_list(:ci_build, 3 - idx, :picked, runner: runner, project: project)
          end

          group_runners.map.with_index do |runner, idx|
            create_list(:ci_build, 2 - idx, :picked, runner: runner, project: project)
          end
        end

        context 'when runner_type is instance_type' do
          let(:runner_type) { :instance_type }

          it 'returns instance runners sorted by running builds' do
            is_expected.to eq(instance_runners.pluck(:id))
          end

          it 'limits the number of running builds counted and sorts by id desc' do
            stub_const("EE::Ci::Runner::MOST_ACTIVE_RUNNERS_BUILDS_LIMIT", 2)

            # The first 2 instance runners with most builds have 2 or more builds, but we're capping at 2 builds,
            # so they are all tied for 1st place, and therefore sorted by id desc
            runner_ids = instance_runners.pluck(:id)
            expected_runner_ids = runner_ids[0..1].sort.reverse + runner_ids[2..]

            is_expected.to eq(expected_runner_ids)
          end
        end

        context 'when runner_type is group_type' do
          let(:runner_type) { :group_type }

          it 'returns group runners sorted by running builds' do
            is_expected.to eq(group_runners.pluck(:id).take(2)) # Only returns runners that have builds
          end
        end
      end
    end

    describe '.with_top_running_builds_by_namespace_id' do
      let(:child_scope) { described_class.with_top_running_builds_by_namespace_id(group.id) }

      context 'with no running builds' do
        it { is_expected.to be_empty }
      end

      context 'with running builds' do
        before_all do
          group_runners.map.with_index do |runner, idx|
            create_list(:ci_build, 3 - idx, :picked, runner: runner, project: project)
          end
        end

        it 'returns group runners sorted by running builds' do
          is_expected.to eq(group_runners.pluck(:id))
        end

        it 'limits the number of running builds counted and sorts by id desc' do
          stub_const("EE::Ci::Runner::MOST_ACTIVE_RUNNERS_BUILDS_LIMIT", 2)

          runner_ids = group_runners.pluck(:id)

          # The first 2 group runners with most builds have 2 or more builds, but we're capping at 2 builds,
          # so they are all tied for 1st place, and therefore sorted by id desc
          expected_runner_ids = runner_ids[0..1].reverse + runner_ids[2..]

          is_expected.to eq(expected_runner_ids)
        end
      end
    end
  end

  describe "allowed_plans support" do
    let(:free_plan) { ::GitlabSubscriptions::SystemDefined::Plan.find_by(name: 'free') }
    let(:premium_plan) { ::GitlabSubscriptions::SystemDefined::Plan.find_by(name: 'premium') }

    let(:runner) { create(:ci_runner) }

    describe '#allowed_plans=' do
      it 'sets allowed_plan_name_uids via GitlabSubscriptions::SystemDefined::Plan.uids_for_names' do
        runner.allowed_plans = %w[free premium]

        expect(runner.allowed_plan_name_uids).to match_array([free_plan.id, premium_plan.id])
      end

      it 'ignores unknown plan names' do
        runner.allowed_plans = %w[free unknown_plan]

        expect(runner.allowed_plan_name_uids).to match_array([free_plan.id])
      end

      it 'clears allowed_plan_name_uids when set to an empty array' do
        runner = create(:ci_runner, :instance, allowed_plan_name_uids: [free_plan.id])

        runner.allowed_plans = []
        runner.save!

        expect(runner.reload.allowed_plan_name_uids).to eq([])
      end

      it 'does not populate allowed_plan_ids' do
        runner.allowed_plans = %w[free premium]
        runner.save!
        expect(runner.reload.allowed_plan_ids).to be_empty
      end
    end

    describe '#allowed_plan_names' do
      subject(:names) { runner.allowed_plan_names }

      it { is_expected.to be_empty }

      context 'when allowed_plan_name_uids are set' do
        let(:runner) do
          create(:ci_runner, allowed_plan_name_uids: [free_plan.id, premium_plan.id])
        end

        it { is_expected.to include(free_plan.name) }
        it { is_expected.to include(premium_plan.name) }
      end
    end
  end

  describe '.runner_matchers' do
    subject(:matchers) { described_class.all.runner_matchers }

    context 'with multiple plans' do
      let(:premium_uid) { ::GitlabSubscriptions::SystemDefined::Plan.find_by(name: 'premium').id }
      let(:ultimate_uid) { ::GitlabSubscriptions::SystemDefined::Plan.find_by(name: 'ultimate').id }
      let(:free_uid) { ::GitlabSubscriptions::SystemDefined::Plan.find_by(name: 'free').id }
      let(:bronze_uid) { ::GitlabSubscriptions::SystemDefined::Plan.find_by(name: 'bronze').id }

      before do
        create_list(:ci_runner, 2, allowed_plan_name_uids: [premium_uid, ultimate_uid])
        create_list(:ci_runner, 2, allowed_plan_name_uids: [free_uid, bronze_uid])
      end

      it 'deduplicates and creates two matchers' do
        expect(matchers.size).to eq(2)

        expect(matchers.map(&:allowed_plan_name_uids)).to match_array(
          [
            [premium_uid, ultimate_uid],
            [free_uid, bronze_uid]
          ]
        )
      end
    end
  end

  describe '#compute_token_expiration', :freeze_time do
    subject(:compute_token_expiration) { runner.compute_token_expiration }

    context 'when explicit_token_expires_at is set' do
      let(:runner) { build(:ci_runner) }
      let(:explicit_expiration) { 2.days.from_now }

      before do
        stub_application_setting(runner_token_expiration_interval: 5.days.to_i)

        runner.explicit_token_expires_at = explicit_expiration
      end

      it 'returns the explicit expiration' do
        is_expected.to eq(explicit_expiration)
      end

      context 'when use_explicit is false' do
        subject(:compute_token_expiration) { runner.compute_token_expiration(use_explicit: false) }

        it 'returns the configured expiration when use_explicit is false' do
          is_expected.to eq(5.days.from_now)
        end
      end
    end

    context 'when explicit_token_expires_at is nil' do
      context 'with instance runner' do
        let(:runner) { build(:ci_runner) }

        before do
          stub_application_setting(runner_token_expiration_interval: 5.days.to_i)
        end

        it 'computes the instance expiration' do
          is_expected.to eq(5.days.from_now)
        end
      end

      context 'with group runner' do
        let_it_be_with_reload(:group_settings) do
          create(:namespace_settings, runner_token_expiration_interval: 6.days.to_i)
        end

        let_it_be_with_reload(:group_with_expiration) { create(:group, namespace_settings: group_settings) }
        let(:runner) { build(:ci_runner, :group, groups: [group_with_expiration]) }

        it 'computes the group expiration' do
          is_expected.to eq(6.days.from_now)
        end
      end

      context 'with project runner' do
        let_it_be(:project_with_expiration) { create(:project, runner_token_expiration_interval: 4.days.to_i) }
        let(:runner) { build(:ci_runner, :project, projects: [project_with_expiration]) }

        it 'computes the project expiration' do
          is_expected.to eq(4.days.from_now)
        end
      end
    end

    context 'when token has been reset' do
      let(:runner) { build(:ci_runner) }
      let(:explicit_expiration) { 2.days.from_now }

      before do
        stub_application_setting(runner_token_expiration_interval: 5.days.to_i)

        runner.explicit_token_expires_at = explicit_expiration
        runner.reset_token!
        runner.explicit_token_expires_at = nil
      end

      it 'falls back to the computed expiration' do
        expect(runner.compute_token_expiration).to eq(5.days.from_now)
      end
    end
  end
end
