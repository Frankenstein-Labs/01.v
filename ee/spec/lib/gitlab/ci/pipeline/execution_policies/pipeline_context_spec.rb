# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::ExecutionPolicies::PipelineContext, feature_category: :security_policy_management do
  let(:sha_context) do
    Gitlab::Ci::Pipeline::ShaContext.new(
      before: command.before_sha,
      after: command.after_sha,
      source: command.source_sha,
      checkout: command.checkout_sha,
      target: command.target_sha
    )
  end

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let(:source) { 'push' }
  let(:pipeline) { build(:ci_pipeline, source: source, project: project, ref: 'master', user: user) }
  let(:bridge) { build_stubbed(:ci_bridge) }
  let(:trigger) { build_stubbed(:ci_trigger) }
  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(
      project: project, source: pipeline.source, current_user: user, origin_ref: pipeline.ref, bridge: bridge,
      trigger: trigger
    )
  end

  subject(:context) do
    described_class.new(
      project: project,
      source: command.source,
      current_user: command.current_user,
      ref: command.ref,
      sha_context: sha_context,
      variables_attributes: command.variables_attributes,
      chat_data: command.chat_data,
      merge_request: command.merge_request,
      schedule: command.schedule,
      trigger: trigger,
      bridge: command.bridge
    )
  end

  describe 'direct context access' do
    # With delegation removed, callers should now access pipeline_execution_context directly
    # These tests verify the context object is properly initialized
    it 'provides access to pipeline execution context' do
      expect(context.pipeline_execution_context).to be_a(
        ::Gitlab::Ci::Pipeline::PipelineExecutionPolicies::PipelineContext
      )
    end
  end

  describe '#pipeline_execution_context' do
    it 'initializes it with correct attributes' do
      expect(::Gitlab::Ci::Pipeline::PipelineExecutionPolicies::PipelineContext)
        .to receive(:new).with(
          context: context,
          project: project,
          source: command.source,
          current_user: command.current_user,
          ref: command.ref,
          sha_context: sha_context,
          variables_attributes: command.variables_attributes,
          chat_data: command.chat_data,
          merge_request: command.merge_request,
          schedule: command.schedule,
          trigger: command.trigger,
          is_parent_pipeline_policy: false
        )

      context.pipeline_execution_context
    end

    context 'when pipeline_execution_policy_context_block is provided' do
      let_it_be(:policy_management_project) { create(:project) }
      let_it_be(:policy_configuration) do
        create(:security_orchestration_policy_configuration,
          project: project,
          security_policy_management_project: policy_management_project)
      end

      let(:scheduled_policy_context) do
        build(:pipeline_execution_policy_config, :scheduled,
          policy_config: policy_configuration)
      end

      let(:block) { ->(args) { args.merge(current_policy: scheduled_policy_context) } }

      subject(:context) do
        described_class.new(
          project: project,
          source: command.source,
          current_user: command.current_user,
          ref: command.ref,
          sha_context: sha_context,
          variables_attributes: command.variables_attributes,
          chat_data: command.chat_data,
          merge_request: command.merge_request,
          schedule: command.schedule,
          trigger: command.trigger,
          bridge: command.bridge,
          pipeline_execution_policy_context_block: block
        )
      end

      it 'passes the modified args to the execution policy context' do
        expect(::Gitlab::Ci::Pipeline::PipelineExecutionPolicies::PipelineContext)
          .to receive(:new).with(hash_including(current_policy: scheduled_policy_context))

        context.pipeline_execution_context
      end
    end

    describe '#is_parent_pipeline_policy' do
      context 'when source is nil' do
        let(:source) { nil }

        it 'initializes it with correct attributes' do
          expect(::Gitlab::Ci::Pipeline::PipelineExecutionPolicies::PipelineContext)
            .to receive(:new).with(
              include(is_parent_pipeline_policy: false)
            )

          context.pipeline_execution_context
        end
      end

      context 'when source is parent_pipeline' do
        let(:source) { 'parent_pipeline' }

        it 'initializes it with correct attributes' do
          expect(::Gitlab::Ci::Pipeline::PipelineExecutionPolicies::PipelineContext)
            .to receive(:new).with(
              include(is_parent_pipeline_policy: false)
            )

          context.pipeline_execution_context
        end

        context 'when parent pipeline is a policy pipeline' do
          let(:build_source) { build_stubbed(:ci_build_source, source: 'pipeline_execution_policy') }
          let(:bridge) { build_stubbed(:ci_bridge, job_source: build_source) }

          it 'initializes it with correct attributes' do
            expect(::Gitlab::Ci::Pipeline::PipelineExecutionPolicies::PipelineContext)
              .to receive(:new).with(
                include(is_parent_pipeline_policy: true)
              )

            context.pipeline_execution_context
          end
        end

        context 'when parent pipeline is a scheduled execution policy pipeline' do
          let(:build_source) { build_stubbed(:ci_build_source, source: 'pipeline_execution_policy_schedule') }
          let(:bridge) { build_stubbed(:ci_bridge, job_source: build_source) }

          it 'initializes it with correct attributes' do
            expect(::Gitlab::Ci::Pipeline::PipelineExecutionPolicies::PipelineContext)
              .to receive(:new).with(
                include(is_parent_pipeline_policy: true)
              )

            context.pipeline_execution_context
          end
        end
      end
    end
  end

  describe '#scan_execution_context' do
    it 'is memoized by ref' do
      expect(::Gitlab::Ci::Pipeline::ScanExecutionPolicies::PipelineContext).to receive(:new).with(
        project: project, ref: 'refs/heads/master', current_user: user, source: 'push').exactly(:once).and_call_original
      expect(::Gitlab::Ci::Pipeline::ScanExecutionPolicies::PipelineContext).to receive(:new).with(
        project: project, ref: 'refs/heads/main', current_user: user, source: 'push').exactly(:once).and_call_original

      2.times { context.scan_execution_context('refs/heads/master') }
      2.times { context.scan_execution_context('refs/heads/main') }
    end
  end

  describe '#skip_ci_allowed?' do
    subject { context.skip_ci_allowed?(ref: pipeline.ref) }

    it { is_expected.to be(true) }

    context 'when there are pipeline execution policies' do
      before do
        allow(context.pipeline_execution_context).to receive(:skip_ci_allowed?).and_return(allowed)
      end

      context 'when they disallow skip_ci' do
        let(:allowed) { false }

        it { is_expected.to be(false) }
      end

      context 'when they allow skip_ci' do
        let(:allowed) { true }

        it { is_expected.to be(true) }
      end
    end

    context 'when there are scan execution policies' do
      let(:skip_allowed) { true }

      before do
        scan_execution_context_double =
          instance_double(::Gitlab::Ci::Pipeline::ScanExecutionPolicies::PipelineContext,
            skip_ci_allowed?: skip_allowed)
        allow(context).to receive(:scan_execution_context).with(pipeline.ref).and_return(scan_execution_context_double)
      end

      context 'when they are allowed to be skipped' do
        let(:skip_allowed) { true }

        it { is_expected.to be(true) }
      end

      context 'when they are not allowed to be skipped' do
        let(:skip_allowed) { false }

        it { is_expected.to be(false) }
      end
    end
  end

  describe '#no_pipeline_allowed?' do
    subject { context.no_pipeline_allowed?(ref: pipeline.ref) }

    it { is_expected.to be(true) }

    context 'when there are pipeline execution policies' do
      before do
        allow(context.pipeline_execution_context).to receive(:no_pipeline_allowed?).and_return(allowed)
      end

      context 'when they disallow no_pipeline' do
        let(:allowed) { false }

        it { is_expected.to be(false) }
      end

      context 'when they allow no_pipeline' do
        let(:allowed) { true }

        it { is_expected.to be(true) }
      end
    end

    context 'when there are scan execution policies' do
      let(:no_pipeline_allowed) { true }

      before do
        scan_execution_context_double =
          instance_double(::Gitlab::Ci::Pipeline::ScanExecutionPolicies::PipelineContext,
            no_pipeline_allowed?: no_pipeline_allowed)
        allow(context).to receive(:scan_execution_context).with(pipeline.ref).and_return(scan_execution_context_double)
      end

      context 'when they are allowed to be not created' do
        let(:no_pipeline_allowed) { true }

        it { is_expected.to be(true) }
      end

      context 'when they are not allowed to be not created' do
        let(:no_pipeline_allowed) { false }

        it { is_expected.to be(false) }
      end
    end
  end

  describe '#job_options' do
    subject { context.job_options(ref: pipeline.ref, job_name: 'test-job') }

    it { is_expected.to be_nil }

    context 'when there are pipeline execution policies' do
      before do
        allow(context.pipeline_execution_context).to receive(:job_options)
          .and_return({ name: 'Policy', project_id: 123, sha: 'sha' })
      end

      it { is_expected.to eq(name: 'Policy', project_id: 123, sha: 'sha') }
    end

    context 'when there are scan execution policies' do
      before do
        scan_execution_context_double =
          instance_double(::Gitlab::Ci::Pipeline::ScanExecutionPolicies::PipelineContext,
            job_options: { name: 'Policy', project_id: 123, sha: 'sha' })
        allow(context).to receive(:scan_execution_context).with(pipeline.ref).and_return(scan_execution_context_double)
      end

      it { is_expected.to eq(name: 'Policy', project_id: 123, sha: 'sha') }
    end
  end
end
