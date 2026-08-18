# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ci::ProjectCiCdSettingsUpdate, feature_category: :continuous_integration do
  include GraphqlHelpers

  let_it_be_with_reload(:project) { create(:project) }

  let(:current_user) { project.first_owner }
  let(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

  subject(:resolve_mutation) { mutation.resolve(full_path: project.full_path, **mutation_params) }

  before do
    stub_licensed_features(merge_pipelines: true, merge_trains: true)
    project.update!(
      merge_pipelines_enabled: nil,
      merge_trains_enabled: false,
      merge_trains_skip_train_allowed: false
    )
  end

  describe '#resolve' do
    before do
      resolve_mutation
      project.reload
    end

    context 'when merge trains are set to true and merge pipelines are set to false' do
      let(:mutation_params) do
        {
          full_path: project.full_path,
          merge_pipelines_enabled: false,
          merge_trains_enabled: true
        }
      end

      it 'does not enable merge trains' do
        expect(project.ci_cd_settings.merge_trains_enabled?).to be(false)
      end
    end

    context 'when merge trains and merge pipelines are set to true' do
      let(:mutation_params) do
        {
          full_path: project.full_path,
          merge_pipelines_enabled: true,
          merge_trains_enabled: true
        }
      end

      it 'enables merge pipelines and merge trains' do
        expect(project.merge_pipelines_enabled?).to be(true)
        expect(project.merge_trains_enabled?).to be(true)
      end
    end

    context 'when merge_trains_skip_train_allowed is set to true' do
      let(:mutation_params) do
        {
          merge_trains_skip_train_allowed: true
        }
      end

      it 'updates the value' do
        # This column value is not the same as #merge_trains_skip_train_allowed?
        # which has added business logic
        expect(project.ci_cd_settings.merge_trains_skip_train_allowed).to be(true)
      end
    end

    context 'when max_pipelines_per_merge_train is set' do
      let(:mutation_params) do
        {
          max_pipelines_per_merge_train: 5
        }
      end

      it 'updates the value' do
        expect(project.ci_cd_settings.max_pipelines_per_merge_train).to eq(5)
      end
    end

    context 'when merge_train_enforcement is set' do
      let(:mutation_params) do
        {
          merge_train_enforcement: 'enforce_for_all_users'
        }
      end

      it 'updates the value' do
        expect(project.ci_cd_settings.merge_train_enforcement).to eq('enforce_for_all_users')
      end
    end
  end

  describe 'when the inbound_job_token_scope parameter is not provided' do
    let(:mutation_params) do
      {
        full_path: project.full_path,
        merge_pipelines_enabled: true,
        merge_trains_enabled: true
      }
    end

    it 'does not log an audit event' do
      expect(::Gitlab::Audit::Auditor).not_to receive(:audit).with(
        hash_including(name: a_string_matching(/^secure_ci_job_token_inbound/))
      )
      resolve_mutation
    end
  end

  describe 'inbound_job_token_scope_enabled' do
    let(:mutation_params) do
      {
        full_path: project.full_path,
        inbound_job_token_scope_enabled: inbound_job_token_scope_enabled_target
      }
    end

    let(:project) do
      create(:project,
        keep_latest_artifact: true,
        ci_inbound_job_token_scope_enabled: inbound_job_token_scope_enabled_origin
      )
    end

    let(:ci_cd_settings) { project.ci_cd_settings }

    let(:expected_target) do
      project.ci_cd_settings
    end

    let(:expected_audit_context) do
      {
        name: event_name,
        author: current_user,
        scope: project,
        target: expected_target,
        message: expected_audit_message
      }
    end

    before do
      ci_cd_settings.update!(inbound_job_token_scope_enabled: inbound_job_token_scope_enabled_origin)
    end

    context 'when changes from enabled to disabled' do
      let(:inbound_job_token_scope_enabled_origin) { true }
      let(:inbound_job_token_scope_enabled_target) { false }
      let(:expected_audit_message) { 'Secure ci_job_token was disabled for inbound' }
      let(:event_name) { 'secure_ci_job_token_inbound_disabled' }

      before do
        allow(::Gitlab::CurrentSettings).to receive(:enforce_ci_inbound_job_token_scope_enabled?).and_return(false)
      end

      it 'logs an audit event' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(hash_including(expected_audit_context))

        resolve_mutation
      end
    end

    context 'when changes from disabled to enabled' do
      let(:inbound_job_token_scope_enabled_origin) { false }
      let(:inbound_job_token_scope_enabled_target) { true }
      let(:expected_audit_message) { 'Secure ci_job_token was enabled for inbound' }
      let(:event_name) { 'secure_ci_job_token_inbound_enabled' }

      it 'logs an audit event' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(hash_including(expected_audit_context))

        resolve_mutation
      end
    end

    context 'when there are no changes' do
      let(:inbound_job_token_scope_enabled_origin) { true }
      let(:inbound_job_token_scope_enabled_target) { true }

      it 'does not log an audit event' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        resolve_mutation
      end
    end

    context 'when instance-level enforcement is enabled' do
      before do
        allow(::Gitlab::CurrentSettings).to receive(:enforce_ci_inbound_job_token_scope_enabled?).and_return(true)
      end

      context 'when trying to disable inbound_job_token_scope_enabled' do
        let(:inbound_job_token_scope_enabled_origin) { true }
        let(:inbound_job_token_scope_enabled_target) { false }

        it 'does not log an audit event because the update is blocked' do
          expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

          resolve_mutation
        end

        it 'returns an error' do
          result = resolve_mutation

          expect(result[:errors]).to include(include('enforced for the instance'))
        end
      end
    end
  end
end
