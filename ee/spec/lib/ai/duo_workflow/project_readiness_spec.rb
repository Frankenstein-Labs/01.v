# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflow::ProjectReadiness, feature_category: :duo_agent_platform do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }

  let(:readiness) { described_class.new(project) }

  describe '#platform_enabled?' do
    subject { readiness.platform_enabled? }

    it 'reports whether the Agent Platform is on above this project' do
      allow(::Ai::DuoWorkflow).to receive(:duo_agent_platform_available?).with(project).and_return(true)

      is_expected.to be(true)
    end

    it 'is false when the platform is off' do
      allow(::Ai::DuoWorkflow).to receive(:duo_agent_platform_available?).with(project).and_return(false)

      is_expected.to be(false)
    end

    # The self-managed path re-reads the Ai::Setting singleton on every call.
    it 'is read once' do
      expect(::Ai::DuoWorkflow).to receive(:duo_agent_platform_available?).once.and_return(true)

      3.times { readiness.platform_enabled? }
    end
  end

  describe '#runner_available?' do
    subject { readiness.runner_available? }

    let(:workload_tag) { ::Ai::DuoWorkflows::Workflow::WORKLOAD_TAG }

    def create_duo_runner(*traits, **runner_args)
      create(:ci_runner, :online, *traits, tag_list: [workload_tag], **runner_args).tap do |runner|
        create(:ci_runner_machine, runner: runner, executor_type: :docker)
      end
    end

    context 'with an online, Duo-tagged instance runner on a Docker executor' do
      before do
        create_duo_runner(:instance)
      end

      it { is_expected.to be(true) }
    end

    it 'is false when no runner carries the workload tag' do
      runner = create(:ci_runner, :instance, :online, tag_list: %w[some-other-tag])
      create(:ci_runner_machine, runner: runner, executor_type: :docker)

      is_expected.to be(false)
    end

    it 'is false when the only tagged runner is paused' do
      create_duo_runner(:instance, :paused)

      is_expected.to be(false)
    end

    it 'is false when the only tagged runner has stopped checking in' do
      create_duo_runner(:instance, :offline)

      is_expected.to be(false)
    end

    it 'is false when the runner has no Docker-compatible executor' do
      runner = create(:ci_runner, :instance, :online, tag_list: [workload_tag])
      create(:ci_runner_machine, runner: runner, executor_type: :shell)

      is_expected.to be(false)
    end

    it 'is false when the runner never registered a manager' do
      create(:ci_runner, :instance, :online, tag_list: [workload_tag])

      is_expected.to be(false)
    end

    context 'when the only tagged runner is a project runner' do
      before do
        create_duo_runner(:project, projects: [project])
      end

      it { is_expected.to be(false) }

      context 'when duo_runner_restrictions is disabled' do
        before do
          stub_feature_flags(duo_runner_restrictions: false)
        end

        it { is_expected.to be(true) }
      end
    end

    context 'with a top-level group runner' do
      before do
        create_duo_runner(:group, groups: [group])
      end

      it { is_expected.to be(true) }
    end

    it 'looks the runner up once, however many readers ask' do
      expect(project).to receive(:all_available_runners).once.and_call_original

      readiness.runner_available?
      readiness.runner_available?
      readiness.usable_runner_type
    end
  end

  describe '#usable_runner_type' do
    subject { readiness.usable_runner_type }

    let(:workload_tag) { ::Ai::DuoWorkflows::Workflow::WORKLOAD_TAG }

    def create_duo_runner(*traits, **runner_args)
      create(:ci_runner, :online, *traits, tag_list: [workload_tag], **runner_args).tap do |runner|
        create(:ci_runner_machine, runner: runner, executor_type: :docker)
      end
    end

    it 'is instance_type for an instance runner' do
      create_duo_runner(:instance)

      is_expected.to eq('instance_type')
    end

    it 'is group_type for a top-level group runner' do
      create_duo_runner(:group, groups: [group])

      is_expected.to eq('group_type')
    end

    context 'when duo_runner_restrictions is disabled, so project runners count too' do
      before do
        stub_feature_flags(duo_runner_restrictions: false)
      end

      it 'is project_type for a project runner' do
        create_duo_runner(:project, projects: [project])

        is_expected.to eq('project_type')
      end
    end

    it 'is nil when nothing qualifies' do
      is_expected.to be_nil
    end
  end
end
