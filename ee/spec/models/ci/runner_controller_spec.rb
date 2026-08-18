# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::RunnerController, feature_category: :continuous_integration do
  describe 'validations' do
    subject { build(:ci_runner_controller) }

    it { is_expected.to validate_length_of(:description).is_at_most(1024) }
  end

  describe 'associations' do
    subject { build(:ci_runner_controller) }

    it { is_expected.to have_many(:tokens).class_name('Ci::RunnerControllerToken').inverse_of(:runner_controller) }

    it 'has one instance_level_scoping' do
      is_expected.to have_one(:instance_level_scoping).class_name('Ci::RunnerControllerInstanceLevelScoping')
                                                .inverse_of(:runner_controller)
    end

    it 'has many runner_level_scopings' do
      is_expected.to have_many(:runner_level_scopings).class_name('Ci::RunnerControllerRunnerLevelScoping')
                                               .inverse_of(:runner_controller)
    end

    context 'when runner controller has multiple instance-type runner controller scopings' do
      let_it_be(:runner_controller) { create(:ci_runner_controller) }
      let_it_be(:instance_runner_1) { create(:ci_runner, :instance) }
      let_it_be(:instance_runner_2) { create(:ci_runner, :instance) }
      let_it_be(:instance_runner_scoping_1) do
        create(:ci_runner_controller_runner_level_scoping,
          runner_controller: runner_controller,
          runner: instance_runner_1)
      end

      let_it_be(:instance_runner_scoping_2) do
        create(:ci_runner_controller_runner_level_scoping,
          runner_controller: runner_controller,
          runner: instance_runner_2)
      end

      it 'returns all associated runner-level scopings' do
        expect(runner_controller.runner_level_scopings).to contain_exactly(
          instance_runner_scoping_1,
          instance_runner_scoping_2
        )
      end
    end
  end

  describe 'state enum' do
    it 'defines the correct states' do
      expect(described_class.states).to eq(
        'disabled' => 0,
        'enabled' => 1,
        'dry_run' => 2
      )
    end

    it 'defaults to disabled' do
      controller = described_class.new

      expect(controller.state).to eq('disabled')
      expect(controller).to be_disabled
    end

    it 'can be set to enabled' do
      controller = build(:ci_runner_controller, state: :enabled)

      expect(controller.state).to eq('enabled')
      expect(controller).to be_enabled
    end

    it 'can be set to dry_run' do
      controller = build(:ci_runner_controller, state: :dry_run)

      expect(controller.state).to eq('dry_run')
      expect(controller).to be_dry_run
    end
  end

  describe 'scopes' do
    let_it_be(:enabled_controller) { create(:ci_runner_controller, :enabled) }
    let_it_be(:disabled_controller) { create(:ci_runner_controller) }
    let_it_be(:dry_run_controller) { create(:ci_runner_controller, :dry_run) }

    describe '.enabled' do
      subject(:enabled) { described_class.enabled }

      it 'returns only enabled runner controllers' do
        is_expected.to contain_exactly(enabled_controller)
      end
    end

    describe '.disabled' do
      subject(:disabled) { described_class.disabled }

      it 'returns only disabled runner controllers' do
        is_expected.to contain_exactly(disabled_controller)
      end
    end

    describe '.dry_run' do
      subject(:dry_run) { described_class.dry_run }

      it 'returns only dry_run runner controllers' do
        is_expected.to contain_exactly(dry_run_controller)
      end
    end

    describe '.active' do
      subject(:active) { described_class.active }

      context 'when controllers in different states exist' do
        it 'returns enabled and dry_run runner controllers' do
          is_expected.to contain_exactly(enabled_controller, dry_run_controller)
        end
      end

      context 'when no active controllers exist' do
        before do
          described_class.active.delete_all
        end

        it 'returns empty collection' do
          is_expected.to be_empty
        end
      end
    end

    describe '.with_instance_scope' do
      subject(:with_instance_scope) { described_class.with_instance_scope }

      context 'when no controllers have instance-level scope' do
        it 'returns empty collection' do
          is_expected.to be_empty
        end
      end

      context 'when some controllers have instance-level scope' do
        before do
          create(:ci_runner_controller_instance_level_scoping, runner_controller: enabled_controller)
          create(:ci_runner_controller_instance_level_scoping, runner_controller: disabled_controller)
        end

        it 'returns only controllers with instance-level scope' do
          is_expected.to contain_exactly(enabled_controller, disabled_controller)
        end
      end

      context 'when combined with active scope' do
        let_it_be(:scoped_enabled) { create(:ci_runner_controller, :enabled) }
        let_it_be(:scoped_disabled) { create(:ci_runner_controller, :disabled) }
        let_it_be(:unscoped_enabled) { create(:ci_runner_controller, :enabled) }

        before do
          create(:ci_runner_controller_instance_level_scoping, runner_controller: scoped_enabled)
          create(:ci_runner_controller_instance_level_scoping, runner_controller: scoped_disabled)
        end

        it 'returns only active controllers with instance-level scope' do
          expect(described_class.active.with_instance_scope).to contain_exactly(scoped_enabled)
        end
      end
    end

    describe '.with_runner_scoping_for' do
      let_it_be(:instance_runner) { create(:ci_runner, :instance) }
      let_it_be(:other_runner) { create(:ci_runner, :instance) }

      subject(:with_runner_scoping_for) { described_class.with_runner_scoping_for(instance_runner.id) }

      context 'when no controllers have runner-level scope for the runner' do
        it 'returns empty collection' do
          is_expected.to be_empty
        end
      end

      context 'when some controllers have runner-level scope for the runner' do
        before do
          create(:ci_runner_controller_runner_level_scoping,
            runner_controller: enabled_controller,
            runner: instance_runner)
          create(:ci_runner_controller_runner_level_scoping,
            runner_controller: disabled_controller,
            runner: other_runner)
        end

        it 'returns only controllers with runner-level scope for the specified runner' do
          is_expected.to contain_exactly(enabled_controller)
        end
      end
    end

    describe '.applicable_for' do
      let_it_be(:instance_runner) { create(:ci_runner, :instance) }
      let_it_be(:other_runner) { create(:ci_runner, :instance) }

      subject(:applicable_for) { described_class.applicable_for(instance_runner) }

      context 'when no controllers have any scoping' do
        it 'returns empty collection' do
          is_expected.to be_empty
        end
      end

      context 'when controllers have instance-level scope' do
        let_it_be(:instance_scoped_enabled) { create(:ci_runner_controller, :enabled) }
        let_it_be(:instance_scoped_disabled) { create(:ci_runner_controller, :disabled) }

        before do
          create(:ci_runner_controller_instance_level_scoping, runner_controller: instance_scoped_enabled)
          create(:ci_runner_controller_instance_level_scoping, runner_controller: instance_scoped_disabled)
        end

        it 'returns only active controllers with instance-level scope' do
          is_expected.to contain_exactly(instance_scoped_enabled)
        end
      end

      context 'when controllers have runner-level scope' do
        let_it_be(:runner_scoped_enabled) { create(:ci_runner_controller, :enabled) }
        let_it_be(:runner_scoped_disabled) { create(:ci_runner_controller, :disabled) }
        let_it_be(:other_runner_scoped) { create(:ci_runner_controller, :enabled) }

        before do
          create(:ci_runner_controller_runner_level_scoping,
            runner_controller: runner_scoped_enabled,
            runner: instance_runner)
          create(:ci_runner_controller_runner_level_scoping,
            runner_controller: runner_scoped_disabled,
            runner: instance_runner)
          create(:ci_runner_controller_runner_level_scoping,
            runner_controller: other_runner_scoped,
            runner: other_runner)
        end

        it 'returns only active controllers with runner-level scope for the specified runner' do
          is_expected.to contain_exactly(runner_scoped_enabled)
        end
      end

      context 'when controllers have mixed scoping types' do
        let_it_be(:instance_scoped) { create(:ci_runner_controller, :enabled) }
        let_it_be(:runner_scoped) { create(:ci_runner_controller, :enabled) }
        let_it_be(:unscoped) { create(:ci_runner_controller, :enabled) }

        before do
          create(:ci_runner_controller_instance_level_scoping, runner_controller: instance_scoped)
          create(:ci_runner_controller_runner_level_scoping,
            runner_controller: runner_scoped,
            runner: instance_runner)
        end

        it 'returns controllers with either instance-level or runner-level scope for the runner' do
          is_expected.to contain_exactly(instance_scoped, runner_scoped)
        end

        it 'does not return unscoped controllers' do
          expect(applicable_for).not_to include(unscoped)
        end
      end
    end
  end

  describe '#connected?' do
    subject(:connected?) { runner_controller.connected? }

    let_it_be(:runner_controller) { create(:ci_runner_controller) }

    context 'when no tokens exist' do
      it { is_expected.to be false }
    end

    context 'when an active token was used recently' do
      before do
        create(:ci_runner_controller_token, :recently_used, runner_controller: runner_controller)
      end

      it { is_expected.to be true }
    end

    context 'when an active token was used longer ago than INACTIVE_AFTER' do
      before do
        create(:ci_runner_controller_token, :not_recently_used, runner_controller: runner_controller)
      end

      it { is_expected.to be false }
    end

    context 'when a revoked token was used recently' do
      before do
        create(:ci_runner_controller_token, :revoked, :recently_used, runner_controller: runner_controller)
      end

      it { is_expected.to be false }
    end

    context 'when token has never been used' do
      before do
        create(:ci_runner_controller_token, :unused, runner_controller: runner_controller)
      end

      it { is_expected.to be false }
    end

    context 'when multiple tokens exist with mixed usage' do
      before do
        create(:ci_runner_controller_token, :not_recently_used, runner_controller: runner_controller)
        create(:ci_runner_controller_token, :recently_used, runner_controller: runner_controller)
      end

      it { is_expected.to be true }
    end
  end
end
