# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflow::RunnerValidator, feature_category: :duo_agent_platform do
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, namespace: group) }

  describe '#valid?' do
    subject { described_class.new(runner, project).valid? }

    context 'with instance runner' do
      let(:runner) { create(:ci_runner, :instance) }

      it { is_expected.to be_truthy }
    end

    context 'with top level group runner' do
      let(:runner) { create(:ci_runner, :group, groups: [group]) }

      it { is_expected.to be_truthy }
    end

    context 'with subgroup runner' do
      let(:runner) { create(:ci_runner, :group, groups: [subgroup]) }

      it { is_expected.to be_falsey }
    end

    context 'with project runner' do
      let(:runner) { create(:ci_runner, :project, projects: [project]) }

      it { is_expected.to be_falsey }
    end

    context 'when duo_runner_restrictions is disabled' do
      before do
        stub_feature_flags(duo_runner_restrictions: false)
      end

      context 'with subgroup runner' do
        let(:runner) { create(:ci_runner, :group, groups: [subgroup]) }

        it { is_expected.to be_truthy }
      end

      context 'with project runner' do
        let(:runner) { create(:ci_runner, :project, projects: [project]) }

        it { is_expected.to be_truthy }
      end
    end
  end
end
