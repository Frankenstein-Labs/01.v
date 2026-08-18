# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GitlabSubscriptionUsageUserEvent'], feature_category: :consumables_cost_management do
  include GraphqlHelpers

  it { expect(described_class.graphql_name).to eq('GitlabSubscriptionUsageUserEvent') }
  it { expect(described_class).to require_graphql_authorizations(:read_user) }

  it 'has expected fields' do
    expect(described_class).to have_graphql_fields([:timestamp, :event_type, :flow_type, :location, :credits_used,
      :session_link])
  end

  describe '#session_link' do
    let(:event_type) { described_class.send(:new, event, context) }
    let(:context) { instance_double(GraphQL::Query::Context) }
    let_it_be(:project) { create(:project) }
    let(:project_id) { project.id }
    let(:session_id) { 100 }
    let(:show_session_link) { true }

    let(:event) do
      Types::GitlabSubscriptions::SubscriptionUsage::UserType::UserEvent.new(
        '2025-10-01T16:30:12Z', 'workflow_execution', 'Flow', project_id, nil, 25.32,
        session_id, show_session_link, nil
      )
    end

    context 'when show_session_link is false' do
      let(:show_session_link) { false }

      it 'returns nil' do
        expect(event_type.session_link).to be_nil
      end
    end

    context 'when project_id is nil' do
      let(:project_id) { nil }

      it 'returns nil' do
        expect(event_type.session_link).to be_nil
      end
    end

    context 'when session_id is nil' do
      let(:session_id) { nil }

      it 'returns nil' do
        expect(event_type.session_link).to be_nil
      end
    end

    context 'when project is not found' do
      let(:project_id) { non_existing_record_id }

      it 'returns nil' do
        result = batch_sync { event_type.session_link }

        expect(result).to be_nil
      end
    end

    context 'when all conditions are met' do
      it 'returns the session URL' do
        result = batch_sync { event_type.session_link }

        expected_url = "#{Gitlab::Routing.url_helpers.project_automate_agent_sessions_url(project)}/#{session_id}"
        expect(result).to eq(expected_url)
      end
    end
  end
end
