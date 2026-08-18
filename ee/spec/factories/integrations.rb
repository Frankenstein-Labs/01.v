# frozen_string_literal: true

FactoryBot.define do
  factory :github_integration, class: 'Integrations::Github' do
    project
    type { 'Integrations::Github' }
    active { true }
    token { 'github-token' }
    repository_url { 'https://github.com/owner/repository' }
  end

  factory :google_cloud_platform_artifact_registry_integration,
    class: 'Integrations::GoogleCloudPlatform::ArtifactRegistry' do
    project
    type { 'Integrations::GoogleCloudPlatform::ArtifactRegistry' }
    active { true }
    artifact_registry_project_id { 'dev-gcp-9abafed1' }
    artifact_registry_location { 'us-east1' }
    artifact_registry_repositories { 'demo, my-repo' }
  end

  factory(:google_cloud_platform_workload_identity_federation_integration,
    class: 'Integrations::GoogleCloudPlatform::WorkloadIdentityFederation') do
    project
    type { 'Integrations::GoogleCloudPlatform::WorkloadIdentityFederation' }
    active { true }
    workload_identity_federation_project_id { 'google-wlif-project-id' }
    workload_identity_federation_project_number { '123456789' }
    workload_identity_pool_id { 'wlif-pool-id' }
    workload_identity_pool_provider_id { 'wlif-pool-provider-id' }
  end

  factory :git_guardian_integration, class: 'Integrations::GitGuardian' do
    project
    type { 'Integrations::GitGuardian' }
    active { true }
    token { 'git_guardian-token' }
  end

  factory :amazon_q_integration, class: 'Integrations::AmazonQ' do
    type { 'Integrations::AmazonQ' }
    active { true }
    instance { true }
    role_arn { 'q' }
    availability { 'default_on' }
    auto_review_enabled { false }
    organization { association(:organization) }

    after(:build) do |integration|
      integration.organization = nil unless integration.instance
    end
  end
end
