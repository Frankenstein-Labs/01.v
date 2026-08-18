# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::ApplicationSettings::SemanticSearchEmbeddingsController, :enable_admin_mode, :aggregate_failures, feature_category: :global_search do
  let_it_be(:user) { create(:user) }
  let_it_be(:admin) { create(:admin) }

  let_it_be(:self_hosted_embedding_model) do
    create(:ai_self_hosted_model, :embedding, name: 'Embedding Model 1', identifier: 'embedding-1')
  end

  before do
    allow(admin).to receive(:can?).and_call_original
  end

  shared_examples 'redirects logged-out users' do
    context 'for logged-out user' do
      before do
        sign_out(user)
        sign_out(admin)
      end

      it 'redirects to login page' do
        send_request

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  shared_examples 'not available for non-admin users' do
    context 'for non-admin user' do
      before do
        sign_in(user)
      end

      it 'is not found' do
        send_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  shared_examples 'redirects to the search admin settings page' do
    it 'redirects to the search admin settings page' do
      send_request

      expect(response).to redirect_to(search_admin_application_settings_path)
    end
  end

  shared_examples 'checks semantic search and collection availability' do
    context 'when semantic search is not available' do
      before do
        allow(::Ai::ActiveContext).to receive(:semantic_search_available?).and_return(false)
      end

      it_behaves_like 'redirects to the search admin settings page'
    end

    context 'when semantic search is available' do
      before do
        allow(::Ai::ActiveContext).to receive(:semantic_search_available?).and_return(true)
      end

      context 'when there is no active ActiveContext connection' do
        it_behaves_like 'redirects to the search admin settings page'

        context 'when there is an active ActiveContext connection' do
          let_it_be(:connection) { create(:ai_active_context_connection, :elasticsearch) }

          context 'when collection key is invalid' do
            let(:collection_key) { :dummy }

            it_behaves_like 'redirects to the search admin settings page'
          end

          context 'when collection record is missing' do
            let(:collection_key) { :code }

            it_behaves_like 'redirects to the search admin settings page'
          end

          context 'when collection record exists but testing terms were not accepted' do
            before do
              allow(Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(false)
            end

            let(:collection_key) { :code }
            let_it_be(:collection_record) do
              create(
                :ai_active_context_collection,
                :code_collection,
                connection: connection
              )
            end

            it_behaves_like 'redirects to the search admin settings page'
          end
        end
      end
    end
  end

  shared_context 'when semantic search is available and collection can be configured' do
    before do
      allow(License).to receive(:ai_features_available?).and_return(true)
      allow(::Gitlab::CurrentSettings).to receive(:duo_features_enabled?).and_return(true)
      allow(Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(true)
    end

    let_it_be(:connection) { create(:ai_active_context_connection, :elasticsearch) }

    let(:collection_key) { :code }
    let_it_be_with_reload(:collection_record) do
      create(
        :ai_active_context_collection,
        :code_collection,
        connection: connection
      )
    end
  end

  shared_examples 'does not show the model update form' do
    it 'displays the model details but does not show the update form' do
      collection_record.reload.update_metadata!(
        current_indexing_embedding_model: {
          model_type: :gitlab_managed,
          model_ref: 'text_embedding_005_vertex',
          field: 'test_embeddings_v1',
          dimensions: 768
        }
      )

      send_request

      expect(response.body).to have_css(
        "[data-testid='semantic-search-display-embedding-model-current']",
        text: /Gitlab-managed \| text-embedding-005 - Vertex \| 768/
      )

      expect(flash[:notice]).to eq(expected_flash_notice)
      expect(response.body).to have_css('[data-testid="semantic-search-embeddings"]')
      expect(response.body).not_to have_css('[data-testid="semantic-search-embeddings-form"]')
    end
  end

  shared_examples 'does not update the embedding model' do
    it 'does not update the embedding and shows a warning' do
      expect(::Ai::ActiveContext::EmbeddingModelActivationService).not_to receive(:new)

      send_request

      expect(flash[:alert]).to eq(expected_flash_alert)
      expect(response.body).to have_css('[data-testid="semantic-search-embeddings"]')
    end
  end

  shared_examples 'returns an error json response' do
    it 'returns an error json response' do
      send_request

      expect(response).to have_gitlab_http_status(expected_status)

      json_response = ::Gitlab::Json.safe_parse(response.body)
      expect(json_response['success']).to be(false)
      expect(json_response['message']).to eq(expected_message)
      expect(json_response['tested_model_metadata']).to be_nil
    end
  end

  def expect_inputs_disabled(response)
    expect(response.body).to have_css(
      "[data-testid='semantic-search-embeddings-model'][disabled='disabled']"
    )
    expect(response.body).to have_css(
      "[data-testid='semantic-search-embeddings-dimensions'][disabled='disabled']"
    )
    expect(response.body).to have_css(
      "[data-testid='semantic-search-embeddings-submit-button'][disabled='disabled']"
    )
  end

  describe 'GET #show' do
    subject(:send_request) do
      get admin_application_settings_semantic_search_embedding_path(collection_key.to_s)
    end

    let(:collection_key) { :code }

    it_behaves_like 'redirects logged-out users'
    it_behaves_like 'not available for non-admin users'

    context 'for admin user' do
      before do
        sign_in(admin)
      end

      it_behaves_like 'checks semantic search and collection availability'

      context 'when semantic search is available and collection can be configured' do
        include_context 'when semantic search is available and collection can be configured'

        context 'when instance does not support user model selection' do
          before do
            allow(::Ai::ActiveContext).to receive(:user_selects_embedding_model?).and_return(false)
          end

          it_behaves_like 'does not show the model update form' do
            let(:expected_flash_notice) { 'Model selection by user is not available in this GitLab instance.' }
          end
        end

        context 'when user does not have permissions to update AI models' do
          before do
            allow(::Ai::ActiveContext).to receive(:user_selects_embedding_model?).and_return(true)
            allow(admin).to receive(:can?).with(:manage_instance_model_selection).and_return(false)
          end

          it_behaves_like 'does not show the model update form' do
            let(:expected_flash_notice) { 'You do not have sufficient permissions to update the model.' }
          end
        end

        context 'when user can update the embedding model' do
          before do
            allow(::Ai::ActiveContext).to receive_messages(
              gitlab_selects_embedding_model?: false,
              user_selects_embedding_model?: true
            )
            allow(admin).to receive(:can?).with(:manage_instance_model_selection).and_return(true)
          end

          it 'allows setting the model without warnings' do
            send_request

            expect(response.body).to have_css(
              "[data-testid='semantic-search-embeddings-model']:not([disabled])"
            )
            expect(response.body).to have_css(
              "[data-testid='semantic-search-embeddings-dimensions']:not([disabled])"
            )
            expect(response.body).to have_css(
              "[data-testid='semantic-search-embeddings-submit-button']:not([disabled])",
              text: 'Set embeddings'
            )
          end

          context 'when collection record has current embedding model' do
            before do
              collection_record.reload.update_metadata!(
                current_indexing_embedding_model: {
                  model_type: current_model_type,
                  model_ref: current_model_ref,
                  field: 'test_embeddings_v1',
                  dimensions: 768
                }
              )
            end

            let(:current_model_type) { :gitlab_managed }
            let(:current_model_ref) { 'text_embedding_005_vertex' }

            it 'displays the correct model information, allows update with warnings' do
              send_request

              expect(response.body).to have_css(
                "[data-testid='semantic-search-display-embedding-model-current']",
                text: /Gitlab-managed \| text-embedding-005 - Vertex \| 768/
              )

              expect(response.body).to have_css(
                "[data-testid='semantic-search-embeddings-model']:not([disabled]) " \
                  "option[selected][value='gitlab_managed__text_embedding_005_vertex']"
              )
              expect(response.body).to have_css(
                "[data-testid='semantic-search-embeddings-dimensions'][value='768']:not([disabled])"
              )

              expect(response.body).to have_css(
                '[data-testid="semantic-search-embeddings-update-warning"]'
              )
              expect(response.body).to have_css(
                '[data-testid="semantic-search-embeddings-submit-button"]:not([disabled])',
                text: 'Update embeddings and start backfill process'
              )
            end

            context 'when current model_type is nil' do
              let(:current_model_type) { nil }

              it 'displays the correct model information without the model type' do
                send_request

                expect(response.body).not_to have_css(
                  "[data-testid='semantic-search-display-embedding-model-current']",
                  text: /Gitlab-managed/
                )
                expect(response.body).to have_css(
                  "[data-testid='semantic-search-display-embedding-model-current']",
                  text: /text-embedding-005 - Vertex \| 768/
                )
              end
            end

            context 'when current model is a self-hosted model' do
              let(:current_model_type) { :self_hosted }
              let(:current_model_ref) { self_hosted_embedding_model.id.to_s }

              it 'displays the correct model information' do
                send_request

                expect(response.body).to have_css(
                  "[data-testid='semantic-search-display-embedding-model-current']",
                  text: /Self-hosted \| Embedding Model 1 \| 768/
                )

                expect(response.body).to have_css(
                  "[data-testid='semantic-search-embeddings-model']:not([disabled]) " \
                    "option[selected][value='self_hosted__#{self_hosted_embedding_model.id}']"
                )
                expect(response.body).to have_css(
                  "[data-testid='semantic-search-embeddings-dimensions'][value='768']:not([disabled])"
                )
              end
            end
          end

          context 'when collection record has next embedding model' do
            before do
              collection_record.reload.update_metadata!(
                next_indexing_embedding_model: {
                  model_type: next_model_type,
                  model_ref: next_model_ref,
                  field: 'mock_embeddings_v1',
                  dimensions: 32
                }
              )
            end

            let(:next_model_type) { :gitlab_managed }
            let(:next_model_ref) { 'text_embedding_005_vertex' }

            it 'shows the next model details, but does not allow updates' do
              send_request

              expect(flash[:notice]).to eq(
                "You cannot update the model at this time. " \
                  "There is already a next embedding model."
              )

              expect(response.body).to have_css(
                "[data-testid='semantic-search-display-embedding-model-next']",
                text: /Gitlab-managed \| text-embedding-005 - Vertex \| 32/
              )

              expect(response.body).to have_css(
                "[data-testid='semantic-search-embeddings-model'] " \
                  "option[selected][value='gitlab_managed__text_embedding_005_vertex']"
              )
              expect(response.body).to have_css(
                "[data-testid='semantic-search-embeddings-dimensions'][value='32']"
              )

              expect_inputs_disabled(response)
            end

            context 'when next model is a self-hosted model' do
              let(:next_model_type) { :self_hosted }
              let(:next_model_ref) { self_hosted_embedding_model.id.to_s }

              it 'shows the next model details, but disables inputs and submit button' do
                send_request

                expect(response.body).to have_css(
                  "[data-testid='semantic-search-display-embedding-model-next']",
                  text: /Self-hosted \| Embedding Model 1 \| 32/
                )

                expect(response.body).to have_css(
                  "[data-testid='semantic-search-embeddings-model'] " \
                    "option[selected][value='self_hosted__#{self_hosted_embedding_model.id}']"
                )
                expect(response.body).to have_css(
                  "[data-testid='semantic-search-embeddings-dimensions'][value='32']"
                )

                expect_inputs_disabled(response)
              end
            end
          end

          describe 'chunking strategy' do
            context 'when collection record does not have embedding models' do
              before do
                collection_record.update_metadata!(
                  current_indexing_embedding_model: nil,
                  next_indexing_embedding_model: nil
                )
              end

              it 'renders the chunking strategy fields and does not show the text display' do
                send_request

                expect(response.body).to have_css('[data-testid="semantic-search-chunk-strategy-select"]')
                expect(response.body).to have_css('[data-testid="semantic-search-chunk-strategy-size-input"]')

                expect(response.body).not_to have_css(
                  "[data-testid='semantic-search-display-current-chunk-strategy']"
                )
              end
            end

            context 'when collection record has current embedding model' do
              before do
                collection_record.update_metadata!(
                  current_indexing_embedding_model: {
                    model_type: 'gitlab_managed',
                    model_ref: 'text_embedding_005_vertex',
                    field: 'test_embeddings_v1',
                    dimensions: 768
                  }
                )
              end

              it 'does not render the chunking strategy fields' do
                send_request

                expect(response.body).not_to have_css('[data-testid="semantic-search-chunk-strategy-select"]')
                expect(response.body).not_to have_css('[data-testid="semantic-search-chunk-strategy-size-input"]')
              end

              context 'when collection record has chunking strategy' do
                before do
                  collection_record.update!(
                    options: {
                      chunk_strategy: 'code_pre_bert',
                      chunk_strategy_size: 240
                    }
                  )
                end

                it 'shows the chunking strategy details' do
                  send_request

                  expect(response.body).to have_css(
                    "[data-testid='semantic-search-display-current-chunk-strategy']",
                    text: /Code Pre Bert \| 240/
                  )
                end
              end

              context 'when collection record does not have chunking strategy' do
                before do
                  collection_record.update!(
                    options: {
                      chunk_strategy: nil,
                      chunk_strategy_size: nil
                    }
                  )
                end

                it 'shows the default chunking strategy details' do
                  send_request

                  expect(response.body).to have_css(
                    "[data-testid='semantic-search-display-current-chunk-strategy']",
                    text: /Code Bytes \| 1000/
                  )
                end
              end
            end

            context 'when collection record has next embedding model' do
              before do
                collection_record.update_metadata!(
                  next_indexing_embedding_model: {
                    model_type: 'gitlab_managed',
                    model_ref: 'text_embedding_005_vertex',
                    field: 'test_embeddings_v1',
                    dimensions: 768
                  }
                )
              end

              it 'does not render the chunking strategy fields' do
                send_request

                expect(response.body).not_to have_css('[data-testid="semantic-search-chunk-strategy-select"]')
                expect(response.body).not_to have_css('[data-testid="semantic-search-chunk-strategy-size-input"]')
              end

              context 'when collection record does not have chunking strategy' do
                before do
                  collection_record.update!(
                    options: {
                      chunk_strategy: nil,
                      chunk_strategy_size: nil
                    }
                  )
                end

                it 'shows the default chunking strategy details' do
                  send_request

                  expect(response.body).to have_css(
                    "[data-testid='semantic-search-display-current-chunk-strategy']",
                    text: /Code Bytes \| 1000/
                  )
                end
              end

              context 'when collection record has chunking strategy' do
                before do
                  collection_record.update!(
                    options: {
                      chunk_strategy: 'code_pre_bert',
                      chunk_strategy_size: 240
                    }
                  )
                end

                it 'shows the chunking strategy details' do
                  send_request

                  expect(response.body).to have_css(
                    "[data-testid='semantic-search-display-current-chunk-strategy']",
                    text: /Code Pre Bert \| 240/
                  )
                end
              end
            end
          end
        end
      end
    end
  end

  describe 'PUT #update' do
    subject(:send_request) do
      put(
        admin_application_settings_semantic_search_embedding_path(collection_key.to_s),
        params: update_params
      )
    end

    let(:collection_key) { :code }
    let(:update_params) { {} }

    it_behaves_like 'redirects logged-out users'
    it_behaves_like 'not available for non-admin users'

    context 'for admin user' do
      before do
        sign_in(admin)
      end

      it_behaves_like 'checks semantic search and collection availability'

      context 'when semantic search is available and collection can be configured' do
        include_context 'when semantic search is available and collection can be configured'

        before do
          allow(::Ai::ActiveContext::EmbeddingModelActivationService).to receive(:new).and_call_original

          # mock task chain creation
          task_service = instance_double(::Ai::ActiveContext::TaskService, create_chain: nil)
          allow(::Ai::ActiveContext::TaskService).to receive(:new).and_return(task_service)

          # mock embedding model testing
          test_model_service = instance_double(Ai::ActiveContext::TestEmbeddingModelService)
          allow(test_model_service).to receive(:execute).and_return(ServiceResponse.success)
          allow(Ai::ActiveContext::TestEmbeddingModelService).to receive(:new).and_return(test_model_service)
          allow(Ai::FeatureSetting).to receive(:allowed_features).and_return(['embeddings_code'])
        end

        context 'when instance does not support user model selection' do
          before do
            allow(::Ai::ActiveContext).to receive(:user_selects_embedding_model?).and_return(false)
          end

          it_behaves_like 'does not update the embedding model' do
            let(:expected_flash_alert) { 'Model selection by user is not available in this GitLab instance.' }
          end
        end

        context 'when user does not have permissions to update AI models' do
          before do
            allow(::Ai::ActiveContext).to receive(:user_selects_embedding_model?).and_return(true)
            allow(admin).to receive(:can?).with(:manage_instance_model_selection).and_return(false)
          end

          it_behaves_like 'does not update the embedding model' do
            let(:expected_flash_alert) { 'You do not have sufficient permissions to update the model.' }
          end
        end

        context 'when user can update the embedding model' do
          before do
            allow(::Ai::ActiveContext).to receive_messages(
              gitlab_selects_embedding_model?: false,
              user_selects_embedding_model?: true
            )
            allow(admin).to receive(:can?).with(:manage_instance_model_selection).and_return(true)
          end

          context 'when embedding_model is not present' do
            let(:update_params) { { embedding_model: nil, embedding_dimensions: 768 } }

            it_behaves_like 'does not update the embedding model' do
              let(:expected_flash_alert) do
                suffix = Gitlab.next_rails? ? 'empty or invalid' : 'empty'
                "Error: param is missing or the value is #{suffix}: embedding_model."
              end
            end
          end

          context 'when embedding_dimensions is not present' do
            let(:update_params) { { embedding_model: 'gitlab_managed__test_model_1', embedding_dimensions: nil } }

            it_behaves_like 'does not update the embedding model' do
              let(:expected_flash_alert) do
                suffix = Gitlab.next_rails? ? 'empty or invalid' : 'empty'
                "Error: param is missing or the value is #{suffix}: embedding_dimensions."
              end
            end
          end

          context 'when required params are present' do
            before do
              collection_record.reload.update_metadata!(
                current_indexing_embedding_model: nil
              )
            end

            let(:update_params) do
              {
                embedding_model: 'gitlab_managed__text_embedding_005_vertex',
                embedding_dimensions: 768
              }
            end

            it 'sets the embedding and disables inputs' do
              expect(::Ai::ActiveContext::EmbeddingModelActivationService).to receive(:new)
              expect(::Ai::ActiveContext::TestEmbeddingModelService).to receive(:new)

              send_request

              expect(flash[:notice]).to eq('Embedding model has been set.')

              expect(response.body).to have_css(
                "[data-testid='semantic-search-display-embedding-model-next']",
                text: /Gitlab-managed \| text-embedding-005 - Vertex \| 768/
              )

              expect_inputs_disabled(response)
            end

            context 'when selected model is a self-hosted model' do
              let(:update_params) do
                {
                  embedding_model: "self_hosted__#{self_hosted_embedding_model.id}",
                  embedding_dimensions: 768
                }
              end

              it 'sets the embedding and disables inputs' do
                expect(::Ai::ActiveContext::EmbeddingModelActivationService).to receive(:new)
                expect(::Ai::ActiveContext::TestEmbeddingModelService).to receive(:new)

                send_request

                expect(flash[:notice]).to eq('Embedding model has been set.')

                expect(response.body).to have_css(
                  "[data-testid='semantic-search-display-embedding-model-next']",
                  text: /Self-hosted \| Embedding Model 1 \| 768/
                )

                expect_inputs_disabled(response)
              end
            end

            context 'when collection record already has a current embedding model' do
              before do
                collection_record.reload.update_metadata!(
                  current_indexing_embedding_model: {
                    model_type: :gitlab_managed,
                    model_ref: 'embedding_model_001_test',
                    field: 'test_embeddings_v1',
                    dimensions: 32
                  }
                )
              end

              let(:update_params) do
                {
                  embedding_model: 'gitlab_managed__text_embedding_005_vertex',
                  embedding_dimensions: 768
                }
              end

              it 'updates the embedding and disables inputs' do
                expect(::Ai::ActiveContext::EmbeddingModelActivationService).to receive(:new)
                expect(::Ai::ActiveContext::TestEmbeddingModelService).to receive(:new)

                send_request

                expect(flash[:notice]).to eq('Embeddings updated and backfill started.')

                expect(response.body).to have_css(
                  "[data-testid='semantic-search-display-embedding-model-next']",
                  text: /Gitlab-managed \| text-embedding-005 - Vertex \| 768/
                )

                expect_inputs_disabled(response)
              end
            end

            context 'when params include a tested model metadata' do
              let(:update_params) do
                {
                  embedding_model: 'gitlab_managed__text_embedding_005_vertex',
                  embedding_dimensions: 768,
                  tested_model_metadata: tested_model_metadata
                }
              end

              context 'when tested model metadata does not match the model update params' do
                let(:tested_model_metadata) do
                  {
                    model_type: 'gitlab_managed',
                    model_ref: 'text_embedding_005_vertex',
                    dimensions: 32
                  }.to_json
                end

                it 'performs embeddings request testing before updating the model' do
                  expect(::Ai::ActiveContext::TestEmbeddingModelService).to receive(:new).with(
                    collection_class: ::Ai::ActiveContext::Collections::Code,
                    model_type: :gitlab_managed,
                    model_ref: 'text_embedding_005_vertex',
                    dimensions: 768
                  )

                  send_request

                  expect(response.body).to have_css(
                    "[data-testid='semantic-search-display-embedding-model-next']",
                    text: /Gitlab-managed \| text-embedding-005 - Vertex \| 768/
                  )
                end
              end

              context 'when tested model metadata matches model update params' do
                let(:tested_model_metadata) do
                  {
                    model_type: 'gitlab_managed',
                    model_ref: 'text_embedding_005_vertex',
                    dimensions: 768
                  }.to_json
                end

                it 'does not perform embeddings request testing' do
                  expect(::Ai::ActiveContext::TestEmbeddingModelService).not_to receive(:new)

                  send_request

                  expect(response.body).to have_css(
                    "[data-testid='semantic-search-display-embedding-model-next']",
                    text: /Gitlab-managed \| text-embedding-005 - Vertex \| 768/
                  )
                end
              end

              context 'when tested model metadata is an empty string' do
                let(:tested_model_metadata) { '' }

                it 'performs embeddings request testing before updating the model' do
                  expect(::Ai::ActiveContext::TestEmbeddingModelService).to receive(:new).with(
                    collection_class: ::Ai::ActiveContext::Collections::Code,
                    model_type: :gitlab_managed,
                    model_ref: 'text_embedding_005_vertex',
                    dimensions: 768
                  )

                  send_request

                  expect(response.body).to have_css(
                    "[data-testid='semantic-search-display-embedding-model-next']",
                    text: /Gitlab-managed \| text-embedding-005 - Vertex \| 768/
                  )
                end
              end
            end

            context 'when params include chunking strategies' do
              let(:update_params) do
                {
                  embedding_model: 'gitlab_managed__text_embedding_005_vertex',
                  embedding_dimensions: 768
                }.merge(chunking_strategy_params)
              end

              let(:chunking_strategy_params) do
                {
                  chunk_strategy: 'code_pre_bert',
                  chunk_strategy_size: 240
                }
              end

              it 'sets the chunking strategy and does not render inputs' do
                send_request

                expect(response.body).to have_css(
                  "[data-testid='semantic-search-display-current-chunk-strategy']",
                  text: /Code Pre Bert \| 240/
                )

                expect(response.body).not_to have_css("[data-testid='semantic-search-chunk-strategy-select']")
                expect(response.body).not_to have_css("[data-testid='semantic-search-chunk-strategy-size-input']")
              end
            end

            context 'when EmbeddingModelActivationService throws an expected error' do
              it 'shows the error and fills the form with the update params' do
                allow(::Ai::ActiveContext::EmbeddingModelActivationService).to receive(:new).and_raise(
                  ::Ai::ActiveContext::EmbeddingModelActivationService::Error,
                  "embedding model activation service failed"
                )

                send_request

                expect(flash[:alert]).to eq('Update failed: embedding model activation service failed.')

                expect(response.body).not_to have_css(
                  "[data-testid='semantic-search-display-embedding-model-next']"
                )
                expect(response.body).to have_css(
                  "[data-testid='semantic-search-embeddings-model']:not([disabled]) " \
                    "option[selected][value='gitlab_managed__text_embedding_005_vertex']"
                )
                expect(response.body).to have_css(
                  "[data-testid='semantic-search-embeddings-dimensions'][value='768']:not([disabled])"
                )
              end
            end

            context 'when EmbeddingModelActivationService throws an unexpected error' do
              before do
                allow(::Ai::ActiveContext::EmbeddingModelActivationService).to receive(:new).and_raise(
                  StandardError, "there is an error"
                )
              end

              it 'shows an unknown error warning and fills the form with the update params' do
                send_request

                expect(flash[:alert]).to eq('Update failed: unknown error.')

                expect(response.body).not_to have_css(
                  "[data-testid='semantic-search-display-embedding-model-next']"
                )
                expect(response.body).to have_css(
                  "[data-testid='semantic-search-embeddings-model']:not([disabled]) " \
                    "option[selected][value='gitlab_managed__text_embedding_005_vertex']"
                )
                expect(response.body).to have_css(
                  "[data-testid='semantic-search-embeddings-dimensions'][value='768']:not([disabled])"
                )
              end

              it 'logs the error with class_name in the payload' do
                logger = ::Logger.new(File::NULL)
                allow(::ActiveContext::Config).to receive(:logger).and_return(logger)

                expect(logger).to receive(:error).with(
                  a_hash_including('class_name' => described_class.name, 'message' => 'there is an error')
                )

                send_request
              end
            end
          end
        end
      end
    end
  end

  describe 'POST #test_model_configuration' do
    subject(:send_request) do
      post(
        test_model_configuration_admin_application_settings_semantic_search_embedding_path(
          collection_key.to_s
        ),
        params: update_params
      )
    end

    let(:collection_key) { :code }
    let(:update_params) { {} }

    it_behaves_like 'redirects logged-out users'
    it_behaves_like 'not available for non-admin users'

    context 'for admin user' do
      before do
        sign_in(admin)
      end

      it_behaves_like 'checks semantic search and collection availability'

      context 'when semantic search is available and collection can be configured' do
        include_context 'when semantic search is available and collection can be configured'

        context 'when instance does not support user model selection' do
          before do
            allow(::Ai::ActiveContext).to receive(:user_selects_embedding_model?).and_return(false)
          end

          it_behaves_like 'returns an error json response' do
            let(:expected_status) { :unauthorized }
            let(:expected_message) { 'Model selection by user is not available in this GitLab instance.' }
          end
        end

        context 'when user does not have permissions to update AI models' do
          before do
            allow(::Ai::ActiveContext).to receive(:user_selects_embedding_model?).and_return(true)
            allow(admin).to receive(:can?).with(:manage_instance_model_selection).and_return(false)
          end

          it_behaves_like 'returns an error json response' do
            let(:expected_status) { :unauthorized }
            let(:expected_message) { 'You do not have sufficient permissions to update the model.' }
          end
        end

        context 'when user can update the embedding model' do
          before do
            allow(::Ai::ActiveContext).to receive_messages(
              gitlab_selects_embedding_model?: false,
              user_selects_embedding_model?: true
            )
            allow(admin).to receive(:can?).with(:manage_instance_model_selection).and_return(true)
          end

          context 'when embedding_model is not present' do
            let(:update_params) { { embedding_model: nil, embedding_dimensions: 768 } }

            it_behaves_like 'returns an error json response' do
              let(:expected_status) { :bad_request }
              let(:expected_message) do
                suffix = Gitlab.next_rails? ? 'empty or invalid' : 'empty'
                "Error: param is missing or the value is #{suffix}: embedding_model."
              end
            end
          end

          context 'when embedding_dimensions is not present' do
            let(:update_params) { { embedding_model: 'gitlab_managed__test_model_1', embedding_dimensions: nil } }

            it_behaves_like 'returns an error json response' do
              let(:expected_status) { :bad_request }
              let(:expected_message) do
                suffix = Gitlab.next_rails? ? 'empty or invalid' : 'empty'
                "Error: param is missing or the value is #{suffix}: embedding_dimensions."
              end
            end
          end

          context 'when required params are present' do
            before do
              allow(test_model_service).to receive(:execute).and_return(test_model_response)
              allow(Ai::ActiveContext::TestEmbeddingModelService).to receive(:new).and_return(test_model_service)
            end

            let(:test_model_service) { instance_double(Ai::ActiveContext::TestEmbeddingModelService) }
            let(:test_model_response) { ServiceResponse.success }

            let(:update_params) do
              {
                embedding_model: 'gitlab_managed__text_embedding_005_vertex',
                embedding_dimensions: 768
              }
            end

            context 'when model configuration testing returns successful response' do
              let(:test_model_response) do
                ServiceResponse.success(
                  payload: {
                    tested_model_metadata: {
                      model_type: :gitlab_managed,
                      model_ref: 'text_embedding_005_vertex',
                      dimensions: 768
                    }
                  }
                )
              end

              it 'returns a successful response with the payload' do
                send_request

                expect(response).to have_gitlab_http_status(:ok)

                json_response = ::Gitlab::Json.safe_parse(response.body)
                expect(json_response['success']).to be(true)
                expect(json_response['tested_model_metadata']).to eq(
                  {
                    'model_type' => 'gitlab_managed',
                    'model_ref' => 'text_embedding_005_vertex',
                    'dimensions' => 768
                  }
                )
              end
            end

            context 'when model configuration testing returns an error response' do
              let(:test_model_response) { ServiceResponse.error(message: 'model testing error') }

              it_behaves_like 'returns an error json response' do
                let(:expected_status) { :unprocessable_entity }
                let(:expected_message) { 'model testing error' }
              end
            end

            context 'when there is an unexpected error' do
              before do
                allow(test_model_service).to receive(:execute).and_raise(
                  StandardError, "some error"
                )
              end

              it_behaves_like 'returns an error json response' do
                let(:expected_status) { :unprocessable_entity }
                let(:expected_message) { 'unknown error' }
              end
            end
          end
        end
      end
    end
  end
end
