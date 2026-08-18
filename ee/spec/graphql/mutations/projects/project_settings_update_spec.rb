# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Projects::ProjectSettingsUpdate, feature_category: :duo_code_review do
  include GraphqlHelpers
  subject(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

  let_it_be(:current_user) { create(:user) }
  let_it_be(:namespace) { create(:group) }
  let_it_be(:add_on) { create(:gitlab_subscription_add_on, :duo_pro) }
  let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, namespace: namespace, add_on: add_on) }
  let_it_be(:project) { create(:project, namespace: namespace) }

  let_it_be(:project_without_addon) { create(:project) }

  describe '#resolve' do
    subject(:resolve) do
      args = { full_path: project.full_path }
      args[:duo_features_enabled] = duo_features_enabled if defined?(duo_features_enabled)
      args[:duo_context_exclusion_settings] = duo_context_exclusion_settings if defined?(duo_context_exclusion_settings)
      args[:duo_sast_vr_workflow_enabled] = duo_sast_vr_workflow_enabled if defined?(duo_sast_vr_workflow_enabled)
      args[:duo_sast_fp_detection_enabled] = duo_sast_fp_detection_enabled if defined?(duo_sast_fp_detection_enabled)
      if defined?(duo_secret_detection_fp_enabled)
        args[:duo_secret_detection_fp_enabled] =
          duo_secret_detection_fp_enabled
      end

      mutation.resolve(**args)
    end

    let(:duo_features_enabled) { true }
    let(:duo_context_exclusion_settings) { nil }

    it 'raises an error if the resource is not accessible to the user' do
      expect { resolve }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
    end

    context 'when the user can update duo features enabled' do
      before_all do
        project.add_owner(current_user)
      end

      context 'when duo features are not available' do
        before do
          stub_licensed_features(code_suggestions: false)
        end

        it 'raises an error' do
          expect { resolve }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when duo addon is not available' do
        before do
          stub_licensed_features(code_suggestions: true)
        end

        it 'raises an error' do
          expect do
            mutation.resolve(full_path: project_without_addon.full_path,
              duo_features_enabled: duo_features_enabled)
          end.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when duo chat is enabled on saas' do
        before do
          stub_licensed_features(code_suggestions: false)
          stub_saas_features(duo_chat_on_saas: true)
        end

        it 'updates the setting' do
          expect(::Projects::UpdateService).to receive(:new).with(
            anything,
            anything,
            { project_setting_attributes: { duo_features_enabled: duo_features_enabled } }
          ).and_call_original
          expect(resolve[:project_settings]).to have_attributes(duo_features_enabled: duo_features_enabled)
        end
      end

      context 'when disabling duo features' do
        let(:duo_features_enabled) { false }

        before do
          stub_saas_features(duo_chat_on_saas: true)
        end

        it 'updates the setting' do
          expect(resolve[:project_settings]).to have_attributes(duo_features_enabled: duo_features_enabled)
        end
      end

      context 'when updating duo context exclusion settings' do
        let(:duo_context_exclusion_settings) { { exclusion_rules: ['*.txt', 'node_modules/'] } }

        before do
          stub_saas_features(duo_chat_on_saas: true)
        end

        it 'updates the duo context exclusion settings' do
          expect(::Projects::UpdateService).to receive(:new).with(
            anything,
            anything,
            hash_including(project_setting_attributes:
              hash_including(duo_context_exclusion_settings: duo_context_exclusion_settings)
                          )).and_call_original

          resolve
        end
      end

      context 'when not providing any parameters' do
        subject(:resolve_without_params) do
          mutation.resolve(full_path: project.full_path)
        end

        before do
          stub_saas_features(duo_chat_on_saas: true)
        end

        it 'raise an error' do
          expect do
            resolve_without_params
          end.to raise_error(Gitlab::Graphql::Errors::ArgumentError, 'Must provide at least one argument')
        end
      end
    end

    context 'when user cannot update duo features enabled' do
      before_all do
        project.add_developer(current_user)
      end

      it 'raises an error' do
        expect { resolve }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when user is a security manager updating duo_sast_vr_workflow_enabled' do
      let_it_be(:security_manager) { create(:user, security_manager_of: project) }

      let(:current_user) { security_manager }
      let(:duo_sast_vr_workflow_enabled) { true }

      subject(:resolve) do
        mutation.resolve(full_path: project.full_path, duo_sast_vr_workflow_enabled: duo_sast_vr_workflow_enabled)
      end

      before do
        stub_saas_features(duo_chat_on_saas: true)
        stub_feature_flags(update_sast_vr_setting_permission: true)
        project.project_setting.update!(duo_sast_vr_workflow_enabled: false)
      end

      it 'updates the setting' do
        expect(resolve[:project_settings]).to have_attributes(duo_sast_vr_workflow_enabled: true)
      end

      context 'when also trying to update other settings' do
        subject(:resolve) do
          mutation.resolve(
            full_path: project.full_path,
            duo_sast_vr_workflow_enabled: true,
            duo_features_enabled: true
          )
        end

        it 'raises an error' do
          expect { resolve }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when update_sast_vr_setting_permission feature flag is disabled' do
        before do
          stub_feature_flags(update_sast_vr_setting_permission: false)
        end

        it 'raises an error' do
          expect { resolve }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end
    end

    context 'when user is a security manager updating duo_sast_fp_detection_enabled' do
      let_it_be(:security_manager) { create(:user, security_manager_of: project) }

      let(:current_user) { security_manager }
      let(:duo_sast_fp_detection_enabled) { true }

      subject(:resolve) do
        mutation.resolve(full_path: project.full_path, duo_sast_fp_detection_enabled: duo_sast_fp_detection_enabled)
      end

      before do
        stub_saas_features(duo_chat_on_saas: true)
        stub_feature_flags(update_false_positive_detection_setting_permission: true)
        project.project_setting.update!(duo_sast_fp_detection_enabled: false)
      end

      it 'updates the setting' do
        expect(resolve[:project_settings]).to have_attributes(duo_sast_fp_detection_enabled: true)
      end

      context 'when also trying to update other settings' do
        subject(:resolve) do
          mutation.resolve(
            full_path: project.full_path,
            duo_sast_fp_detection_enabled: true,
            duo_features_enabled: true
          )
        end

        it 'raises an error' do
          expect { resolve }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when update_false_positive_detection_setting_permission feature flag is disabled' do
        before do
          stub_feature_flags(update_false_positive_detection_setting_permission: false)
        end

        it 'raises an error' do
          expect { resolve }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when updating both sec AI workflow settings together' do
        subject(:resolve) do
          mutation.resolve(
            full_path: project.full_path,
            duo_sast_fp_detection_enabled: true,
            duo_sast_vr_workflow_enabled: true
          )
        end

        before do
          stub_feature_flags(
            update_sast_vr_setting_permission: true,
            update_false_positive_detection_setting_permission: true
          )
          project.project_setting.update!(duo_sast_vr_workflow_enabled: false)
        end

        it 'updates both settings', :aggregate_failures do
          result = resolve
          expect(result[:project_settings]).to have_attributes(
            duo_sast_fp_detection_enabled: true,
            duo_sast_vr_workflow_enabled: true
          )
        end
      end
    end

    context 'when user is a security manager updating duo_secret_detection_fp_enabled' do
      let_it_be(:security_manager) { create(:user, security_manager_of: project) }

      let(:current_user) { security_manager }
      let(:duo_secret_detection_fp_enabled) { true }

      subject(:resolve) do
        mutation.resolve(full_path: project.full_path,
          duo_secret_detection_fp_enabled: duo_secret_detection_fp_enabled)
      end

      before do
        stub_saas_features(duo_chat_on_saas: true)
        stub_feature_flags(update_false_positive_detection_setting_permission: true)
        project.project_setting.update!(duo_secret_detection_fp_enabled: false)
      end

      it 'updates the setting' do
        expect(resolve[:project_settings]).to have_attributes(duo_secret_detection_fp_enabled: true)
      end

      context 'when also trying to update other settings' do
        subject(:resolve) do
          mutation.resolve(
            full_path: project.full_path,
            duo_secret_detection_fp_enabled: true,
            duo_features_enabled: true
          )
        end

        it 'raises an error' do
          expect { resolve }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when update_false_positive_detection_setting_permission feature flag is disabled' do
        before do
          stub_feature_flags(update_false_positive_detection_setting_permission: false)
        end

        it 'raises an error' do
          expect { resolve }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when updating both duo_secret_detection_fp_enabled and duo_sast_vr_workflow_enabled together' do
        subject(:resolve) do
          mutation.resolve(
            full_path: project.full_path,
            duo_secret_detection_fp_enabled: true,
            duo_sast_vr_workflow_enabled: true
          )
        end

        before do
          stub_feature_flags(
            update_sast_vr_setting_permission: true,
            update_false_positive_detection_setting_permission: true
          )
          project.project_setting.update!(duo_sast_vr_workflow_enabled: false)
        end

        it 'updates both settings', :aggregate_failures do
          result = resolve
          expect(result[:project_settings]).to have_attributes(
            duo_secret_detection_fp_enabled: true,
            duo_sast_vr_workflow_enabled: true
          )
        end
      end

      context 'when updating both duo_secret_detection_fp_enabled and duo_sast_fp_detection_enabled together' do
        subject(:resolve) do
          mutation.resolve(
            full_path: project.full_path,
            duo_secret_detection_fp_enabled: true,
            duo_sast_fp_detection_enabled: true
          )
        end

        before do
          stub_feature_flags(
            update_sast_vr_setting_permission: false,
            update_false_positive_detection_setting_permission: true
          )
          project.project_setting.update!(duo_secret_detection_fp_enabled: true, duo_sast_fp_detection_enabled: true)
        end

        it 'updates both settings', :aggregate_failures do
          result = resolve
          expect(result[:project_settings]).to have_attributes(
            duo_secret_detection_fp_enabled: true,
            duo_sast_fp_detection_enabled: true
          )
        end
      end
    end
  end
end
