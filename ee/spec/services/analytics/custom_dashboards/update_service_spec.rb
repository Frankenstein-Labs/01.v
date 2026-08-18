# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::CustomDashboards::UpdateService, feature_category: :custom_dashboards_foundation do
  let_it_be_with_reload(:user) { create(:user) }
  let_it_be(:organization) { create(:organization) }
  let_it_be(:namespace) { create(:group, organization: organization) }

  let_it_be_with_reload(:dashboard) do
    create(
      :dashboard,
      organization: organization,
      namespace: namespace,
      created_by: user,
      name: 'Original Name',
      description: 'Original Description',
      config: {
        version: '2',
        title: 'Original Dashboard',
        panels: []
      }
    )
  end

  let(:current_user) { user }

  let(:new_config) do
    {
      version: '2',
      title: 'Updated Dashboard',
      panels: [
        {
          title: 'New Panel',
          visualization: 'line_chart',
          gridAttributes: { width: 6, height: 3 }
        }
      ]
    }
  end

  let(:params) do
    {
      name: 'Updated Name',
      description: 'Updated Description',
      config: new_config
    }
  end

  subject(:execute) do
    described_class.new(current_user: current_user, dashboard: dashboard, params: params).execute
  end

  before do
    stub_licensed_features(product_analytics: true)
    stub_feature_flags(custom_dashboard_storage: true)
  end

  describe '#execute' do
    context 'when user can update dashboard' do
      before_all do
        create(:organization_user, organization: organization, user: user)
        user.update!(organization: organization)
        create(:group_member, :developer, group: namespace, user: user)
      end

      context 'with valid params' do
        it 'updates the dashboard and returns a success response' do
          expect { execute }.not_to change { Analytics::CustomDashboards::Dashboard.count }

          expect(execute).to be_success

          updated_dashboard = execute.payload[:dashboard]
          expect(updated_dashboard.name).to eq('Updated Name')
          expect(updated_dashboard.description).to eq('Updated Description')
          expect(updated_dashboard.config).to eq(new_config.deep_stringify_keys)
          expect(updated_dashboard.updated_by).to eq(user)
        end

        it 'updates only provided fields' do
          partial_params = { name: 'Only Name Changed' }

          result = described_class.new(
            current_user: current_user,
            dashboard: dashboard,
            params: partial_params
          ).execute

          expect(result).to be_success
          expect(result.payload[:dashboard].name).to eq('Only Name Changed')
          expect(result.payload[:dashboard].description).to eq('Original Description')
        end

        it 'tracks the user who updated the dashboard' do
          execute

          expect(dashboard.reload.updated_by).to eq(user)
        end
      end

      context 'with invalid params' do
        context 'when name is blank' do
          let(:params) { super().merge(name: '') }

          it 'does not update the dashboard and returns an error response' do
            expect { execute }.not_to change { dashboard.reload.name }

            expect(execute).to be_error
            expect(execute.message).to include("Name can't be blank")
          end
        end

        context 'when config is invalid' do
          let(:params) { super().merge(config: { invalid: 'schema' }) }

          it 'does not update the dashboard and returns an error response' do
            expect { execute }.not_to change { dashboard.reload.config }

            expect(execute).to be_error
          end
        end

        context 'when config is not a hash' do
          let(:params) { super().merge(config: 'not a hash') }

          it 'does not update the dashboard and returns an error response' do
            expect { execute }.not_to change { dashboard.reload.config }

            expect(execute).to be_error
            expect(execute.message).to include('Config must be a JSON object')
          end
        end
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

      it 'allows the creator to update their dashboard' do
        result = described_class.new(
          current_user: creator,
          dashboard: dashboard_by_creator,
          params: { name: 'Updated by Creator' }
        ).execute

        expect(result).to be_success
        expect(result.payload[:dashboard].name).to eq('Updated by Creator')
      end
    end

    context 'when user cannot update dashboard' do
      let_it_be(:unauthorized_user) { create(:user, organization: organization) }
      let(:current_user) { unauthorized_user }

      before_all do
        create(:group_member, :reporter, group: namespace, user: unauthorized_user)
      end

      it 'returns an authorization error' do
        expect { execute }.not_to change { dashboard.reload.updated_at }

        expect(execute).to be_error
        expect(execute.message).to eq('You are not authorized to update this dashboard')
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
        expect(execute.message).to eq('You are not authorized to update this dashboard')
      end
    end
  end
end
