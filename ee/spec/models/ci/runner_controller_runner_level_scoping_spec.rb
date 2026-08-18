# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::RunnerControllerRunnerLevelScoping, feature_category: :continuous_integration do
  describe 'associations' do
    subject { build(:ci_runner_controller_runner_level_scoping) }

    it 'belongs to runner_controller' do
      is_expected.to belong_to(:runner_controller).class_name('Ci::RunnerController')
                                                  .inverse_of(:runner_level_scopings)
                                                  .optional(false)
    end

    it 'belongs to runner' do
      is_expected.to belong_to(:runner).class_name('Ci::Runner')
                                       .inverse_of(:runner_controller_runner_level_scopings)
                                       .optional(false)
    end
  end

  describe 'validations' do
    subject { build(:ci_runner_controller_runner_level_scoping, runner_type: 'instance_type') }

    it { is_expected.to validate_uniqueness_of(:runner_controller_id).scoped_to(:runner_id, :runner_type) }

    describe '.for_runner' do
      let_it_be(:runner1) { create(:ci_runner, :instance) }
      let_it_be(:runner2) { create(:ci_runner, :instance) }
      let_it_be(:scoping1) { create(:ci_runner_controller_runner_level_scoping, runner: runner1) }
      let_it_be(:scoping2) { create(:ci_runner_controller_runner_level_scoping, runner: runner2) }

      it 'returns scopings for the specified runner' do
        expect(described_class.for_runner(runner1.id)).to contain_exactly(scoping1)
      end

      it 'returns empty when no scopings exist for the runner' do
        expect(described_class.for_runner(non_existing_record_id)).to be_empty
      end
    end

    describe 'runner_must_be_instance_type' do
      let_it_be(:instance_runner) { create(:ci_runner, :instance) }
      let_it_be(:group) { create(:group) }
      let_it_be(:group_runner) { create(:ci_runner, :group, groups: [group]) }

      context 'when runner is instance type' do
        subject(:scoping) { build(:ci_runner_controller_runner_level_scoping, runner: instance_runner) }

        it { is_expected.to be_valid }
      end

      context 'when runner is not instance type' do
        subject(:scoping) { build(:ci_runner_controller_runner_level_scoping, runner: group_runner) }

        it 'is invalid' do
          expect(scoping).not_to be_valid
          expect(scoping.errors[:runner]).to include('must be an instance-type runner')
        end
      end
    end
  end

  describe '#set_runner_type' do
    let_it_be(:runner) { create(:ci_runner, :instance) }

    context 'when runner_type is not set' do
      let(:runner_level_scoping) { build(:ci_runner_controller_runner_level_scoping, runner: runner) }

      it 'sets runner_type from the runner' do
        expect { runner_level_scoping.valid? }.to change { runner_level_scoping.runner_type }.to('instance_type')
      end
    end

    context('when it is already set') do
      let(:runner_level_scoping) { build(:ci_runner_controller_runner_level_scoping, runner_type: :instance_type) }

      it 'does not change the runner_type value' do
        expect { runner_level_scoping.valid? }.not_to change { runner_level_scoping.runner_type }
      end
    end
  end
end
