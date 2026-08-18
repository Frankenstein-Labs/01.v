# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Queries::Code, feature_category: :code_suggestions do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let(:search_term) { 'dummy search term' }

  let_it_be(:indexing_embedding_key) { :current_indexing_embedding_model }
  let_it_be(:indexing_embedding_valid_value) do
    { model_ref: 'text_embedding_005_vertex', field: 'test_field_123' }
  end

  let_it_be(:search_embedding_key) { :search_embedding_model }
  let_it_be(:search_embedding_valid_value) { indexing_embedding_valid_value }

  subject(:codebase_query) { described_class.new(search_term: search_term, user: user) }

  before do
    allow(::ActiveContext).to receive_message_chain(:adapter, :full_collection_name)
      .and_return(ActiveContextHelpers.code_collection_name)
  end

  describe '.available?' do
    subject(:available) { described_class.available? }

    context 'when ActiveContext indexing is disabled' do
      before do
        allow(::ActiveContext).to receive(:indexing?).and_return(false)
      end

      it { is_expected.to be(false) }
    end

    context 'when ActiveContext indexing is enabled' do
      before do
        allow(::ActiveContext).to receive(:indexing?).and_return(true)
      end

      context 'when code collection record does not exist' do
        it { is_expected.to be(false) }
      end

      context 'when code collection record exists' do
        let_it_be_with_reload(:collection_record) do
          create(:ai_active_context_collection, :code_collection)
        end

        it { is_expected.to be(false) }

        context 'when code collection has no search embedding model' do
          before do
            collection_record.update_metadata!(
              indexing_embedding_key => indexing_embedding_valid_value,
              search_embedding_key => nil
            )
          end

          it { is_expected.to be(false) }
        end

        context 'when code collection has no indexing embedding models' do
          before do
            collection_record.update_metadata!(
              indexing_embedding_key => nil,
              search_embedding_key => search_embedding_valid_value
            )
          end

          it { is_expected.to be(false) }
        end

        context 'when code collection record has valid embedding models' do
          before do
            collection_record.update_metadata!(
              indexing_embedding_key => indexing_embedding_valid_value,
              search_embedding_key => search_embedding_valid_value
            )
          end

          it 'returns false if feature setting is not allowed' do
            allow(Ai::ActiveContext::Collections::Code).to receive(:feature_setting_allowed?).and_return(false)
            expect(available).to be(false)
          end

          it 'returns true if feature setting is allowed' do
            allow(Ai::ActiveContext::Collections::Code).to receive(:feature_setting_allowed?).and_return(true)
            expect(available).to be(true)
          end
        end
      end
    end
  end

  describe '#filter' do
    context 'when semantic search is not available' do
      let(:expected_error_class) { Ai::ActiveContext::Queries::Code::NotAvailable }

      before do
        allow(::ActiveContext).to receive(:indexing?).and_return(false)
      end

      it 'raises the expected error' do
        expect { codebase_query.filter(project_or_id: project) }.to raise_error(
          expected_error_class, "Semantic search on Code collection is not available."
        )
      end
    end

    context 'when semantic search is available' do
      before do
        allow(::ActiveContext::Logger).to receive(:info)
        allow(::ActiveContext).to receive(:indexing?).and_return(true)

        allow_next_instance_of(::ActiveContext::EmbeddingModel) do |embedding_model|
          allow(embedding_model).to receive(:generate_embeddings).with(
            search_term, user: user
          ).and_return([target_embeddings])
        end

        # mock code collections search, with different results depending on project_id
        allow(::Ai::ActiveContext::Collections::Code).to receive(:search) do |args|
          project_id = args[:query].children.first.children.first.value[:project_id]

          es_docs = elasticsearch_docs[project_id]
          build_es_query_result(es_docs)
        end
      end

      let_it_be(:collection) do
        create(:ai_active_context_collection, :code_collection).tap do |c|
          c.update_metadata!(
            indexing_embedding_key => indexing_embedding_valid_value,
            search_embedding_key => search_embedding_valid_value
          )
        end
      end

      let_it_be(:root_namespace) { create(:group) }
      let_it_be(:enabled_namespace) do
        create(
          :ai_active_context_code_enabled_namespace,
          :ready,
          namespace: root_namespace,
          active_context_connection: collection.connection
        )
      end

      let_it_be(:sub_group) { create(:group, parent: root_namespace) }

      let_it_be(:project) do
        create(:project, group: sub_group, owners: [user]).tap do |p|
          attach_active_context_repository(project: p, collection: collection, enabled_namespace: enabled_namespace)
        end
      end

      let_it_be(:project_2) do
        create(:project, group: sub_group, developers: [user]).tap do |p|
          attach_active_context_repository(project: p, collection: collection, enabled_namespace: enabled_namespace)
        end
      end

      let(:target_embeddings) { [1, 2, 3] }

      let(:elasticsearch_docs) do
        {
          project.id => [
            {
              '_source' => {
                'id' => 1,
                'project_id' => project.id,
                'content' => "test content 1-1",
                'path' => 'path/p1/one.rb',
                'name' => 'one.rb',
                'language' => 'ruby',
                'source' => 'a99909a7fa51ffd3fe6f9de3ab47dfbf2f59a9d1::0:546::0',
                'embeddings_v1' => Array.new(768, 0.0)
              },
              '_score' => 0.95
            },
            {
              '_source' => {
                'id' => 1,
                'project_id' => project.id,
                'content' => "test content 1-2",
                'path' => 'path/p1/two.rb',
                'name' => 'two.rb',
                'language' => 'ruby',
                'source' => 'a99909a7fa51ffd3fe6f9de3ab47dfbf2f5910d1::600:546::10',
                'embeddings_v1' => Array.new(768, 0.0)
              },
              '_score' => 0.85
            }
          ],
          project_2.id => [
            {
              '_source' => {
                'id' => 2,
                'project_id' => project_2.id,
                'content' => "test content 2-1",
                'path' => 'path/p2/test.rb',
                'name' => 'test.rb',
                'language' => 'ruby',
                'source' => 'a99909a7fa51ffd3fe6f9de3ab47dfbf2f5911d1::0:546::0',
                'embeddings_v1' => Array.new(768, 0.0)
              },
              '_score' => 0.80
            }
          ]
        }
      end

      let(:expected_search_target_field) { search_embedding_valid_value[:field].to_sym }
      let(:expected_embeddings_generation_caller) { "ActiveContext::EmbeddingModel" }

      it 'generates embeddings only once for multiple filters' do
        expect(codebase_query).to receive(:generate_target_embeddings).once.and_call_original

        codebase_query.filter(project_or_id: project)
        codebase_query.filter(project_or_id: project_2)
      end

      it 'calls a search on the Code collection class for each filter' do
        expect(::Ai::ActiveContext::Collections::Code).to receive(:search).twice

        codebase_query.filter(project_or_id: project)
        codebase_query.filter(project_or_id: project_2)
      end

      it 'sends the expected params to the Collection search method' do
        expect(::Ai::ActiveContext::Collections::Code).to receive(:search) do |args|
          user_id = args[:user].id
          expect(user_id).to eq(user.id)

          query_1 = args[:query]
          expect(query_1.type).to eq(:limit)
          expect(query_1.value).to eq(20)

          query_2 = args[:query].children.first
          expect(query_2.type).to eq(:knn)
          expect(query_2.value).to eq({
            target: expected_search_target_field,
            vector: target_embeddings,
            k: 64
          })

          query_3 = args[:query].children.first.children.first
          expect(query_3.type).to eq(:filter)
          expect(query_3.value).to eq({ project_id: project.id })

          # make sure to mock the result
          es_docs = elasticsearch_docs[project.id]
          build_es_query_result(es_docs)
        end

        codebase_query.filter(project_or_id: project)
      end

      it 'returns the expected results' do
        project_1_result = codebase_query.filter(project_or_id: project)
        expect(project_1_result).to be_success
        expect(project_1_result.to_a).to eq(
          elasticsearch_docs[project.id].map { |doc| doc['_source'].merge('score' => doc['_score']) }
        )

        project_2_result = codebase_query.filter(project_or_id: project_2)
        expect(project_2_result).to be_success
        expect(project_2_result.to_a).to eq(
          elasticsearch_docs[project_2.id].map { |doc| doc['_source'].merge('score' => doc['_score']) }
        )
      end

      describe 'setting last_queried_at', :freeze_time do
        let(:ac_repository) { project.reload.ready_active_context_code_repository }

        before do
          ac_repository.update!(last_queried_at: nil)
        end

        it 'updates the last queried timestamp of the active_context repository records', :freeze_time do
          expect { codebase_query.filter(project_or_id: project) }
            .to change { ac_repository.reload.last_queried_at }.to(Time.current)
            .and not_change { project_2.reload.ready_active_context_code_repository.last_queried_at }
        end

        context 'when the last_queried_at of the active context repository record is already set' do
          context 'when last_queried_at is earlier than 1 hour ago' do
            before do
              ac_repository.update!(last_queried_at: Time.current - 2.hours)
            end

            it 'updates the last_queried_at', :freeze_time do
              expect { codebase_query.filter(project_or_id: project) }
                .to change { ac_repository.reload.last_queried_at }.to(Time.current)
                .and not_change { project_2.reload.ready_active_context_code_repository.last_queried_at }
            end
          end

          context 'when last_queried_at is later than 1 hour ago' do
            before do
              ac_repository.update!(last_queried_at: Time.current - 30.minutes)
            end

            it 'does not update the last_queried_at' do
              expect { codebase_query.filter(project_or_id: project) }
                .not_to change { ac_repository.reload.last_queried_at }
            end
          end
        end

        context 'when there is an error updating last_queried_at' do
          before do
            allow(ac_repository).to receive(:update_last_queried_timestamp).and_raise(
              ActiveRecord::ActiveRecordError, "There is an error"
            )

            allow(Ai::ActiveContext::Code::Repository).to receive(:find_by)
              .with(hash_including(project_id: project.id)).and_return(ac_repository)

            allow(::ActiveContext::Config).to receive(:logger).and_return(logger)
          end

          let(:logger) { instance_double(::Gitlab::ActiveContext::Logger, warn: nil) }

          it 'catches the error and logs it' do
            expect(logger).to receive(:warn).with({
              "class_name" => "Ai::ActiveContext::Queries::Code",
              "message" => "Failed to update last_queried_at",
              "exception_class" => "ActiveRecord::ActiveRecordError",
              "exception_message" => "There is an error",
              "ai_active_context_code_repository_id" => ac_repository.id,
              "project_id" => project.id
            })

            expect { codebase_query.filter(project_or_id: project) }.not_to raise_error
          end
        end
      end

      context 'when exclude_fields, extract_source_segments, and build_file_url are provided' do
        it 'returns the expected results' do
          project_1_result = codebase_query.filter(
            project_or_id: project,
            exclude_fields: %w[id source type embeddings_v1 reindexing],
            extract_source_segments: true,
            build_file_url: true
          )

          expect(project_1_result).to be_success

          base_file_url = "http://localhost/#{project.full_path}/-/blob/main/"
          expect(project_1_result).to match_array([
            {
              'project_id' => project.id,
              'path' => 'path/p1/one.rb',
              'name' => 'one.rb',
              'language' => 'ruby',
              'content' => "test content 1-1",
              'blob_id' => "a99909a7fa51ffd3fe6f9de3ab47dfbf2f59a9d1",
              'start_byte' => 0,
              'length' => 546,
              'start_line' => 0,
              'score' => 0.95,
              'file_url' => File.join(base_file_url, 'path/p1/one.rb')
            },
            {
              'project_id' => project.id,
              'path' => 'path/p1/two.rb',
              'name' => 'two.rb',
              'language' => 'ruby',
              'content' => "test content 1-2",
              'blob_id' => 'a99909a7fa51ffd3fe6f9de3ab47dfbf2f5910d1',
              'start_byte' => 600,
              'length' => 546,
              'start_line' => 10,
              'score' => 0.85,
              'file_url' => File.join(base_file_url, 'path/p1/two.rb')
            }
          ])
        end
      end

      context 'when filtering by path' do
        let(:project_es_docs_in_path) do
          [
            {
              '_source' => {
                'id' => 1,
                'project_id' => project.id,
                'content' => "test content in path",
                'path' => 'path/p1/test.rb',
                'name' => 'test.rb',
                'language' => 'ruby',
                'source' => 'a99909a7fa51ffd3fe6f9de3ab47dfbf2f59a9d::0:546::0',
                'embeddings_v1' => Array.new(768, 0.0)
              },
              '_score' => 0.90
            }
          ]
        end

        it 'passes the correct query parameters to search and returns the expected results' do
          allow(::Ai::ActiveContext::Collections::Code).to receive(:search) do |args|
            and_query = args[:query].children.first.children.first.children
            first_query = and_query.first
            second_query = and_query.second

            expect(first_query.type).to eq(:filter)
            expect(first_query.value).to eq({ project_id: project.id })

            expect(second_query.type).to eq(:prefix)
            expect(second_query.value).to eq({ path: 'path/p1/' })

            # make sure to return query results
            build_es_query_result(project_es_docs_in_path)
          end

          result = codebase_query.filter(project_or_id: project, path: 'path/p1')
          expect(result).to be_success
          expect(result.each.to_a).to eq(
            project_es_docs_in_path.map { |doc| doc['_source'].merge('score' => doc['_score']) }
          )
        end
      end

      context 'when an existing project ID is used as project parameter' do
        it 'calls a search on the project and returns the expected results' do
          expect(::Ai::ActiveContext::Collections::Code).to receive(:search).twice

          project_1_result = codebase_query.filter(project_or_id: project.id)
          expect(project_1_result).to be_success
          expect(project_1_result.to_a).to eq(
            elasticsearch_docs[project.id].map { |doc| doc['_source'].merge('score' => doc['_score']) }
          )

          project_2_result = codebase_query.filter(project_or_id: project_2.id.to_s)
          expect(project_2_result).to be_success
          expect(project_2_result.to_a).to eq(
            elasticsearch_docs[project_2.id].map { |doc| doc['_source'].merge('score' => doc['_score']) }
          )
        end
      end

      context 'when invalid project parameters are used' do
        context 'when project with given ID does not exist' do
          it 'raises an error' do
            expect(::Ai::ActiveContext::Collections::Code).not_to receive(:search)

            expect { codebase_query.filter(project_or_id: 0) }.to raise_error(
              described_class::ProjectNotFound, "Could not find project: 0."
            )
          end
        end

        context 'with unexpected project parameter type' do
          it 'raises an error' do
            expect(::Ai::ActiveContext::Collections::Code).not_to receive(:search)

            expect { codebase_query.filter(project_or_id: false) }.to raise_error(
              described_class::ProjectNotFound,
              "Project parameter must be a Project object or ID, got FalseClass."
            )
          end
        end
      end

      context 'when a project has no code embeddings' do
        shared_examples 'returns no code embeddings error result' do
          it 'returns a result with the expected error_code and error_message' do
            expect(result).not_to be_success
            expect(result.error_code).to eq(Ai::ActiveContext::Queries::Result::ERROR_NO_EMBEDDINGS)

            expect(result.error_message(target_class: Project, target_id: project_id)).to eq(
              "Project '#{project_id}' has no embeddings - #{expected_error_detail}"
            )
          end
        end

        let(:result) { codebase_query.filter(project_or_id: project_id) }

        before do
          allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?)
            .with(:semantic_code_search_ad_hoc_indexing, anything)
            .and_return(false)
        end

        context 'when project has no ActiveContext repository record' do
          before do
            project.reload.ready_active_context_code_repository.destroy!

            allow(Ai::ActiveContext::Code::AdHocIndexingWorker).to receive(:perform_async).and_return(true)
          end

          let(:project_id) { project.id }

          it 'prioritizes cached value when checking eligibility' do
            expect(Rails.cache).to receive(:fetch).with(
              "active_context_code_eligible_project_#{project.id}",
              expires_in: described_class::CODE_ELIGIBILITY_CACHE_EXPIRY,
              force: false
            ).and_call_original

            result
          end

          it 'triggers ad-hoc indexing' do
            expect(Ai::ActiveContext::Code::AdHocIndexingWorker).to receive(:perform_async).with(project.id)

            result
          end

          it_behaves_like 'returns no code embeddings error result' do
            let(:expected_error_detail) { described_class::MESSAGE_INITIAL_INDEXING_STARTED }
          end

          context 'when triggering the ad-hoc indexing worker returns a falsey value' do
            before do
              allow(Ai::ActiveContext::Code::AdHocIndexingWorker).to receive(:perform_async)
                .and_return(nil)
            end

            it_behaves_like 'returns no code embeddings error result' do
              let(:expected_error_detail) { described_class::MESSAGE_ADHOC_INDEXING_TRIGGER_FAILED }
            end
          end

          context 'when ad-hoc indexing is rate limited for the namespace' do
            before do
              allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?)
                .with(:semantic_code_search_ad_hoc_indexing, scope: [root_namespace])
                .and_return(true)

              allow(::ActiveContext::Config).to receive(:logger).and_return(logger)
            end

            let(:logger) { instance_double(::Gitlab::ActiveContext::Logger, warn: nil) }

            it 'does not trigger ad-hoc indexing' do
              expect(Ai::ActiveContext::Code::AdHocIndexingWorker).not_to receive(:perform_async)

              result
            end

            it 'logs a warning' do
              expect(logger).to receive(:warn).with({
                "class_name" => "Ai::ActiveContext::Queries::Code",
                "message" => "Ad-hoc indexing rate limited for namespace",
                "project_id" => project.id,
                "namespace_id" => root_namespace.id
              })

              result
            end

            it_behaves_like 'returns no code embeddings error result' do
              let(:expected_error_detail) do
                [
                  described_class::MESSAGE_ADHOC_INDEXING_TRIGGER_FAILED,
                  described_class::MESSAGE_INDEXING_RATE_LIMITED
                ].join(', ')
              end
            end
          end

          context 'when ad-hoc indexing attempt fails' do
            before do
              allow(Ai::ActiveContext::Code::AdHocIndexingWorker).to receive(:perform_async)
                .and_raise(StandardError, "There is an error")

              allow(::ActiveContext::Config).to receive(:logger).and_return(logger)
            end

            let(:logger) { instance_double(::Gitlab::ActiveContext::Logger, warn: nil) }

            it 'logs the error' do
              expect(logger).to receive(:warn).with({
                "class_name" => "Ai::ActiveContext::Queries::Code",
                "message" => "Failed to trigger ad-hoc indexing",
                "exception_class" => "StandardError",
                "exception_message" => "There is an error",
                "project_id" => project_id
              })

              result
            end

            it_behaves_like 'returns no code embeddings error result' do
              let(:expected_error_detail) { described_class::MESSAGE_ADHOC_INDEXING_TRIGGER_FAILED }
            end
          end

          context "when on saas, not GA, and project's root namespace has experiment features enabled" do
            before do
              stub_feature_flags(semantic_code_search_saas_ga: false)
              root_namespace.reload.namespace_settings.update!(experiment_features_enabled: true)
            end

            it 'triggers ad-hoc indexing' do
              expect(Ai::ActiveContext::Code::AdHocIndexingWorker).to receive(:perform_async).with(project.id)

              result
            end

            it_behaves_like 'returns no code embeddings error result' do
              let(:expected_error_detail) { described_class::MESSAGE_INITIAL_INDEXING_STARTED }
            end
          end

          context "when not on saas, not GA, and project's root namespace has experiment features disabled" do
            before do
              allow(::License).to receive(:ai_features_available?).and_return(true)
              stub_feature_flags(semantic_code_search_saas_ga: false)
              root_namespace.reload.namespace_settings.update!(experiment_features_enabled: false)
            end

            it 'triggers ad-hoc indexing' do
              expect(Ai::ActiveContext::Code::AdHocIndexingWorker).to receive(:perform_async).with(project.id)

              result
            end

            it_behaves_like 'returns no code embeddings error result' do
              let(:expected_error_detail) { described_class::MESSAGE_INITIAL_INDEXING_STARTED }
            end
          end

          context 'when not eligible for code embeddings' do
            shared_examples 'returns an error result with "use another source" message' do
              it_behaves_like 'returns no code embeddings error result' do
                let(:expected_error_detail) { described_class::MESSAGE_NOT_ELIGIBLE }
              end
            end

            context 'when project has duo_features_enabled setting = false' do
              before do
                project.project_setting.update!(duo_features_enabled: false)
              end

              it_behaves_like 'returns an error result with "use another source" message'
            end

            context 'when project has no enabled namespace' do
              before do
                enabled_namespace.reload.update!(state: :pending)
              end

              it_behaves_like 'returns an error result with "use another source" message'
            end

            context "when not in GA and project's root namespace has experiment features disabled" do
              before do
                stub_feature_flags(semantic_code_search_saas_ga: false)
                root_namespace.reload.namespace_settings.update!(experiment_features_enabled: false)
              end

              it_behaves_like 'returns an error result with "use another source" message'
            end
          end
        end

        context 'when project has a failed ActiveContext repository record' do
          before do
            project_2.reload.ready_active_context_code_repository.failed!
          end

          let(:project_id) { project_2.id }

          it 'does not trigger ad-hoc indexing' do
            expect(Ai::ActiveContext::Code::AdHocIndexingWorker).not_to receive(:perform_async)

            result
          end

          it_behaves_like 'returns no code embeddings error result' do
            let(:expected_error_detail) { described_class::MESSAGE_INDEXING_FAILED }
          end
        end

        context 'when project has a non-ready and not failed ActiveContext repository record' do
          before do
            project_2.reload.ready_active_context_code_repository.pending!
          end

          let(:project_id) { project_2.id }

          it 'does not trigger ad-hoc indexing' do
            expect(Ai::ActiveContext::Code::AdHocIndexingWorker).not_to receive(:perform_async)

            result
          end

          it_behaves_like 'returns no code embeddings error result' do
            let(:expected_error_detail) { described_class::MESSAGE_INITIAL_INDEXING_ONGOING }
          end
        end

        context 'when project has a deleted ActiveContext repository record' do
          before do
            project_2.reload.ready_active_context_code_repository.deleted!
            allow(Ai::ActiveContext::Code::AdHocIndexingWorker).to receive(:perform_async).and_return(true)
          end

          let(:project_id) { project_2.id }

          it 'triggers ad-hoc indexing' do
            expect(Ai::ActiveContext::Code::AdHocIndexingWorker).to receive(:perform_async).with(project_2.id)

            result
          end

          it_behaves_like 'returns no code embeddings error result' do
            let(:expected_error_detail) { described_class::MESSAGE_INITIAL_INDEXING_STARTED }
          end
        end
      end
    end
  end

  def attach_active_context_repository(project:, collection:, enabled_namespace:)
    create(
      :ai_active_context_code_repository,
      :ready,
      project: project,
      enabled_namespace: enabled_namespace,
      connection_id: collection.connection_id
    )
  end

  def build_es_query_result(es_docs)
    return unless es_docs

    es_hits = { 'hits' => { 'total' => { 'value' => 1 }, 'hits' => es_docs } }

    ActiveContext::Databases::Elasticsearch::QueryResult.new(
      result: es_hits,
      collection: Ai::ActiveContext::Collections::Code,
      user: user
    )
  end
end
