# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::CustomDashboards::DeleteService, feature_category: :custom_dashboards_foundation do
  let_it_be_with_reload(:user) { create(:user) }
  let_it_be(:organization) { create(:organization) }
  let_it_be(:namespace) { create(:group, organization: organization) }

  let_it_be_with_reload(:dashboard) do
    create(
      :dashboard,
      organization: organization,
      namespace: namespace,
      created_by: user,
      name: 'Dashboard to Delete'
    )
  end

  let(:current_user) { user }

  subject(:execute) do
    described_class.new(current_user: current_user, dashboard: dashboard).execute
  end

  before do
    stub_licensed_features(product_analytics: true)
    stub_feature_flags(custom_dashboard_storage: true)
  end

  describe '#execute' do
    context 'when user can delete dashboard' do
      before_all do
        create(:organization_user, organization: organization, user: user)
        user.update!(organization: organization)
        create(:group_member, :developer, group: namespace, user: user)
      end

      it 'deletes the dashboard and returns a success response' do
        expect { execute }.to change { Analytics::CustomDashboards::Dashboard.count }.by(-1)

        expect(execute).to be_success
        expect(execute.payload[:dashboard].id).to eq(dashboard.id)
        expect(execute.payload[:dashboard]).to be_destroyed
        expect(Analytics::CustomDashboards::Dashboard.find_by(id: dashboard.id)).to be_nil
      end
    end

    context 'when user is dashboard creator but only has reporter access' do
      let_it_be(:creator) { create(:user, organization: organization) }
      let_it_be_with_reload(:dashboard_by_creator) do
        create(
          :dashboard,
          organization: organization,
          namespace: namespace,
          created_by: creator,
          name: 'Creator Dashboard'
        )
      end

      let(:current_user) { creator }

      before_all do
        create(:group_member, :reporter, group: namespace, user: creator)
      end

      it 'allows the creator to delete their dashboard' do
        expect do
          described_class.new(current_user: creator, dashboard: dashboard_by_creator).execute
        end.to change { Analytics::CustomDashboards::Dashboard.count }.by(-1)
      end
    end

    context 'when user cannot delete dashboard' do
      let_it_be(:unauthorized_user) { create(:user, organization: organization) }
      let(:current_user) { unauthorized_user }

      before_all do
        create(:group_member, :reporter, group: namespace, user: unauthorized_user)
      end

      it 'returns an authorization error' do
        expect { execute }.not_to change { Analytics::CustomDashboards::Dashboard.count }

        expect(execute).to be_error
        expect(execute.message).to eq('You are not authorized to delete this dashboard')
      end
    end

    context 'when dashboard is nil' do
      let(:dashboard) { nil }

      it 'returns an error' do
        expect(execute).to be_error
        expect(execute.message).to eq('Dashboard not found')
      end
    end

    context 'when dashboard is a system dashboard' do
      let(:dashboard) do
        Analytics::CustomDashboards::SystemDashboard.new(
          slug: 'gitlab_duo',
          config: { 'title' => 'Test', 'version' => '2', 'panels' => [] }
        )
      end

      it 'returns an authorization error' do
        expect(execute).to be_error
        expect(execute.message).to eq('You are not authorized to delete this dashboard')
      end
    end

    context 'when dashboard deletion fails' do
      before do
        allow(dashboard).to receive(:destroy).and_return(false)
        allow(dashboard).to receive_message_chain(:errors, :full_messages).and_return(['Database error'])
        create(:organization_user, organization: organization, user: user)
        user.update!(organization: organization)
        create(:group_member, :developer, group: namespace, user: user)
      end

      it 'returns an error response' do
        expect { execute }.not_to change { Analytics::CustomDashboards::Dashboard.count }

        expect(execute).to be_error
        expect(execute.message).to eq(['Database error'])
      end
    end
  end
end
