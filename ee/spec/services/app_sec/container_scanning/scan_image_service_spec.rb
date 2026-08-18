# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AppSec::ContainerScanning::ScanImageService, feature_category: :software_composition_analysis do
  let_it_be(:bot_user) { create(:user, :security_policy_bot) }
  let_it_be(:project) { create(:project, :small_repo, developers: bot_user) }

  let(:project_id) { project.id }
  let(:image) { "registry.gitlab.com/gitlab-org/security-products/dast/webgoat-8.0@test:latest" }

  before do
    allow(Gitlab::ApplicationRateLimiter).to receive(:throttled_request?).and_return(false)
  end

  shared_examples 'creates a throttled log entry' do
    it do
      expect(Gitlab::AppJsonLogger).to receive(:info).with(
        a_hash_including(
          class: described_class.name,
          project_id: project_id,
          image: image,
          scan_type: :container_scanning,
          pipeline_source: described_class::SOURCE,
          limit_type: :container_scanning_for_registry_scans,
          message: 'Daily rate limit container_scanning_for_registry_scans reached'
        )
      )

      execute
    end
  end

  shared_examples 'does not creates a throttled log entry' do
    it do
      expect(Gitlab::AppJsonLogger).not_to receive(:info)

      execute
    end
  end

  describe '#pipeline_config' do
    subject(:pipeline_config) do
      described_class.new(
        image: image,
        project_id: project_id
      ).pipeline_config
    end

    it 'generates a valid yaml ci config' do
      lint = Gitlab::Ci::Lint.new(project: project, current_user: bot_user)
      result = lint.legacy_validate(pipeline_config)

      expect(result).to be_valid
    end
  end

  describe '#execute' do
    subject(:execute) do
      described_class.new(
        image: image,
        project_id: project_id
      ).execute
    end

    context 'when a project is not present' do
      let(:project_id) { nil }

      it { is_expected.to be_nil }

      it_behaves_like 'does not creates a throttled log entry'
    end

    context 'with a valid project' do
      let(:pipeline) { execute.payload }
      let(:build) { pipeline.builds.find_by(name: :container_scanning) }

      it 'creates a pipeline' do
        expect { execute }.to change { Ci::Pipeline.count }.by(1)
      end

      it 'does not create a throttled log entry' do
        # We expect some logs from Gitlab::Ci::Pipeline::CommandLogger,
        # but no logs from create_throttled_log_entry
        expect(Gitlab::AppJsonLogger).to receive(:info).with(
          hash_including("class" => "Gitlab::Ci::Pipeline::CommandLogger")
        )

        execute
      end

      it_behaves_like 'internal event tracking' do
        let(:event) { 'container_scanning_for_registry_pipeline' }
        let(:additional_properties) do
          {
            property: 'success'
          }
        end

        let(:user) { bot_user }
      end

      it 'sets correct artifacts configuration' do
        expect(build.options[:artifacts]).to eq({
          paths: ["**/gl-sbom-*.cdx.json"],
          access: "developer",
          reports: {
            cyclonedx: ["**/gl-sbom-*.cdx.json"],
            container_scanning: []
          }
        })
      end

      it 'sets correct environment variables' do
        expect(build.yaml_variables).to include(
          { key: "GIT_STRATEGY", value: "none" },
          { key: "REGISTRY_TRIGGERED", value: "true" },
          { key: "CS_IMAGE", value: image }
        )
      end

      context 'when the pipeline creation fails' do
        let(:fake_pipeline) do
          instance_double(Ci::Pipeline, created_successfully?: false, full_error_messages: 'full error messages')
        end

        let(:fake_service) do
          instance_double(Ci::CreatePipelineService,
            execute: ServiceResponse.error(message: 'error message', payload: fake_pipeline))
        end

        before do
          allow(Ci::CreatePipelineService).to receive(:new).and_return(fake_service)
        end

        it 'logs an error with the failure message' do
          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
            a_kind_of(StandardError),
            hash_including(
              class: described_class.name,
              project_id: project_id,
              message: /Failed to create pipeline: full error messages/
            )
          )

          execute
        end
      end
    end

    context 'when the project has exceeded the daily scan limit' do
      before do
        allow(Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_return(true)
      end

      it { is_expected.to be_nil }

      it_behaves_like 'creates a throttled log entry'
    end

    context 'when the project does not have a security policy bot' do
      let_it_be(:project) { create(:project, :small_repo) }

      context 'when it fails to create the security bot' do
        before do
          allow(Security::Orchestration::CreateBotService).to receive_message_chain(:new,
            :execute).and_raise(Gitlab::Access::AccessDeniedError)
        end

        it 'logs the error with its respective details' do
          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
            a_kind_of(Gitlab::Access::AccessDeniedError),
            hash_including(class: described_class.name, project_id: project.id,
              message: /Gitlab::Access::AccessDeniedError/)
          )

          execute
        end

        it 'does not attempt to create a pipeline' do
          expect(Ci::CreatePipelineService).not_to receive(:new)
          expect { execute }.not_to change { Ci::Pipeline.count }
        end
      end

      context 'when creating the security bot returns no user' do
        before do
          allow(Security::Orchestration::CreateBotService).to receive_message_chain(:new,
            :execute).and_return(instance_double(ProjectMember, user: nil))
        end

        it 'logs the error with its respective details' do
          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
            a_kind_of(StandardError),
            hash_including(class: described_class.name, project_id: project.id,
              message: /Security Orchestration Bot was not created/)
          )

          execute
        end
      end

      it 'creates the security policy bot' do
        expect(Security::Orchestration::CreateBotService).to receive(:new)
                  .with(project, nil, skip_authorization: true).and_call_original
        expect(Gitlab::ErrorTracking).not_to receive(:track_exception)

        execute
      end
    end
  end
end
