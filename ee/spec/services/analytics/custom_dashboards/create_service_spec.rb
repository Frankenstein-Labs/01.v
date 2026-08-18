# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::CustomDashboards::CreateService, feature_category: :custom_dashboards_foundation do
  let_it_be(:user) { create(:user) }
  let_it_be(:organization) { create(:organization) }

  let(:current_user) { user }

  let(:valid_config) do
    {
      version: "2",
      title: "Revenue Dashboard",
      description: "Tracks revenue KPIs",
      panels: [
        {
          title: "Total Revenue",
          visualization: "number",
          gridAttributes: { width: 4, height: 2 }
        }
      ]
    }
  end

  let(:params) do
    {
      name: "Revenue Dashboard",
      description: "Tracks KPIs",
      config: valid_config
    }
  end

  subject(:execute) do
    described_class.new(current_user: current_user, organization: organization, params: params).execute
  end

  before do
    stub_licensed_features(product_analytics: true)
    stub_feature_flags(custom_dashboard_storage: true)
  end

  describe '#execute' do
    context 'when user is organization owner' do
      before_all do
        create(:organization_user, :owner, organization: organization, user: user)
      end

      context 'with valid params' do
        it 'creates a dashboard and returns a success response' do
          expect { execute }.to change { Analytics::CustomDashboards::Dashboard.count }.by(1)

          expect(execute).to be_success

          dashboard = execute.payload[:dashboard]
          expect(dashboard.name).to eq("Revenue Dashboard")
          expect(dashboard.description).to eq("Tracks KPIs")
          expect(dashboard.config).to eq(valid_config.deep_stringify_keys)
          expect(dashboard.organization).to eq(organization)
          expect(dashboard.created_by_id).to eq(user.id)
          expect(dashboard.updated_by_id).to eq(user.id)
        end
      end

      context 'with invalid params' do
        context 'when name is missing' do
          let(:params) { super().merge(name: nil) }

          it 'does not create a dashboard and returns an error response' do
            expect { execute }.not_to change { Analytics::CustomDashboards::Dashboard.count }

            expect(execute).to be_error
            expect(execute.message).to match(/Name can't be blank/i)
          end
        end

        context 'when config is invalid' do
          let(:params) { super().merge(config: { invalid: "schema" }) }

          it 'does not create a dashboard and returns an error response' do
            expect { execute }.not_to change { Analytics::CustomDashboards::Dashboard.count }

            expect(execute).to be_error
          end
        end

        context 'when config is not a hash' do
          let(:params) { super().merge(config: "not a hash") }

          it 'does not create a dashboard and returns an error response' do
            expect { execute }.not_to change { Analytics::CustomDashboards::Dashboard.count }

            expect(execute).to be_error
            expect(execute.message).to match(/Config must be a JSON object/i)
          end
        end
      end
    end

    context 'when user is organization member but not owner' do
      let_it_be(:regular_member) { create(:user) }
      let(:current_user) { regular_member }

      before_all do
        create(:organization_user, organization: organization, user: regular_member)
      end

      it 'returns an authorization error' do
        expect { execute }.not_to change { Analytics::CustomDashboards::Dashboard.count }

        expect(execute).to be_error
        expect(execute.message).to eq('You are not authorized to create dashboards in this organization')
      end
    end

    context 'when user is not organization member' do
      let_it_be(:non_member_user) { create(:user) }
      let(:current_user) { non_member_user }

      it 'returns an authorization error' do
        expect { execute }.not_to change { Analytics::CustomDashboards::Dashboard.count }

        expect(execute).to be_error
        expect(execute.message).to eq('You are not authorized to create dashboards in this organization')
      end
    end
  end
end
