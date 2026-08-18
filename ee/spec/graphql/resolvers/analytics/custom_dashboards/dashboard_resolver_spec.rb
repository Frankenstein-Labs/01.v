# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Analytics::CustomDashboards::DashboardResolver, feature_category: :custom_dashboards_foundation do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user) }

  let(:namespace) { create(:group) }

  let_it_be(:org_dashboard) do
    create(:dashboard, organization: organization, namespace: nil, name: 'Org Dashboard')
  end

  let(:namespace_dashboard) do
    create(:dashboard, organization: organization, namespace: namespace, name: 'Namespace Dashboard')
  end

  let_it_be(:other_org_dashboard) do
    create(:dashboard, name: 'Other Org Dashboard')
  end

  let(:dashboard) { org_dashboard }
  let(:args) { { id: dashboard.to_global_id } }
  let(:current_user) { user }

  subject(:resolved_dashboard) do
    result = resolve(described_class, args: args, ctx: { current_user: current_user })
    sync(result)
  end

  before do
    stub_feature_flags(custom_dashboard_storage: true)
  end

  describe '#resolve' do
    context 'when user is not an organization member' do
      it 'returns nil' do
        expect(resolved_dashboard).to be_nil
      end
    end

    context 'when user is an organization member' do
      before do
        create(:organization_user, organization: organization, user: user)
      end

      context 'with organization-scoped dashboard' do
        let(:dashboard) { org_dashboard }

        it 'returns the dashboard' do
          expect(resolved_dashboard).to eq(org_dashboard)
        end
      end

      context 'with namespace-scoped dashboard' do
        let(:dashboard) { namespace_dashboard }

        context 'when user has namespace access' do
          before do
            namespace.add_reporter(user)
          end

          it 'returns the dashboard' do
            expect(resolved_dashboard).to eq(namespace_dashboard)
          end
        end

        context 'when user does not have namespace access' do
          it 'returns nil' do
            expect(resolved_dashboard).to be_nil
          end
        end
      end

      context 'with dashboard from different organization' do
        let(:dashboard) { other_org_dashboard }

        it 'returns nil' do
          expect(resolved_dashboard).to be_nil
        end
      end

      context 'when dashboard does not exist' do
        let(:args) { { id: "gid://gitlab/Analytics::CustomDashboards::Dashboard/#{non_existing_record_id}" } }

        it 'returns nil' do
          expect(resolved_dashboard).to be_nil
        end
      end
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(custom_dashboard_storage: false)
        create(:organization_user, organization: organization, user: user)
      end

      it 'returns nil' do
        expect(resolved_dashboard).to be_nil
      end
    end

    context 'with different user types' do
      before do
        create(:organization_user, organization: organization, user: user)
      end

      context 'when user is the dashboard creator' do
        let(:dashboard) { create(:dashboard, organization: organization, namespace: nil, created_by: user) }

        it 'returns the dashboard' do
          expect(resolved_dashboard).to eq(dashboard)
        end
      end

      context 'when requesting dashboard created by another user' do
        let(:other_user) { create(:user) }
        let(:dashboard) { create(:dashboard, organization: organization, namespace: nil, created_by: other_user) }

        before do
          create(:organization_user, organization: organization, user: other_user)
        end

        it 'returns the dashboard' do
          expect(resolved_dashboard).to eq(dashboard)
        end
      end
    end
  end
end
