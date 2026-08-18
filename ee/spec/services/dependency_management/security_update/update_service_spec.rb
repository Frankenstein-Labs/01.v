# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyManagement::SecurityUpdate::UpdateService, feature_category: :dependency_management do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:project) { create(:project, :small_repo, organization: organization) }

  let(:vulnerability) do
    create(:vulnerability, :with_finding, :detected, project: project, report_type: :dependency_scanning)
  end

  let(:sbom_occurrence) do
    create(:sbom_occurrence,
      project: project,
      package_manager: 'bundler',
      input_file_path: 'Gemfile',
      component_name: 'rails'
    ).tap do |occurrence|
      occurrence.component_version.update!(version: '6.0.0')
    end
  end

  let(:security_update) do
    DependencyManagement::SecurityUpdate::Request.new(
      sbom_occurrence: sbom_occurrence,
      vulnerability: vulnerability,
      target_ref: project.default_branch
    )
  end

  let(:service) { described_class.new(project: project) }

  # Convenience helpers to avoid repeating the same pipeline/build/vars chain
  def pipeline_from(response)
    response.payload[:pipeline]
  end

  def build_from(response)
    pipeline_from(response).builds.first
  end

  def variables_from(response)
    build_from(response).variables
  end

  def variable_value(response, key)
    variables_from(response).find { |v| v.key == key }&.value
  end

  before do
    stub_ee_application_setting(
      allow_top_level_group_owners_to_create_service_accounts: true
    )
  end

  describe '#execute' do
    subject(:execute) { service.execute(security_update) }

    context 'when project cannot store security reports' do
      before do
        allow(project).to receive(:can_store_security_reports?).and_return(false)
      end

      it 'returns an error response' do
        expect(execute).to be_error
        expect(execute.message).to eq('Automated dependency security updates not enabled')
      end
    end

    context 'when security_update is nil' do
      let(:security_update) { nil }

      before do
        allow(project).to receive(:can_store_security_reports?).and_return(true)
      end

      it 'returns an error response' do
        expect(execute).to be_error
        expect(execute.message).to eq('Security Update Request not found')
      end
    end

    context 'when project can store security reports' do
      before do
        allow(project).to receive(:can_store_security_reports?).and_return(true)
      end

      it 'creates a pipeline using the dependency management service account' do
        response = execute

        expect(response).to be_success
        expect(pipeline_from(response)).to be_a(Ci::Pipeline)
        expect(pipeline_from(response).user).to be_service_account
      end

      it 'sets the correct pipeline attributes' do
        pipeline = pipeline_from(execute)

        expect(pipeline.project).to eq(project)
        expect(pipeline.source).to eq('dependency_management_security_update')
        expect(pipeline.ref).to eq("dependency-management/rails-6.x")
      end

      it 'creates a build with the orchestrator image' do
        expect(build_from(execute).image.name).to eq(
          'registry.gitlab.com/security-products/dependency-management/orchestrator:0'
        )
      end

      it 'sets commands to write job file and invoke the orchestrator' do
        script = build_from(execute).options[:script]

        expect(script).to include(a_string_matching(%r{echo .* > /tmp/dependency-update-job\.json}))
        expect(script).to include(
          'dependency-management-orchestrator update --job-file /tmp/dependency-update-job.json'
        )
      end

      it 'exposes output.json as an artifact' do
        artifacts = build_from(execute).options[:artifacts]

        expect(artifacts).to eq({ paths: ['output.json'] })
      end

      it 'sets the expected environment variables' do
        vars = variables_from(execute)
        key_value_pairs = vars.pluck(:key, :value).to_h

        expect(key_value_pairs).to include(
          'DEPENDENCY_MANAGEMENT_PROJECT_PATH' => project.full_path,
          'DEPENDENCY_MANAGEMENT_TARGET_REF' => project.default_branch,
          'DEPENDENCY_MANAGEMENT_SOURCE_REF' => 'dependency-management/rails-6.x',
          'DEPENDENCY_MANAGEMENT_VULNERABILITY_ID' => vulnerability.id.to_s,
          'DOCKER_HOST' => 'tcp://docker:2376',
          'DOCKER_TLS_CERTDIR' => '/certs'
        )
      end

      it 'uses JobBuilder to generate the job configuration' do
        job_builder = instance_double(DependencyManagement::SecurityUpdate::JobBuilder, to_json: '{}')

        expect(DependencyManagement::SecurityUpdate::JobBuilder)
          .to receive(:new)
          .with(request: security_update, project: project, auto_remediation_configuration: {})
          .and_return(job_builder)

        execute
      end

      context 'when a remediation profile is configured for the project' do
        let_it_be_with_reload(:profile) do
          create(:security_scan_profile, :dependency_scanning_post_processing,
            namespace: project.namespace,
            projects: [project])
        end

        let_it_be(:trigger) do
          create(:security_scan_profile_trigger, scan_profile: profile, trigger_type: :sbom_ingested,
            configuration_values: { auto_remediation: { cooldown: 3, upgrade_policy: 'patch' } })
        end

        before do
          stub_licensed_features(security_scan_profiles: true)
        end

        it 'passes the auto remediation configuration to JobBuilder' do
          job_builder = instance_double(DependencyManagement::SecurityUpdate::JobBuilder, to_json: '{}')

          expect(DependencyManagement::SecurityUpdate::JobBuilder)
            .to receive(:new)
            .with(
              request: security_update,
              project: project,
              auto_remediation_configuration: {
                cooldown: 3,
                severity_level: 'high',
                upgrade_policy: 'patch',
                open_merge_requests_limit: 10,
                runner_tags: []
              }
            )
            .and_return(job_builder)

          execute
        end
      end

      context 'when workload service fails' do
        before do
          allow_next_instance_of(Ci::Workloads::RunWorkloadService) do |workload_service|
            allow(workload_service).to receive(:execute)
              .and_return(ServiceResponse.error(message: 'Workload creation failed'))
          end
        end

        it 'returns an error response' do
          expect(execute).to be_error
          expect(execute.message).to eq('Workload creation failed')
        end
      end

      context 'when dependency management service account already exists' do
        let_it_be(:existing_service_account) do
          create(:service_account,
            provisioned_by_project: project,
            organization: project.organization,
            name: DependencyManagement::ProvisionServiceAccountService::SERVICE_ACCOUNT_NAME
          )
        end

        before do
          project.add_member(existing_service_account, :guest)
        end

        it 'reuses the existing service account' do
          response = execute

          expect(response).to be_success
          expect(pipeline_from(response).user).to eq(existing_service_account)
        end
      end

      context 'when service account provisioning fails' do
        before do
          allow_next_instance_of(DependencyManagement::ProvisionServiceAccountService) do |svc|
            allow(svc).to receive(:execute)
              .and_return(ServiceResponse.error(message: 'Failed to create service account'))
          end
        end

        it 'logs the error and returns an error response' do
          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
            an_instance_of(DependencyManagement::SecurityUpdate::UpdateServiceError),
            hash_including(class: described_class.name, project_id: project.id)
          )

          expect(execute).to be_error
          expect(execute.message).to eq('Failed to retrieve or create bot user')
        end

        it 'does not call RunWorkloadService' do
          expect(Ci::Workloads::RunWorkloadService).not_to receive(:new)
          execute
        end
      end
    end
  end
end
