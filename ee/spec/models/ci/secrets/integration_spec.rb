# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Secrets::Integration, feature_category: :secrets_management do
  let_it_be_with_refind(:project) { create(:project) }
  let_it_be_with_refind(:pipeline) { create(:ci_pipeline, project: project) }
  let(:job) { create(:ci_build, pipeline: pipeline) }

  subject(:secrets_provider?) { job.secrets_provider?(nil) }

  describe '#secrets_provider?' do
    let(:vault_secret) do
      { "SECRET" => { "vault" => { "engine" => { "name" => "kv-v2", "path" => "kv" }, "path" => "secret" } } }
    end

    let(:azure_secret) { { "SECRET" => { "azure_key_vault" => { "name" => "my-secret" } } } }
    let(:gcp_secret)   { { "SECRET" => { "gcp_secret_manager" => { "name" => "my-secret" } } } }

    context 'when secrets is nil' do
      subject(:secrets_provider?) { job.secrets_provider?(nil) }

      it { is_expected.to be(true) }
    end

    context 'when secrets is empty' do
      subject(:secrets_provider?) { job.secrets_provider?({}) }

      it { is_expected.to be(true) }
    end

    context 'when no secret CI variables are set' do
      subject(:secrets_provider?) { job.secrets_provider?(vault_secret) }

      it { is_expected.to be(false) }
    end

    context 'when the VAULT_SERVER_URL is set' do
      subject(:secrets_provider?) { job.secrets_provider?(vault_secret) }

      before do
        project.variables.create!(key: 'VAULT_SERVER_URL', value: 'server_url')
      end

      it { is_expected.to be(true) }
    end

    context 'when only one Azure key vault CI variable is set' do
      subject(:secrets_provider?) { job.secrets_provider?(azure_secret) }

      before do
        project.variables.create!(key: 'AZURE_KEY_VAULT_SERVER_URL', value: 'server_url')
      end

      it { is_expected.to be(false) }
    end

    context 'when all Azure key vault CI variables are set' do
      subject(:secrets_provider?) { job.secrets_provider?(azure_secret) }

      before do
        project.variables.create!(key: 'AZURE_KEY_VAULT_SERVER_URL', value: 'server_url')
        project.variables.create!(key: 'AZURE_CLIENT_ID', value: 'client_ID')
        project.variables.create!(key: 'AZURE_TENANT_ID', value: 'tenant_id')
      end

      it { is_expected.to be(true) }
    end

    context 'when only one GCP Secrets Manager CI variable is set' do
      subject(:secrets_provider?) { job.secrets_provider?(gcp_secret) }

      before do
        project.variables.create!(key: 'GCP_PROJECT_NUMBER', value: '1234')
      end

      it { is_expected.to be(false) }
    end

    context 'when all GCP Secrets Manager CI variables are set' do
      subject(:secrets_provider?) { job.secrets_provider?(gcp_secret) }

      before do
        project.variables.create!(key: 'GCP_PROJECT_NUMBER', value: '1234')
        project.variables.create!(key: 'GCP_WORKLOAD_IDENTITY_FEDERATION_POOL_ID', value: 'pool-id')
        project.variables.create!(key: 'GCP_WORKLOAD_IDENTITY_FEDERATION_PROVIDER_ID', value: 'provider-id')
      end

      it { is_expected.to be(true) }
    end

    context 'when the secret uses GitLab Secrets Manager' do
      let(:gsm_secret) { { "SECRET" => { "gitlab_secrets_manager" => { "name" => "my-secret" } } } }

      subject(:secrets_provider?) { job.secrets_provider?(gsm_secret) }

      it { is_expected.to be(true) }
    end

    context 'when the secret uses GitLab Secrets Manager with a group source' do
      let(:gsm_group_secret) do
        { "SECRET" => { "gitlab_secrets_manager" => { "name" => "my-secret", "source" => "group/my-org" } } }
      end

      subject(:secrets_provider?) { job.secrets_provider?(gsm_group_secret) }

      it { is_expected.to be(true) }
    end

    context 'when the job has both a vault secret and a GSM secret' do
      let(:mixed_secrets) do
        {
          "VAULT_SECRET" => { "vault" => { "engine" => { "name" => "kv-v2", "path" => "kv" }, "path" => "secret" } },
          "GSM_SECRET" => { "gitlab_secrets_manager" => { "name" => "my-secret" } }
        }
      end

      subject(:secrets_provider?) { job.secrets_provider?(mixed_secrets) }

      context 'when the VAULT_SERVER_URL is set' do
        before do
          project.variables.create!(key: 'VAULT_SERVER_URL', value: 'server_url')
        end

        it { is_expected.to be(true) }
      end

      context 'when the VAULT_SERVER_URL is not set' do
        it { is_expected.to be(false) }
      end
    end
  end
end
