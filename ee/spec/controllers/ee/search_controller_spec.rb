# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SearchController, :elastic, feature_category: :global_search do
  let_it_be(:user) { create(:user) }
  let(:category) { described_class.to_s }

  before do
    sign_in(user)
  end

  shared_examples 'unique_users tracking' do |controller_action, tracked_action|
    let_it_be(:group) { create(:group) }

    context 'when elasticsearch is enabled' do
      before do
        stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
      end

      context 'for snowplow' do
        it 'emits all snowplow search events' do
          get controller_action, params: request_params

          expect_snowplow_event(
            category: category, action: tracked_action, namespace: group, user: user,
            context: context('i_search_total'),
            property: 'i_search_total',
            label: 'redis_hll_counters.search.search_total_unique_counts_monthly'
          )
          expect_snowplow_event(
            category: category, action: tracked_action, namespace: group, user: user,
            context: context('i_search_paid'),
            property: 'i_search_paid',
            label: 'redis_hll_counters.search.i_search_paid_monthly'
          )
          expect_snowplow_event(
            category: category, action: tracked_action, namespace: group, user: user,
            context: context('i_search_advanced'),
            property: 'i_search_advanced',
            label: 'redis_hll_counters.search.search_total_unique_counts_monthly'
          )
        end

        context 'when query params search_type is passed as basic' do
          it 'does not emit i_search_paid and i_search_advanced snowplow search events' do
            get controller_action, params: request_params.merge(search_type: 'basic')

            expect_no_snowplow_event(
              category: category, action: tracked_action, namespace: group, user: user,
              context: context('i_search_advanced'),
              property: 'i_search_advanced',
              label: 'redis_hll_counters.search.search_total_unique_counts_monthly'
            )
            expect_no_snowplow_event(
              category: category, action: tracked_action, namespace: group, user: user,
              context: context('i_search_paid'),
              property: 'i_search_paid',
              label: 'redis_hll_counters.search.i_search_paid_monthly'
            )
            expect_snowplow_event(
              category: category, action: tracked_action, namespace: group, user: user,
              context: context('i_search_total'),
              property: 'i_search_total',
              label: 'redis_hll_counters.search.search_total_unique_counts_monthly'
            )
          end
        end
      end

      context 'for redis_hll' do
        subject(:request) { get controller_action, params: request_params }

        context 'with i_search_advanced' do
          let(:target_event) { 'i_search_advanced' }

          it_behaves_like 'tracking unique hll events' do
            let(:expected_value) { instance_of(String) }
          end
        end

        context 'with i_search_paid' do
          let(:target_event) { 'i_search_paid' }

          it_behaves_like 'tracking unique hll events' do
            let(:expected_value) { instance_of(String) }
          end
        end

        context 'with i_search_total' do
          let(:target_event) { 'i_search_total' }

          it_behaves_like 'tracking unique hll events' do
            let(:expected_value) { instance_of(String) }
          end
        end

        context 'when query params search_type is passed as basic' do
          subject(:request) { get controller_action, params: request_params.merge(search_type: 'basic') }

          context 'with i_search_advanced' do
            let(:target_event) { 'i_search_advanced' }

            it_behaves_like 'does not tracking unique hll events' do
              let(:expected_value) { instance_of(String) }
            end
          end

          context 'with i_search_paid' do
            let(:target_event) { 'i_search_paid' }

            it_behaves_like 'does not tracking unique hll events' do
              let(:expected_value) { instance_of(String) }
            end
          end

          context 'with i_search_total' do
            let(:target_event) { 'i_search_total' }

            it_behaves_like 'tracking unique hll events' do
              let(:expected_value) { instance_of(String) }
            end
          end
        end
      end
    end

    context 'when elasticsearch is disabled' do
      before do
        stub_ee_application_setting(elasticsearch_search: false, elasticsearch_indexing: false)
      end

      context 'for snowplow' do
        it 'does not emit i_search_paid and i_search_advanced snowplow search events' do
          get controller_action, params: request_params

          expect_snowplow_event(
            category: category, action: tracked_action, namespace: group, user: user,
            context: context('i_search_total'),
            property: 'i_search_total',
            label: 'redis_hll_counters.search.search_total_unique_counts_monthly'
          )
          expect_no_snowplow_event(
            category: category, action: tracked_action, namespace: group, user: user,
            context: context('i_search_paid'),
            property: 'i_search_paid',
            label: 'redis_hll_counters.search.i_search_paid_monthly'
          )
          expect_no_snowplow_event(
            category: category, action: tracked_action, namespace: group, user: user,
            context: context('i_search_advanced'),
            property: 'i_search_advanced',
            label: 'redis_hll_counters.search.search_total_unique_counts_monthly'
          )
        end

        context 'when query params search_type is passed as advanced' do
          it 'does not emit i_search_paid and i_search_advanced snowplow search events' do
            get controller_action, params: request_params.merge(search_type: 'advanced')

            expect_no_snowplow_event(
              category: category, action: tracked_action, namespace: group, user: user,
              context: context('i_search_advanced'),
              property: 'i_search_advanced',
              label: 'redis_hll_counters.search.search_total_unique_counts_monthly'
            )
            expect_no_snowplow_event(
              category: category, action: tracked_action, namespace: group, user: user,
              context: context('i_search_paid'),
              property: 'i_search_paid',
              label: 'redis_hll_counters.search.i_search_paid_monthly'
            )
            expect_snowplow_event(
              category: category, action: tracked_action, namespace: group, user: user,
              context: context('i_search_total'),
              property: 'i_search_total',
              label: 'redis_hll_counters.search.search_total_unique_counts_monthly'
            )
          end
        end
      end

      context 'for redis_hll' do
        subject(:request) { get controller_action, params: request_params }

        context 'with i_search_advanced' do
          let(:target_event) { 'i_search_advanced' }

          it_behaves_like 'does not tracking unique hll events' do
            let(:expected_value) { instance_of(String) }
          end
        end

        context 'with i_search_paid' do
          let(:target_event) { 'i_search_paid' }

          it_behaves_like 'does not tracking unique hll events' do
            let(:expected_value) { instance_of(String) }
          end
        end

        context 'with i_search_total' do
          let(:target_event) { 'i_search_total' }

          it_behaves_like 'tracking unique hll events' do
            let(:expected_value) { instance_of(String) }
          end
        end

        context 'when query params search_type is passed as advanced' do
          subject(:request) { get controller_action, params: request_params.merge(search_type: 'advanced') }

          context 'with i_search_advanced' do
            let(:target_event) { 'i_search_advanced' }

            it_behaves_like 'does not tracking unique hll events' do
              let(:expected_value) { instance_of(String) }
            end
          end

          context 'with i_search_paid' do
            let(:target_event) { 'i_search_paid' }

            it_behaves_like 'does not tracking unique hll events' do
              let(:expected_value) { instance_of(String) }
            end
          end

          context 'with i_search_total' do
            let(:target_event) { 'i_search_total' }

            it_behaves_like 'tracking unique hll events' do
              let(:expected_value) { instance_of(String) }
            end
          end
        end
      end
    end
  end

  describe 'GET #count' do
    it_behaves_like 'support for elasticsearch timeouts',
      :count, { search: 'hello', scope: 'projects' }, :search_results, :json

    describe 'when Gitlab::Search::Client::ConnectionError is raised' do
      before do
        allow_next_instance_of(SearchService) do |service|
          allow(service).to receive(:search_results)
            .and_raise(::Gitlab::Search::Client::ConnectionError.new('connection failed'))
        end
      end

      it 'returns 503 with an empty body instead of bubbling up to a 500' do
        get :count, params: { search: 'hello', scope: 'projects' }

        expect(response).to have_gitlab_http_status(:service_unavailable)
        expect(json_response).to eq({})
      end

      it 'logs the exception' do
        expect(::Gitlab::ErrorTracking).to receive(:log_exception)
          .with(an_instance_of(::Gitlab::Search::Client::ConnectionError), class: 'SearchController')

        get :count, params: { search: 'hello', scope: 'projects' }
      end
    end
  end

  describe 'GET #show' do
    it_behaves_like 'unique_users tracking', :show, 'executed' do
      let(:request_params) { { group_id: group.id, scope: 'blobs', search: 'term' } }
    end

    it_behaves_like 'support for elasticsearch timeouts', :show, { search: 'hello' }, :search_objects, :html

    describe 'when Gitlab::Search::Client::ConnectionError errors are raised' do
      before do
        allow_next_instance_of(SearchService) do |service|
          allow(service).to receive(:search_objects)
            .and_raise(::Gitlab::Search::Client::ConnectionError.new('connection failed'))
        end
      end

      it 'rescues and does not throw an error' do
        get :show, params: { scope: 'blobs', search: 'test' }

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    describe 'no_results_for_group_or_project_blobs_advanced_search?', :elasticsearch_settings_enabled do
      let_it_be(:project) { create(:project, :public) }

      context 'when abuse_detected? returns true' do
        before do
          allow_next_instance_of(SearchService) do |service|
            allow(service).to receive_messages(
              scope: 'blobs',
              project: project,
              group: nil,
              search_objects: [],
              abuse_detected?: true
            )
          end
        end

        it 'does not call ProjectIndexIntegrityWorker' do
          expect(::Search::ProjectIndexIntegrityWorker).not_to receive(:perform_async)

          get :show, params: { scope: 'blobs', search: 'test', project_id: project.id, search_type: 'advanced' }
        end
      end

      context 'when search_results.failed? returns true' do
        before do
          search_results = instance_double(
            ::Gitlab::Elastic::SearchResults,
            failed?: true,
            error: 'Search failed',
            highlight_map: {}
          )
          allow_next_instance_of(SearchService) do |service|
            allow(service).to receive_messages(
              scope: 'blobs',
              project: project,
              group: nil,
              search_objects: [],
              abuse_detected?: false,
              search_results: search_results
            )
          end
        end

        it 'does not call ProjectIndexIntegrityWorker' do
          expect(::Search::ProjectIndexIntegrityWorker).not_to receive(:perform_async)

          get :show, params: { scope: 'blobs', search: 'test', project_id: project.id, search_type: 'advanced' }
        end
      end

      context 'when search_results is nil' do
        before do
          allow_next_instance_of(SearchService) do |service|
            allow(service).to receive_messages(
              scope: 'blobs',
              project: project,
              group: nil,
              search_objects: [],
              abuse_detected?: false
            )
            allow(service).to receive_messages(search_results: nil, search_highlight: {})
          end
        end

        it 'does not call ProjectIndexIntegrityWorker' do
          expect(::Search::ProjectIndexIntegrityWorker).not_to receive(:perform_async)

          get :show, params: { scope: 'blobs', search: 'test', project_id: project.id, search_type: 'advanced' }
        end

        it 'does not raise an error' do
          expect do
            get :show, params: { scope: 'blobs', search: 'test', project_id: project.id, search_type: 'advanced' }
          end.not_to raise_error
        end
      end
    end

    describe 'search index integrity rate limiting', :elasticsearch_settings_enabled, :freeze_time,
      :clean_gitlab_redis_rate_limiting do
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, :public, group: group) }

      let(:search_params) { { scope: 'blobs', search: 'nonexistent_term', search_type: 'advanced' } }
      let(:search_results) do
        instance_double(
          ::Gitlab::Elastic::SearchResults,
          failed?: false,
          error: nil,
          highlight_map: {}
        )
      end

      before do
        stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
      end

      shared_examples 'rate limits index integrity worker' do
        before do
          allow_next_instance_of(SearchService) do |service|
            allow(service).to receive_messages(
              scope: 'blobs',
              project: request_params[:project_id] ? project : nil,
              group: request_params[:group_id] ? group : nil,
              search_objects: [],
              abuse_detected?: false,
              search_results: search_results,
              search_highlight: {}
            )
          end
        end

        it 'enqueues worker on first request' do
          expect(worker_class).to receive(:perform_async).with(resource.id).once

          get :show, params: search_params.merge(request_params)
        end

        it 'does not enqueue worker on subsequent requests within rate limit window', :aggregate_failures do
          expect(worker_class).to receive(:perform_async).with(resource.id).once
          get :show, params: search_params.merge(request_params)

          expect(worker_class).not_to receive(:perform_async)
          get :show, params: search_params.merge(request_params)

          expect(worker_class).not_to receive(:perform_async)
          get :show, params: search_params.merge(request_params)
        end

        it 'enqueues worker again after rate limit window expires', :aggregate_failures do
          expect(worker_class).to receive(:perform_async).with(resource.id).once
          get :show, params: search_params.merge(request_params)

          # cleaning redis' keys to simulate the expiration in-between
          redis_rate_limiting_cleanup!

          expect(worker_class).to receive(:perform_async).with(resource.id).once
          get :show, params: search_params.merge(request_params)
        end
      end

      context 'for project searches' do
        let(:worker_class) { ::Search::ProjectIndexIntegrityWorker }
        let(:resource) { project }
        let(:request_params) { { project_id: project.id, group_id: group.id } }

        it_behaves_like 'rate limits index integrity worker'

        it 'rate limits independently per project' do
          other_project = create(:project, :public)

          allow_next_instance_of(SearchService) do |service|
            allow(service).to receive_messages(
              scope: 'blobs',
              search_objects: [],
              abuse_detected?: false,
              search_results: search_results,
              search_highlight: {},
              project: project,
              group: nil
            )
          end
          expect(worker_class).to receive(:perform_async).with(project.id).once
          get :show, params: search_params.merge(project_id: project.id)

          allow_next_instance_of(SearchService) do |service|
            allow(service).to receive_messages(
              scope: 'blobs',
              search_objects: [],
              abuse_detected?: false,
              search_results: search_results,
              search_highlight: {},
              project: other_project,
              group: nil
            )
          end
          expect(worker_class).to receive(:perform_async).with(other_project.id).once
          get :show, params: search_params.merge(project_id: other_project.id)
        end
      end

      context 'for group searches' do
        let(:worker_class) { ::Search::NamespaceIndexIntegrityWorker }
        let(:resource) { group }
        let(:request_params) { { group_id: group.id } }

        it_behaves_like 'rate limits index integrity worker'

        it 'rate limits independently per group' do
          other_group = create(:group)

          allow_next_instance_of(SearchService) do |service|
            allow(service).to receive_messages(
              scope: 'blobs',
              project: nil,
              search_objects: [],
              abuse_detected?: false,
              search_results: search_results,
              search_highlight: {},
              group: group
            )
          end
          expect(worker_class).to receive(:perform_async).with(group.id).once
          get :show, params: search_params.merge(group_id: group.id)

          allow_next_instance_of(SearchService) do |service|
            allow(service).to receive_messages(
              scope: 'blobs',
              project: nil,
              search_objects: [],
              abuse_detected?: false,
              search_results: search_results,
              search_highlight: {},
              group: other_group
            )
          end
          expect(worker_class).to receive(:perform_async).with(other_group.id).once
          get :show, params: search_params.merge(group_id: other_group.id)
        end
      end
    end

    describe 'when search_type is not present in params' do
      it 'calls search_type_errors but returns nil' do
        expect_next_instance_of(SearchService) do |service|
          expect(service).to receive(:search_type_errors).and_return(nil)
        end

        get :show, params: { scope: 'blobs', search: 'test' }
      end

      using RSpec::Parameterized::TableSyntax

      where(:search_type, :scope, :use_elastic, :use_zoekt, :flash_expected) do
        'basic' | 'blobs' | false | false | false
        'advanced' | 'blobs' | false | false | true
        'advanced' | 'blobs' | true | false | false
        'zoekt' | 'blobs' | false | false | true
        'zoekt' | 'blobs' | false | true | false
        'zoekt' | 'issue' | false | true | true
      end

      with_them do
        before do
          allow_next_instance_of(SearchService) do |search_service|
            allow(search_service).to receive_messages(use_elasticsearch?: use_elastic, use_zoekt?: use_zoekt,
              scope: scope, search_objects: [])
          end
        end

        it 'sets the flash alert if expected' do
          get :show, params: { scope: scope, search: 'test', search_type: search_type }

          if flash_expected
            expect(controller).to set_flash[:alert]
          else
            expect(controller).not_to set_flash[:alert]
          end
        end
      end
    end

    context 'for tab feature flags' do
      using RSpec::Parameterized::TableSyntax

      subject(:show) { get :show, params: { scope: scope, search: 'term' }, format: :html }

      where(:admin_setting, :scope) do
        :global_search_code_enabled    | 'blobs'
        :global_search_commits_enabled | 'commits'
        :global_search_wiki_enabled    | 'wiki_blobs'
      end

      with_them do
        it 'returns 200 if flag is enabled' do
          stub_application_setting(admin_setting => true)

          show

          expect(response).to have_gitlab_http_status(:ok)
        end

        it 'redirects with alert if flag is disabled' do
          stub_application_setting(admin_setting => false)

          show

          expect(response).to redirect_to search_path
          expect(controller).to set_flash[:alert].to(/Global Search is disabled for this scope/)
        end
      end
    end

    context 'when zoekt search is enabled', :zoekt_settings_enabled, :clean_gitlab_redis_shared_state do
      let(:params) { { scope: 'blobs', search: 'term' } }

      subject(:request) { get :show, params: params }

      before do
        allow(Search::Zoekt::Node).to receive_message_chain(:for_search, :searchable, :exists?).and_return(true)
      end

      it 'triggers search_exact_code internal event' do
        expect { request }.to trigger_internal_events('search_exact_code').with(user: user)
          .and increment_usage_metrics(
            'redis_hll_counters.count_distinct_user_id_from_search_exact_code_weekly',
            'redis_hll_counters.count_distinct_user_id_from_search_exact_code_monthly'
          )
      end

      it 'does not call haml_search_results' do
        expect(controller).not_to receive(:haml_search_results)

        request
      end

      context 'when advanced search is enabled' do
        before do
          stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
        end

        it 'trigger search_exact_code internal event' do
          expect { request }.to trigger_internal_events('search_exact_code').with(user: user)
            .and increment_usage_metrics(
              'redis_hll_counters.count_distinct_user_id_from_search_exact_code_weekly',
              'redis_hll_counters.count_distinct_user_id_from_search_exact_code_monthly'
            )
        end
      end

      context 'when search_type is passed as advanced' do
        let(:params) { { scope: 'blobs', search: 'term' }.merge(search_type: 'advanced') }

        it 'does not trigger search_exact_code internal event' do
          expect { request }.to not_trigger_internal_events('search_exact_code')
            .and not_increment_usage_metrics(
              'redis_hll_counters.count_distinct_user_id_from_search_exact_code_weekly',
              'redis_hll_counters.count_distinct_user_id_from_search_exact_code_monthly'
            )
        end
      end
    end
  end

  describe 'GET #autocomplete' do
    it_behaves_like 'unique_users tracking', :autocomplete, 'autocomplete' do
      let(:request_params) { { group_id: group.id, term: 'term' } }
    end

    describe 'when Gitlab::Search::Client::ConnectionError is raised' do
      before do
        allow(controller).to receive(:search_autocomplete_opts)
          .and_raise(::Gitlab::Search::Client::ConnectionError.new('connection failed'))
      end

      it 'rescues and returns an empty array' do
        get :autocomplete, params: { term: 'test' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to eq([])
      end
    end
  end

  describe 'GET #aggregations' do
    it_behaves_like 'when the user cannot read cross project', :aggregations, { search: 'hello', scope: 'blobs' }
    it_behaves_like 'with external authorization service enabled', :aggregations, { search: 'hello', scope: 'blobs' }
    it_behaves_like 'support for elasticsearch timeouts', :aggregations, { search: 'hello', scope: 'blobs' },
      :search_aggregations, :html

    it_behaves_like 'rate limited endpoint', rate_limit_key: :search_rate_limit do
      let(:current_user) { user }

      def request
        get(:aggregations, params: { search: 'foo@bar.com', scope: 'users' })
      end

      def request_with_second_scope
        get(:aggregations, params: { search: 'foo@bar.com', scope: 'projects' })
      end
    end

    context 'for blobs scope' do
      context 'when elasticsearch is disabled' do
        it 'returns an empty array' do
          get :aggregations, params: { search: 'test', scope: 'blobs' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_empty
        end
      end

      context 'when elasticsearch is enabled', :sidekiq_inline do
        let(:project) { create(:project, :public, :repository) }

        before do
          stub_ee_application_setting(
            elasticsearch_search: true,
            elasticsearch_indexing: true
          )
          allow(::Search::Zoekt).to receive(:search_enabled?).and_return(false)

          project.repository.index_commits_and_blobs
          ensure_elasticsearch_index!
        end

        it 'returns aggregations' do
          get :aggregations, params: { search: 'test', scope: 'blobs' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.first['name']).to eq('language')
          expect(json_response.first['buckets'].length).to eq(2)
        end
      end
    end

    context 'for work_items scope' do
      context 'when elasticsearch is disabled' do
        it 'returns an empty array' do
          get :aggregations, params: { search: 'test', scope: 'work_items' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_empty
        end
      end

      context 'when elasticsearch is enabled', :sidekiq_inline do
        let(:project) { create(:project) }

        before do
          stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)

          create(:labeled_issue, title: 'test', project: project, labels: [create(:label)])
          project.add_developer(user)

          ensure_elasticsearch_index!
        end

        it 'returns aggregations' do
          get :aggregations, params: { search: 'test', scope: 'work_items' }

          expect(response).to have_gitlab_http_status(:ok)

          labels_aggregation = json_response.find { |agg| agg['name'] == 'labels' }
          expect(labels_aggregation).to be_present
          expect(labels_aggregation['buckets'].length).to eq(1)

          work_item_types_aggregation = json_response.find { |agg| agg['name'] == 'work_item_type_ids' }
          expect(work_item_types_aggregation).to be_present
        end
      end
    end

    context 'for merge request scope' do
      context 'when elasticsearch is disabled' do
        it 'returns an empty array' do
          get :aggregations, params: { search: 'test', scope: 'merge_requests' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_empty
        end
      end

      context 'when elasticsearch is enabled', :sidekiq_inline do
        before do
          stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)

          project = create(:project, developers: user)
          create(:labeled_merge_request, title: 'test', source_project: project, labels: [create(:label)])

          ensure_elasticsearch_index!
        end

        it 'returns aggregations' do
          get :aggregations, params: { search: 'test', scope: 'merge_requests' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.first['name']).to eq('labels')
          expect(json_response.first['buckets'].length).to eq(1)
        end
      end
    end

    it 'increments the custom search sli apdex' do
      expect(Gitlab::Metrics::GlobalSearchSlis).to receive(:record_apdex).with(
        elapsed: a_kind_of(Numeric),
        search_scope: 'projects',
        search_type: 'basic',
        search_level: 'global'
      )

      get :aggregations, params: { search: 'test', scope: 'projects' }
    end

    context 'with custom search sli error rate' do
      context 'when the search is successful' do
        it 'increments the custom search sli error rate with error: false' do
          expect(Gitlab::Metrics::GlobalSearchSlis).to receive(:record_error_rate).with(
            error: false,
            search_scope: 'projects',
            search_type: 'basic',
            search_level: 'global'
          )

          get :aggregations, params: { search: 'test', scope: 'projects' }
        end
      end

      context 'when the search raises an error' do
        before do
          allow_next_instance_of(SearchService) do |service|
            allow(service).to receive(:search_aggregations).and_raise(ActiveRecord::QueryCanceled)
          end
        end

        it 'increments the custom search sli error rate with error: true' do
          expect(Gitlab::Metrics::GlobalSearchSlis).to receive(:record_error_rate).with(
            error: true,
            search_scope: 'projects',
            search_type: 'basic',
            search_level: 'global'
          )

          get :aggregations, params: { search: 'test', scope: 'projects' }
        end
      end
    end

    context 'when search_type is nil' do
      it 'handles nil search_type gracefully' do
        allow_next_instance_of(SearchService) do |service|
          allow(service).to receive(:search_type).and_return(nil)
        end

        get :aggregations, params: { search: 'test', scope: 'projects' }

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    it 'raises an error if search term is missing' do
      expect do
        get :aggregations, params: { scope: 'projects' }
      end.to raise_error(ActionController::ParameterMissing)
    end

    it 'returns an error if search term is invalid' do
      search_term = 'a' * (::Search::Params::SEARCH_CHAR_LIMIT + 1)
      get :aggregations, params: { scope: 'blobs', search: search_term }

      expect(response).to have_gitlab_http_status(:bad_request)
      expect(json_response['error']).to include('Search query is too long')
    end

    it 'sets correct cache control headers' do
      get :aggregations, params: { search: 'test', scope: 'issues' }

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.headers['Cache-Control']).to eq('max-age=60, private')
      expect(response.headers['Pragma']).to be_nil
    end

    describe 'when Gitlab::Search::Client::ConnectionError is raised' do
      before do
        allow_next_instance_of(SearchService) do |service|
          allow(service).to receive(:search_aggregations)
            .and_raise(::Gitlab::Search::Client::ConnectionError.new('connection failed'))
        end
      end

      it 'returns service unavailable with error details' do
        get :aggregations, params: { search: 'test', scope: 'blobs' }

        expect(response).to have_gitlab_http_status(:service_unavailable)
        expect(json_response['error']).to eq('Search is currently unavailable. Please try again later.')
        expect(json_response['error_type']).to eq('connection_error')
      end
    end

    context 'when on gitlab.com' do
      before do
        allow(::Gitlab).to receive(:com?).and_return(true)
      end

      it 'sets correct cache control headers' do
        get :aggregations, params: { search: 'test', scope: 'issues' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.headers['Cache-Control']).to eq('max-age=300, private')
        expect(response.headers['Pragma']).to be_nil
      end
    end
  end

  describe '#append_info_to_payload' do
    let(:search_type) { 'advanced' }

    before do
      allow_next_instance_of(SearchService) do |service|
        allow(service).to receive(:search_type).and_return search_type
      end
    end

    it 'appends search metadata for logging' do
      expect(controller).to receive(:append_info_to_payload).and_wrap_original do |method, payload|
        method.call(payload)

        expect(payload[:metadata]['meta.search.filters.source_branch']).to eq('included-branch')
        expect(payload[:metadata]['meta.search.filters.not_source_branch']).to eq('excluded-branch')
        expect(payload[:metadata]['meta.search.filters.target_branch']).to eq('included-branch')
        expect(payload[:metadata]['meta.search.filters.not_target_branch']).to eq('excluded-branch')
        expect(payload[:metadata]['meta.search.filters.author_username']).to eq('included-username')
        expect(payload[:metadata]['meta.search.filters.not_author_username']).to eq('excluded-username')
      end

      get :show, params: {
        scope: 'work_items',
        search: 'hello world',
        source_branch: 'included-branch',
        target_branch: 'included-branch',
        author_username: 'included-username',
        not: {
          source_branch: 'excluded-branch',
          target_branch: 'excluded-branch',
          author_username: 'excluded-username'
        }
      }
    end

    context 'when using elasticsearch' do
      it 'appends the type of search used as advanced' do
        expect(controller).to receive(:append_info_to_payload).and_wrap_original do |method, payload|
          method.call(payload)

          expect(payload[:metadata]['meta.search.type']).to eq(search_type)
        end

        get :show, params: { search: 'hello world' }
      end
    end

    context 'when using basic search' do
      let(:search_type) { 'basic' }

      it 'appends the type of search used as basic' do
        expect(controller).to receive(:append_info_to_payload).and_wrap_original do |method, payload|
          method.call(payload)

          expect(payload[:metadata]['meta.search.type']).to eq(search_type)
        end

        get :show, params: { search: 'hello world', search_type: search_type }
      end
    end

    context 'on the autocomplete action' do
      it 'does not append merge request filter metadata' do
        expect(controller).to receive(:append_info_to_payload).and_wrap_original do |method, payload|
          method.call(payload)

          expect(payload[:metadata]).not_to have_key('meta.search.filters.source_branch')
          expect(payload[:metadata]).not_to have_key('meta.search.filters.not_source_branch')
          expect(payload[:metadata]).not_to have_key('meta.search.filters.target_branch')
          expect(payload[:metadata]).not_to have_key('meta.search.filters.not_target_branch')
          expect(payload[:metadata]).not_to have_key('meta.search.filters.author_username')
          expect(payload[:metadata]).not_to have_key('meta.search.filters.not_author_username')
        end

        get :autocomplete, params: {
          term: 'hello',
          source_branch: 'included-branch',
          target_branch: 'included-branch',
          author_username: 'included-username',
          not: {
            source_branch: 'excluded-branch',
            target_branch: 'excluded-branch',
            author_username: 'excluded-username'
          }
        }
      end
    end
  end

  describe '#multi_match?' do
    subject(:controller_instance) { described_class.new }

    let(:current_user) { user }
    let(:scope) { 'blobs' }
    let(:search_type) { 'zoekt' }

    before do
      allow(controller_instance).to receive(:current_user).and_return(current_user)
    end

    context 'when scope is "blobs", and search_type is "zoekt"' do
      it 'returns true' do
        result = controller_instance.send(:multi_match?, search_type: search_type, scope: scope)
        expect(result).to be(true)
      end
    end

    context 'when scope is not "blobs"' do
      let(:scope) { 'other_scope' }

      it 'returns false' do
        result = controller_instance.send(:multi_match?, search_type: search_type, scope: scope)
        expect(result).to be(false)
      end
    end

    context 'when search_type is not "zoekt"' do
      let(:search_type) { 'other_search' }

      it 'returns false' do
        result = controller_instance.send(:multi_match?, search_type: search_type, scope: scope)
        expect(result).to be(false)
      end
    end
  end

  private

  def context(event)
    [Gitlab::Tracking::ServicePingContext.new(data_source: :redis_hll, event: event).to_context.to_json]
  end
end
