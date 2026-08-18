# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::AuditEventsController, feature_category: :audit_events do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { create(:user) }
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:auditor) { create(:user, auditor: true) }
  let_it_be(:project) { create(:project, :private) }
  let_it_be(:new_events) { create_list(:audit_events_project_audit_event, 5, project_id: project.id) }

  describe 'GET #index' do
    let(:sort) { nil }
    let(:entity_type) { nil }
    let(:entity_id) { nil }

    let(:request) do
      get :index, params: { project_id: project.to_param, namespace_id: project.namespace.to_param, sort: sort, entity_type: entity_type, entity_id: entity_id }
    end

    shared_context 'when audit_events feature is available' do
      let(:audit_events_params) { ActionController::Parameters.new(sort: '', entity_type: '', entity_id: '', created_after: Date.current.beginning_of_month, created_before: Date.current.end_of_day).permit! }

      before do
        stub_licensed_features(audit_events: true)

        allow(AuditEvents::ProjectAuditEventFinder).to receive(:new).and_call_original
      end

      shared_examples 'AuditEventFinder params' do
        it 'has the correct params' do
          request

          expect(AuditEvents::ProjectAuditEventFinder).to have_received(:new).with(
            project: project, params: audit_events_params
          )
        end
      end

      it 'renders index with 200 status code' do
        request

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to render_template(:index)
      end

      context 'invokes AuditEventFinder with correct arguments' do
        it_behaves_like 'AuditEventFinder params'
      end

      context 'author' do
        context 'when no author entity type is specified' do
          it_behaves_like 'AuditEventFinder params'
        end

        context 'when the author entity type is specified' do
          let(:entity_type) { 'Author' }
          let(:entity_id) { 1 }
          let(:audit_events_params) { ActionController::Parameters.new(sort: '', author_id: '1', created_after: Date.current.beginning_of_month, created_before: Date.current.end_of_day).permit! }

          it_behaves_like 'AuditEventFinder params'
        end
      end

      context 'ordering' do
        shared_examples 'orders by id descending' do
          it 'orders by id descending' do
            request

            actual_event_ids = assigns(:events).map { |event| event[:id] }
            expected_event_ids = new_events.map(&:id).reverse

            expect(actual_event_ids).to eq(expected_event_ids)
          end
        end

        context 'when no sort order is specified' do
          it_behaves_like 'orders by id descending'
        end

        context 'when sorting by latest events first' do
          let(:sort) { 'created_desc' }

          it_behaves_like 'orders by id descending'
        end

        context 'when sorting by oldest events first' do
          let(:sort) { 'created_asc' }

          it 'orders by id ascending' do
            request

            actual_event_ids = assigns(:events).map { |event| event[:id] }
            expected_event_ids = new_events.map(&:id)

            expect(actual_event_ids).to eq(expected_event_ids)
          end
        end

        context 'when sorting by an unsupported sort order' do
          let(:sort) { 'FOO' }

          it_behaves_like 'orders by id descending'
        end
      end

      context 'when invalid date' do
        where(:created_before, :created_after) do
          'invalid-date' | nil
          nil            | true
          '2021-13-10'   | nil
          nil            | '2021-02-31'
          '2021-03-31'   | '2021-02-31'
        end

        with_them do
          it 'returns an error' do
            get :index, params: { project_id: project.to_param, namespace_id: project.namespace.to_param, created_before: created_before, created_after: created_after }

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(flash[:alert]).to eq 'Invalid date format. Please use UTC format as YYYY-MM-DD'
          end
        end
      end

      context 'when date range is greater than limit' do
        subject { get :index, params: { project_id: project.to_param, namespace_id: project.namespace.to_param, created_before: created_before, created_after: created_after } }

        it_behaves_like 'a date range error is returned'
      end
    end

    shared_examples 'pagination' do
      it 'sets instance variables' do
        request

        expect(assigns(:is_last_page)).to be(true)
      end

      it 'paginates audit events, without casting a count query' do
        serializer = instance_spy(AuditEventSerializer)
        allow(AuditEventSerializer).to receive(:new).and_return(serializer)

        request

        expect(serializer).to have_received(:represent).with(kind_of(Kaminari::PaginatableWithoutCount))
      end
    end

    shared_context 'when audit_events feature is not available' do
      before do
        stub_licensed_features(audit_events: false)
      end

      it 'renders 404' do
        request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when authorized as auditor' do
      before do
        sign_in(auditor)
      end

      it_behaves_like 'when audit_events feature is available'

      it_behaves_like 'pagination'

      it_behaves_like 'when audit_events feature is not available'

      it 'tracks search event', :snowplow do
        request

        expect_snowplow_event(
          category: 'Projects::AuditEventsController',
          action: 'search_audit_event',
          project: project,
          user: auditor,
          namespace: project.namespace
        )
      end

      context 'govern usage tracking' do
        it_behaves_like 'tracks govern usage event', 'audit_events'

        context 'with active frameworks' do
          let_it_be(:framework) { create :compliance_framework }
          let_it_be(:group) { framework.namespace }
          let_it_be(:project) { create :project, namespace: group }

          it 'tracks with_active_compliance_frameworks' do
            create(:compliance_framework_project_setting, project: project, compliance_management_framework: framework)

            expect(Gitlab::InternalEvents)
              .to receive(:track_event)
              .with('user_perform_visit', hash_including(additional_properties: hash_including(
                page_name: 'audit_events',
                with_active_compliance_frameworks: 'true'
              )))

            request
          end
        end
      end
    end

    context 'when authorized as maintainer' do
      before_all do
        project.add_maintainer(maintainer)
      end

      before do
        sign_in(maintainer)
      end

      it_behaves_like 'when audit_events feature is available'

      it_behaves_like 'pagination'

      it_behaves_like 'when audit_events feature is not available'

      it 'tracks search event', :snowplow do
        request

        expect_snowplow_event(
          category: 'Projects::AuditEventsController',
          action: 'search_audit_event',
          project: project,
          user: maintainer,
          namespace: project.namespace
        )
      end

      it_behaves_like 'tracks govern usage event', 'audit_events' do
        let(:user) { maintainer }
      end
    end

    context 'unauthorized' do
      before do
        stub_licensed_features(audit_events: true)
        sign_in(user)
      end

      it 'renders 404' do
        request

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it_behaves_like "doesn't track govern usage event", 'users_visiting_audit_events'
    end
  end
end
