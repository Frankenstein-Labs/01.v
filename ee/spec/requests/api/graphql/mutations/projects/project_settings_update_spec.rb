# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "Project settings update", feature_category: :duo_code_review do
  include GraphqlHelpers
  include ProjectForksHelper
  include ExclusiveLeaseHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:group) }
  let_it_be(:add_on) { create(:gitlab_subscription_add_on, :duo_pro) }
  let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, namespace: namespace, add_on: add_on) }
  let_it_be(:duo_features_enabled) { true }
  let_it_be(:web_based_commit_signing_enabled) { true }
  let_it_be_with_reload(:project) do
    create(:project, namespace: namespace, duo_features_enabled: !duo_features_enabled,
      web_based_commit_signing_enabled: !web_based_commit_signing_enabled)
  end

  let(:duo_context_exclusion_settings) { nil }
  let(:mutation) do
    params = {
      full_path: project.full_path,
      duo_features_enabled: duo_features_enabled,
      duo_context_exclusion_settings: duo_context_exclusion_settings,
      web_based_commit_signing_enabled: web_based_commit_signing_enabled
    }.compact

    graphql_mutation(:project_settings_update, params) do
      <<-QL.strip_heredoc
        projectSettings {
          duoFeaturesEnabled
          duoContextExclusionSettings {
            exclusionRules
          }
          webBasedCommitSigningEnabled
        }
        errors
      QL
    end
  end

  context 'when updating settings' do
    before_all do
      project.add_maintainer(user)
    end

    before do
      stub_saas_features(duo_chat_on_saas: true)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :update_project do
      let(:boundary_object) { project }
      let(:mutation) do
        graphql_mutation(:project_settings_update,
          { full_path: project.full_path, duo_features_enabled: duo_features_enabled },
          'errors')
      end

      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end

    it 'updates the settings' do
      expect { post_graphql_mutation(mutation, current_user: user) }
        .to change {
              [
                project.reload.duo_features_enabled,
                project.reload.web_based_commit_signing_enabled
              ]
            }
        .from([!duo_features_enabled, !web_based_commit_signing_enabled])
        .to([duo_features_enabled, web_based_commit_signing_enabled])

      expect(graphql_mutation_response('projectSettingsUpdate')['projectSettings'])
        .to include({
          'duoFeaturesEnabled' => duo_features_enabled,
          'webBasedCommitSigningEnabled' => web_based_commit_signing_enabled
        })
    end

    context 'when updating duo_context_exclusion_settings' do
      let(:duo_context_exclusion_settings) { { "exclusion_rules" => ['*.txt', 'node_modules/'] } }

      it 'updates the duo context exclusion settings' do
        expect { post_graphql_mutation(mutation, current_user: user) }
          .to change { project.project_setting.reload.duo_context_exclusion_settings }
          .from({}).to(duo_context_exclusion_settings)

        expect(graphql_mutation_response('projectSettingsUpdate')['projectSettings']['duoContextExclusionSettings'])
          .to eq({ 'exclusionRules' => ['*.txt', 'node_modules/'] })
      end
    end

    context 'when updating only web_based_commit_signing_enabled' do
      let(:duo_features_enabled) { nil }
      let(:web_based_commit_signing_mutation) do
        graphql_mutation(:project_settings_update, {
          full_path: project.full_path,
          web_based_commit_signing_enabled: web_based_commit_signing_enabled
        }) do
          <<-QL.strip_heredoc
            projectSettings {
              webBasedCommitSigningEnabled
            }
            errors
          QL
        end
      end

      before do
        stub_saas_features(repositories_web_based_commit_signing: true)
      end

      it 'updates web_based_commit_signing_enabled without duo_chat_on_saas feature' do
        expect { post_graphql_mutation(web_based_commit_signing_mutation, current_user: user) }
          .to change { project.reload.web_based_commit_signing_enabled }
          .from(!web_based_commit_signing_enabled)
          .to(web_based_commit_signing_enabled)

        expect(graphql_mutation_response('projectSettingsUpdate')['projectSettings'])
          .to include({
            'webBasedCommitSigningEnabled' => web_based_commit_signing_enabled
          })
      end
    end

    context 'when updating only ai_audit_events_storage_enabled' do
      let_it_be(:owner) { create(:user) }
      let(:duo_features_enabled) { nil }
      let(:ai_audit_mutation) do
        graphql_mutation(:project_settings_update, {
          full_path: project.full_path,
          ai_audit_events_storage_enabled: true
        }) do
          <<-QL.strip_heredoc
            projectSettings {
              aiAuditEventsStorageEnabled
            }
            errors
          QL
        end
      end

      before_all do
        project.add_owner(owner)
      end

      it 'updates ai_audit_events_storage_enabled as an owner' do
        expect { post_graphql_mutation(ai_audit_mutation, current_user: owner) }
          .to change { project.reload.ai_audit_events_storage_enabled }
          .from(false).to(true)

        expect(graphql_mutation_response('projectSettingsUpdate')['projectSettings'])
          .to include({ 'aiAuditEventsStorageEnabled' => true })
      end

      it 'denies a maintainer' do
        expect { post_graphql_mutation(ai_audit_mutation, current_user: user) }
          .not_to change { project.reload.ai_audit_events_storage_enabled }

        expect(graphql_errors).to include(
          a_hash_including('message' => ::Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR)
        )
      end

      it 'allows a security manager' do
        security_manager = create(:user)
        project.add_member(security_manager, Gitlab::Access::SECURITY_MANAGER)

        expect { post_graphql_mutation(ai_audit_mutation, current_user: security_manager) }
          .to change { project.reload.ai_audit_events_storage_enabled }
          .from(false).to(true)
      end
    end

    context 'when no arguments are provided' do
      let(:duo_features_enabled) { nil }
      let(:empty_mutation) do
        graphql_mutation(:project_settings_update, { full_path: project.full_path }) do
          <<-QL.strip_heredoc
            projectSettings {
              duoFeaturesEnabled
            }
            errors
          QL
        end
      end

      it 'returns an error' do
        post_graphql_mutation(empty_mutation, current_user: user)

        expect(graphql_errors).to include(a_hash_including(
          'message' => 'Must provide at least one argument'
        ))
      end
    end

    context 'when the project full path does not exist' do
      let(:invalid_mutation) do
        graphql_mutation(:project_settings_update, {
          full_path: 'non/existent/path',
          duo_features_enabled: duo_features_enabled
        }, 'errors')
      end

      it 'returns a graceful resource-not-available error instead of a stack trace' do
        post_graphql_mutation(invalid_mutation, current_user: user)

        expect(response).to have_gitlab_http_status(:success)
        expect_graphql_errors_to_include(
          "The resource that you are attempting to access does not exist " \
            "or you don't have permission to perform this action"
        )
      end
    end
  end
end
