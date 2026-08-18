# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::Chain::SetBuildSources, feature_category: :security_policy_management do
  include RepoHelpers

  let(:opts) { {} }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :small_repo, group: group) }
  let_it_be(:user) { create(:user, developer_of: [project]) }

  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(
      project: project,
      current_user: user,
      origin_ref: 'master'
    )
  end

  let(:pipeline) { build(:ci_pipeline, project: project) }

  subject(:perform) do
    described_class.new(pipeline, command).perform!
  end

  describe '#perform!' do
    let(:pipeline_seed) do
      pipeline_seed = instance_double(Gitlab::Ci::Pipeline::Seed::Pipeline)
      allow(pipeline_seed).to receive(:stages).and_return(
        [
          instance_double(Ci::Stage, statuses: [
            build_double(name: "build", options: {}),
            build_double(name: "namespace_policy_job", options: { policy: { name: 'Policy 1' } })
          ]),
          instance_double(Ci::Stage, statuses: [
            build_double(name: "rspec", options: {}),
            build_double(name: "secret-detection-0", options: {}),
            build_double(name: "project_policy_job", options: { policy: { name: 'Policy 2' } }),
            build_double(name: "secret-detection-1", options: { policy: { name: 'Policy 3' } }),
            build_double(name: "arbitrary-job-name", options: {})
          ])
        ]
      )
      pipeline_seed
    end

    before do
      allow(command).to receive(:pipeline_seed).and_return(pipeline_seed)
    end

    context 'with security policy' do
      let(:pipeline_execution_context) do
        instance_double(::Gitlab::Ci::Pipeline::PipelineExecutionPolicies::PipelineContext)
      end

      let(:scan_execution_context) do
        instance_double(::Gitlab::Ci::Pipeline::ScanExecutionPolicies::PipelineContext)
      end

      it 'sets correct build and pipeline source for jobs' do
        expected_sources = {
          "build" => pipeline.source,
          "namespace_policy_job" => "pipeline_execution_policy",
          "rspec" => pipeline.source,
          "secret-detection-0" => "scan_execution_policy",
          "project_policy_job" => "pipeline_execution_policy",
          "secret-detection-1" => "pipeline_execution_policy",
          "arbitrary-job-name" => "scan_execution_policy"
        }

        expect(command.pipeline_policy_context).to receive(:scan_execution_context)
          .with(pipeline.source_ref_path)
          .at_least(:once)
          .and_return(scan_execution_context)

        expect(command.pipeline_policy_context).to receive(:pipeline_execution_context)
          .at_least(:once)
          .and_return(pipeline_execution_context)

        allow(pipeline_execution_context).to receive(:creating_policy_pipeline?)
          .exactly(7).times
          .and_return(false, true, false, false, true, true, false)

        pipeline_seed.stages.flat_map(&:statuses).each do |build|
          allow(scan_execution_context).to receive(:job_injected?)
            .with(build.name)
            .and_return(expected_sources[build.name] == "scan_execution_policy")

          expect(build).to receive(:build_job_source).with(
            source: expected_sources[build.name],
            project_id: project.id
          )
        end

        perform
      end
    end

    context 'with security scan profile pipeline' do
      let(:pipeline) { build(:ci_pipeline, project: project, config_source: :security_scan_profiles_source) }

      let(:pipeline_seed) do
        seed = instance_double(Gitlab::Ci::Pipeline::Seed::Pipeline)
        allow(seed).to receive(:stages).and_return(
          [
            instance_double(Ci::Stage, statuses: [
              build_double(name: "sast-0", options: {}),
              build_double(name: "secret-detection-0", options: {})
            ])
          ]
        )
        seed
      end

      let(:pipeline_execution_context) do
        instance_double(
          ::Gitlab::Ci::Pipeline::PipelineExecutionPolicies::PipelineContext,
          creating_policy_pipeline?: false
        )
      end

      let(:scan_execution_context) do
        instance_double(::Gitlab::Ci::Pipeline::ScanExecutionPolicies::PipelineContext)
      end

      before do
        allow(command.pipeline_policy_context).to receive_messages(
          pipeline_execution_context: pipeline_execution_context, scan_execution_context: scan_execution_context)
        allow(scan_execution_context).to receive(:job_injected?).and_return(false)
      end

      it 'sets security_scan_profiles source for all jobs' do
        perform

        builds = pipeline_seed.stages.flat_map(&:statuses)
        sources = builds.map { |b| b.job_source.source }

        expect(sources).to all(eq('security_scan_profiles'))
      end
    end

    context 'with a mixed pipeline (repository + profile-injected jobs)' do
      let(:pipeline) { build(:ci_pipeline, project: project, config_source: :repository_source) }

      let(:pipeline_seed) do
        seed = instance_double(Gitlab::Ci::Pipeline::Seed::Pipeline)
        allow(seed).to receive(:stages).and_return(
          [
            instance_double(Ci::Stage, statuses: [
              build_double(name: "build", options: {}),
              build_double(name: "rspec", options: {})
            ]),
            instance_double(Ci::Stage, statuses: [
              build_double(name: "sast-0", options: {}),
              build_double(name: "secret-detection-0", options: {})
            ])
          ]
        )
        seed
      end

      let(:pipeline_execution_context) do
        instance_double(
          ::Gitlab::Ci::Pipeline::PipelineExecutionPolicies::PipelineContext,
          creating_policy_pipeline?: false
        )
      end

      let(:scan_execution_context) do
        instance_double(::Gitlab::Ci::Pipeline::ScanExecutionPolicies::PipelineContext)
      end

      let(:scan_profile_context) do
        instance_double(::Gitlab::Ci::Pipeline::SecurityScanProfiles::PipelineContext)
      end

      before do
        allow(command.pipeline_policy_context).to receive_messages(
          pipeline_execution_context: pipeline_execution_context, scan_execution_context: scan_execution_context)
        allow(scan_execution_context).to receive(:job_injected?).and_return(false)
        allow(command).to receive(:scan_profile_context).and_return(scan_profile_context)
        allow(scan_profile_context).to receive(:job_injected?).with('sast-0').and_return(true)
        allow(scan_profile_context).to receive(:job_injected?).with('secret-detection-0').and_return(true)
        allow(scan_profile_context).to receive(:job_injected?).with('build').and_return(false)
        allow(scan_profile_context).to receive(:job_injected?).with('rspec').and_return(false)
      end

      it 'sets security_scan_profiles source only for profile-injected jobs' do
        perform

        builds = pipeline_seed.stages.flat_map(&:statuses)
        builds_by_name = builds.index_by(&:name)

        expect(builds_by_name['sast-0'].job_source.source).to eq('security_scan_profiles')
        expect(builds_by_name['secret-detection-0'].job_source.source).to eq('security_scan_profiles')
        expect(builds_by_name['build'].job_source.source).to eq(pipeline.source)
        expect(builds_by_name['rspec'].job_source.source).to eq(pipeline.source)
      end
    end

    context 'with a non-profile pipeline' do
      let(:pipeline) { build(:ci_pipeline, project: project, config_source: :repository_source) }

      let(:pipeline_execution_context) do
        instance_double(
          ::Gitlab::Ci::Pipeline::PipelineExecutionPolicies::PipelineContext,
          creating_policy_pipeline?: false
        )
      end

      let(:scan_execution_context) do
        instance_double(::Gitlab::Ci::Pipeline::ScanExecutionPolicies::PipelineContext)
      end

      let(:scan_profile_context) do
        instance_double(::Gitlab::Ci::Pipeline::SecurityScanProfiles::PipelineContext)
      end

      before do
        allow(command.pipeline_policy_context).to receive_messages(
          pipeline_execution_context: pipeline_execution_context, scan_execution_context: scan_execution_context)
        allow(scan_execution_context).to receive(:job_injected?).and_return(false)
        allow(command).to receive(:scan_profile_context).and_return(scan_profile_context)
        allow(scan_profile_context).to receive(:job_injected?).and_return(false)
      end

      it 'does not set security_scan_profiles source' do
        perform

        builds = pipeline_seed.stages.flat_map(&:statuses)
        sources = builds.map { |b| b.job_source.source }

        expect(sources).to all(eq(pipeline.source))
      end
    end
  end

  private

  def build_double(**args)
    build = instance_double(::Ci::Build, args[:name], **args, job_source: nil)
    allow(build).to receive(:build_job_source) do |source:, project_id:|
      job_source = instance_double(Ci::BuildSource, source: source, project_id: project_id)
      allow(build).to receive(:job_source).and_return(job_source)
    end
    build
  end
end
