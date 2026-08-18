# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::ApplicationSettingsController, :enable_admin_mode, feature_category: :shared do
  include StubENV

  let_it_be(:admin) { create(:admin) }

  before do
    stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
  end

  describe 'PUT update_microsoft_application', feature_category: :system_access do
    let(:params) do
      { system_access_microsoft_application: attributes_for(:system_access_microsoft_application) }
    end

    let(:path) { update_microsoft_application_admin_application_settings_path }

    subject(:update_request) { put path, params: params }

    before do
      allow(::Gitlab::Auth::Saml::Config).to receive(:microsoft_group_sync_enabled?).and_return(true)
      sign_in(admin)
    end

    it 'raises an error when parameters are missing' do
      expect { put path }.to raise_error(ActionController::ParameterMissing)
    end

    it 'redirects with error alert when missing required attributes' do
      put path, params: { system_access_microsoft_application: { enabled: true } }

      expect(response).to have_gitlab_http_status(:redirect)
      expect(flash[:alert]).to include('Microsoft Azure integration settings failed to save.')
    end

    it 'redirects with success notice' do
      put path, params: params

      expect(response).to have_gitlab_http_status(:redirect)
      expect(flash[:notice]).to eq(s_('Microsoft|Microsoft Azure integration settings were successfully updated.'))
    end

    it 'creates new SystemAccess::MicrosoftApplication' do
      expect { update_request }.to change { SystemAccess::MicrosoftApplication.count }.by(1)
    end

    it 'does not create a SystemAccess::GroupMicrosoftApplication' do
      expect { update_request }.not_to change { SystemAccess::GroupMicrosoftApplication.count }
    end
  end

  describe 'GET #general', feature_category: :user_management do
    before do
      sign_in(admin)
    end

    context 'when microsoft_group_sync_enabled? is true' do
      before do
        allow(::Gitlab::Auth::Saml::Config).to receive(:microsoft_group_sync_enabled?).and_return(true)
      end

      it 'initializes correctly with SystemAccess::MicrosoftApplication' do
        create(:system_access_microsoft_application, namespace: nil, client_xid: 'test-xid-456')

        get general_admin_application_settings_path

        expect(response.body).to match(/test-xid-456/)
      end
    end

    it 'does push :disable_private_profiles license feature' do
      expect_next_instance_of(described_class) do |instance|
        expect(instance).to receive(:push_licensed_feature).with(:password_complexity)
        expect(instance).to receive(:push_licensed_feature).with(:seat_control)
        expect(instance).to receive(:push_licensed_feature).with(:disable_private_profiles)
      end

      get general_admin_application_settings_path
    end

    context 'for display_gitlab_credits_user_data', feature_category: :consumables_cost_management do
      it 'does not show the checkbox in saas', :saas_gitlab_com_subscriptions do
        stub_licensed_features(usage_billing: true)

        get general_admin_application_settings_path

        expect(response.body).not_to include('GitLab Credits dashboard')
        expect(response.body).not_to include('Display user data')
      end

      it 'hides checkbox when license does not have usage billing feature' do
        stub_licensed_features(usage_billing: false)

        get general_admin_application_settings_path

        expect(response.body).not_to include('GitLab Credits dashboard')
        expect(response.body).not_to include('Display user data')
      end

      it 'shows the checkbox when license feature is enabled' do
        stub_licensed_features(usage_billing: true)

        get general_admin_application_settings_path

        expect(response.body).to include('GitLab Credits dashboard')
        expect(response.body).to include('Display user data')
      end

      it 'shows checkbox as checked when setting is true' do
        stub_licensed_features(usage_billing: true)
        ::Gitlab::CurrentSettings.update!(display_gitlab_credits_user_data: true)

        get general_admin_application_settings_path

        expect(response.body).to include('display_gitlab_credits_user_data')
        expect(response.body)
          .to include('checked="checked" name="application_setting[display_gitlab_credits_user_data]"')
      end

      it 'shows checkbox as unchecked when setting is false' do
        stub_licensed_features(usage_billing: true)
        ::Gitlab::CurrentSettings.update!(display_gitlab_credits_user_data: false)

        get general_admin_application_settings_path

        expect(response.body).to include('display_gitlab_credits_user_data')
        expect(response.body)
          .not_to include('checked="checked" name="application_setting[display_gitlab_credits_user_data]"')
      end
    end

    it 'pushes the :secrets_manager_paid_experience FF to the frontend', feature_category: :secrets_management do
      stub_feature_flags(secrets_manager_paid_experience: true)

      get general_admin_application_settings_path

      expect(response.body).to have_pushed_frontend_feature_flags(secretsManagerPaidExperience: true)
    end
  end

  describe 'GET #search', feature_category: :global_search do
    before do
      sign_in(admin)
    end

    describe 'semantic search settings', :aggregate_failures do
      shared_examples 'renders the collection information' do
        context 'when collection record has current embedding model' do
          before do
            collection_record.update_metadata!(
              current_indexing_embedding_model: current_indexing_embedding_model
            )
          end

          let(:current_indexing_embedding_model) do
            {
              model_type: 'gitlab_managed',
              model_ref: 'text_embedding_005_vertex',
              field: 'test_embeddings_v1',
              dimensions: 768
            }
          end

          it 'shows the embedding model details' do
            get search_admin_application_settings_path

            expect(response).to have_gitlab_http_status(:ok)
            expect(response.body).to have_css('h4', text: "#{collection_key.to_s.humanize} embeddings")
            expect(response.body).to have_css(
              "[data-testid='semantic-search-model-#{collection_key}']",
              text: /Gitlab-managed \| text-embedding-005 - Vertex \| 768/
            )
          end

          context 'when current model does not have a model_type or dimensions' do
            let(:current_indexing_embedding_model) do
              {
                model_ref: 'text_embedding_005_vertex',
                field: 'test_embeddings_v1'
              }
            end

            it 'shows the model information without the model_type' do
              get search_admin_application_settings_path

              expect(response).to have_gitlab_http_status(:ok)
              expect(response.body).to have_text('text-embedding-005 - Vertex')
              expect(response.body).not_to have_text('Gitlab-managed | text-embedding-005 - Vertex | 768')
            end
          end
        end

        context 'when collection record has next embedding model' do
          before do
            collection_record.update_metadata!(
              next_indexing_embedding_model: next_indexing_embedding_model
            )
          end

          let(:next_indexing_embedding_model) do
            {
              model_type: 'gitlab_managed',
              model_ref: 'text_embedding_005_vertex',
              field: 'test_embeddings_v1',
              dimensions: 768
            }
          end

          it 'shows the next model information' do
            get search_admin_application_settings_path

            expect(response).to have_gitlab_http_status(:ok)
            expect(response.body).to have_css('h4', text: "#{collection_key.to_s.humanize} embeddings")
            expect(response.body).to have_css(
              "[data-testid='semantic-search-model-#{collection_key}']",
              text: /Switching to: Gitlab-managed \| text-embedding-005 - Vertex \| 768/
            )
          end
        end
      end

      shared_examples 'model configuration is unavailable' do
        it 'shows model configuration is unavailable' do
          get search_admin_application_settings_path

          expect(response).to have_gitlab_http_status(:ok)
          expect(response.body).to have_css(
            "[data-testid='semantic-search-model-#{collection_key}']",
            text: /Embedding model configuration is not available. #{expected_unavailable_message}/
          )
          expect(response.body).not_to have_css(
            "[data-testid='configure-semantic-search-embeddings-#{collection_key}']"
          )
        end
      end

      shared_examples 'does not allow model configuration' do
        it 'does not show a button to configured the model' do
          get search_admin_application_settings_path

          expect(response).to have_gitlab_http_status(:ok)
          expect(response.body).not_to have_css(
            "[data-testid='configure-semantic-search-embeddings-#{collection_key}']"
          )
        end
      end

      shared_examples 'allows model configuration' do
        it 'shows a button to configure the model' do
          get search_admin_application_settings_path

          expect(response).to have_gitlab_http_status(:ok)
          expected_button_css = "[data-testid='configure-semantic-search-embeddings-#{collection_key}']" \
            "[href='#{admin_application_settings_semantic_search_embedding_path(collection_key.to_s)}']"
          expect(response.body).to have_css(
            expected_button_css,
            text: expected_configure_embedding_button_text
          )
        end
      end

      before do
        allow(::Ai::ActiveContext).to receive(:semantic_search_available?).and_return(true)

        allow(Ability).to receive(:allowed?).and_call_original
      end

      let_it_be(:collection_key) { :code }

      it 'renders the semantic search settings section' do
        get search_admin_application_settings_path

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to have_css(
          "[data-testid='semantic-search-settings']"
        )
      end

      context 'when there is no ActiveContext connection' do
        it_behaves_like 'model configuration is unavailable' do
          let(:expected_unavailable_message) { "The connection is not configured." }
        end
      end

      context 'when there is an ActiveContext connection' do
        let_it_be_with_reload(:connection) { create(:ai_active_context_connection, :elasticsearch) }

        context 'when collection record does not exist' do
          it_behaves_like 'model configuration is unavailable' do
            let(:expected_unavailable_message) do
              "Ensure Code collection exists."
            end
          end
        end

        context 'when collection record exists' do
          let_it_be_with_reload(:collection_record) do
            create(
              :ai_active_context_collection,
              :"#{collection_key}_collection",
              connection: connection
            )
          end

          context 'when gitlab selects the embedding model' do
            before do
              allow(::Ai::ActiveContext).to receive(:gitlab_selects_embedding_model?).and_return(true)
            end

            context 'when there is an ActiveContext connection' do
              it_behaves_like 'renders the collection information'

              context 'when user has ability to manage instance models' do
                before do
                  allow(Ability).to receive(:allowed?).with(
                    instance_of(User), :manage_instance_model_selection, *any_args
                  ).and_return(true)
                end

                it_behaves_like 'does not allow model configuration'
              end
            end
          end

          context 'when user selects the embedding model' do
            before do
              allow(::Ai::ActiveContext).to receive(:gitlab_selects_embedding_model?).and_return(false)
            end

            it_behaves_like 'renders the collection information'

            context 'when user does not have ability to manage instance models' do
              before do
                allow(Ability).to receive(:allowed?).with(
                  instance_of(User), :manage_instance_model_selection, *any_args
                ).and_return(false)
              end

              it_behaves_like 'does not allow model configuration'
            end

            context 'when user has ability to manage instance models' do
              before do
                allow(Ability).to receive(:allowed?).with(
                  instance_of(User), :manage_instance_model_selection, *any_args
                ).and_return(true)
              end

              context 'when testing terms are not accepted' do
                before do
                  allow(Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(false)
                end

                context 'when collection record has no current embedding model' do
                  before do
                    collection_record.update_metadata!(
                      current_indexing_embedding_model: nil
                    )
                  end

                  it 'disallows model configuration with a message' do
                    get search_admin_application_settings_path

                    expect(response).to have_gitlab_http_status(:ok)
                    expect(response.body).not_to have_css(
                      "[data-testid='configure-semantic-search-embeddings-#{collection_key}']"
                    )

                    expect(response.body).to have_css(
                      "[data-testid='configure-semantic-search-embeddings-#{collection_key}-disallowed']",
                      text: "Configuration is not allowed. Ensure self-hosted beta models and features are turned on."
                    )
                  end
                end

                context 'when collection record has current embedding model' do
                  before do
                    collection_record.update_metadata!(
                      current_indexing_embedding_model: {
                        model_type: :gitlab_managed,
                        model_ref: 'text_embedding_005_vertex',
                        field: 'test_embeddings_v1',
                        dimensions: 768
                      }
                    )
                  end

                  it 'disallows model configuration with a message, and indexing is disabled' do
                    get search_admin_application_settings_path

                    expect(response).to have_gitlab_http_status(:ok)
                    expect(response.body).not_to have_css(
                      "[data-testid='configure-semantic-search-embeddings-#{collection_key}']"
                    )

                    expect(response.body).to have_css(
                      "[data-testid='configure-semantic-search-embeddings-#{collection_key}-disallowed']",
                      text: "Configuration is not allowed, and indexing is disabled. " \
                        "Ensure self-hosted beta models and features are turned on."
                    )
                  end
                end
              end

              context 'when testing terms are accepted' do
                before do
                  allow(Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(true)
                end

                it_behaves_like 'allows model configuration' do
                  let(:expected_configure_embedding_button_text) { 'Set model' }
                end

                context 'when collection record has current embedding model' do
                  before do
                    collection_record.update_metadata!(
                      current_indexing_embedding_model: {
                        model_type: :gitlab_managed,
                        model_ref: 'text_embedding_005_vertex',
                        field: 'test_embeddings_v1',
                        dimensions: 768
                      }
                    )
                  end

                  it_behaves_like 'allows model configuration' do
                    let(:expected_configure_embedding_button_text) { 'Change model' }
                  end
                end

                context 'when collection record has next embedding model' do
                  before do
                    collection_record.update_metadata!(
                      next_indexing_embedding_model: {
                        model_type: :gitlab_managed,
                        model_ref: 'text_embedding_005_vertex',
                        field: 'test_embeddings_v1',
                        dimensions: 768
                      }
                    )
                  end

                  it 'disables model configuration' do
                    get search_admin_application_settings_path

                    expect(response).to have_gitlab_http_status(:ok)
                    expect(response.body).to have_css(
                      "[data-testid='configure-semantic-search-embeddings-#{collection_key}'][disabled='disabled']"
                    )
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  describe 'GET #work_item', feature_category: :team_planning do
    before do
      sign_in(admin)
    end

    it 'renders the work_item settings page' do
      get work_item_admin_application_settings_path

      expect(response).to have_gitlab_http_status(:ok)
    end

    context 'when user is unauthorized' do
      let(:unauthorized_user) { create(:user) }

      before do
        sign_in(unauthorized_user)
      end

      it 'does not render the page' do
        get work_item_admin_application_settings_path

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when on SaaS' do
      before do
        stub_saas_features(namespace_scoped_work_item_types: true)
      end

      it 'returns 404' do
        get work_item_admin_application_settings_path

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'PATCH #update' do
    before do
      sign_in(admin)
    end

    context 'for display_gitlab_credits_user_data', feature_category: :consumables_cost_management do
      let(:params) do
        { application_setting: { display_gitlab_credits_user_data: display_gitlab_credits_user_data } }
      end

      context 'when updating to true' do
        let(:display_gitlab_credits_user_data) { true }

        it 'updates the setting successfully' do
          patch general_admin_application_settings_path, params: params

          expect(response).to have_gitlab_http_status(:redirect)
          expect(::Gitlab::CurrentSettings.display_gitlab_credits_user_data).to be true
        end

        it 'shows success message' do
          patch general_admin_application_settings_path, params: params

          expect(flash[:notice]).to eq('Application settings saved successfully')
        end
      end

      context 'when updating to false' do
        let(:display_gitlab_credits_user_data) { false }

        before do
          ::Gitlab::CurrentSettings.update!(display_gitlab_credits_user_data: true)
        end

        it 'updates the setting successfully' do
          patch general_admin_application_settings_path, params: params

          expect(response).to have_gitlab_http_status(:redirect)
          expect(::Gitlab::CurrentSettings.display_gitlab_credits_user_data).to be false
        end
      end

      context 'when updating with invalid value' do
        let(:display_gitlab_credits_user_data) { nil }

        it 'does not update the setting' do
          original_value = ::Gitlab::CurrentSettings.display_gitlab_credits_user_data

          patch general_admin_application_settings_path, params: params

          expect(::Gitlab::CurrentSettings.reload.display_gitlab_credits_user_data).to eq(original_value)
        end

        it 'shows error message' do
          patch general_admin_application_settings_path, params: params

          expect(response.body).to include('must be a boolean value')
        end
      end
    end
  end
end
