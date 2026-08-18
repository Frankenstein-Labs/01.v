# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::CustomDashboards::DashboardsFinder, feature_category: :custom_dashboards_foundation do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user) }
  let_it_be(:other_user) { create(:user) }

  let(:namespace) { create(:group, organization: organization) }
  let(:other_namespace) { create(:group, organization: organization) }

  let_it_be(:org_dashboard1) do
    create(:dashboard, organization: organization, namespace: nil, name: 'Sales Dashboard')
  end

  let_it_be(:org_dashboard2) do
    create(:dashboard, organization: organization, namespace: nil, name: 'Marketing Dashboard', created_by: user)
  end

  let(:namespace_dashboard) do
    create(:dashboard, organization: organization, namespace: namespace, name: 'Team Dashboard', created_by: user)
  end

  let(:other_namespace_dashboard) do
    create(:dashboard, organization: organization, namespace: other_namespace, name: 'Other Team Dashboard')
  end

  let(:params) { {} }
  let(:current_user) { user }

  subject(:dashboards) do
    described_class.new(current_user, organization: organization, params: params).execute
  end

  before do
    create(:organization_user, organization: organization, user: user)
  end

  describe '#execute' do
    context 'when user is an organization member' do
      context 'without namespace access' do
        it 'returns only organization-scoped dashboards' do
          expect(dashboards).to contain_exactly(org_dashboard1, org_dashboard2)
        end

        it 'does not return namespace-scoped dashboards' do
          namespace_dashboard
          other_namespace_dashboard

          expect(dashboards).not_to include(namespace_dashboard, other_namespace_dashboard)
        end

        it 'orders by created_at desc' do
          expect(dashboards.first.created_at).to be >= dashboards.last.created_at
        end
      end

      context 'with namespace access' do
        before do
          namespace_dashboard
          namespace.add_reporter(user)
        end

        it 'returns organization-scoped and accessible namespace-scoped dashboards' do
          expect(dashboards).to contain_exactly(org_dashboard1, org_dashboard2, namespace_dashboard)
        end

        it 'does not return dashboards from inaccessible namespaces' do
          other_namespace_dashboard
          expect(dashboards).not_to include(other_namespace_dashboard)
        end
      end

      context 'with multiple namespace access' do
        before do
          namespace_dashboard
          other_namespace_dashboard
          namespace.add_reporter(user)
          other_namespace.add_reporter(user)
        end

        it 'returns all accessible dashboards' do
          expect(dashboards).to contain_exactly(
            org_dashboard1,
            org_dashboard2,
            namespace_dashboard,
            other_namespace_dashboard
          )
        end
      end
    end

    context 'when user is not an organization member' do
      let(:current_user) { create(:user) }

      it 'returns empty array' do
        expect(dashboards).to be_empty
      end
    end

    context 'when current_user is nil' do
      let(:current_user) { nil }

      it 'does not attempt to resolve namespace access and returns empty result' do
        expect(dashboards).to be_empty
      end
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(custom_dashboard_storage: false)
      end

      it 'returns empty array' do
        expect(dashboards).to be_empty
      end
    end

    context 'with namespace filter' do
      let(:params) { { namespace_id: namespace.id } }

      context 'when user has namespace access' do
        before do
          namespace_dashboard
          namespace.add_reporter(user)
        end

        it 'returns only dashboards in the specified namespace' do
          expect(dashboards).to contain_exactly(namespace_dashboard)
        end

        it 'does not return organization-scoped dashboards' do
          expect(dashboards).not_to include(org_dashboard1, org_dashboard2)
        end
      end

      context 'when user does not have namespace access' do
        before do
          namespace_dashboard
        end

        it 'returns empty array' do
          expect(dashboards).to be_empty
        end
      end
    end

    context 'with created_by filter' do
      let(:params) { { created_by_id: user.id } }

      it 'returns only organization-scoped dashboards created by user' do
        expect(dashboards).to contain_exactly(org_dashboard2)
      end

      context 'when user has namespace access' do
        before do
          namespace_dashboard
          namespace.add_reporter(user)
        end

        it 'returns both org and namespace dashboards created by user' do
          expect(dashboards).to contain_exactly(org_dashboard2, namespace_dashboard)
        end
      end
    end

    context 'with combined filters' do
      let(:params) { { namespace_id: namespace.id, created_by_id: user.id } }

      before do
        namespace_dashboard
        namespace.add_reporter(user)
      end

      it 'applies both filters correctly' do
        expect(dashboards).to contain_exactly(namespace_dashboard)
      end
    end

    context 'when organization has no namespace-scoped dashboards' do
      let_it_be(:org_only_organization) { create(:organization) }
      let_it_be(:org_only_dashboard) do
        create(:dashboard, organization: org_only_organization, namespace: nil)
      end

      let(:current_user) { user }

      before do
        create(:organization_user, organization: org_only_organization, user: user)
      end

      subject(:dashboards) do
        described_class.new(current_user, organization: org_only_organization, params: params).execute
      end

      it 'returns organization-scoped dashboards' do
        expect(dashboards).to contain_exactly(org_only_dashboard)
      end

      it 'does not attempt to authorize namespaces' do
        expect(Namespace).not_to receive(:where)
      end
    end

    context 'when dashboards exist in another organization' do
      let_it_be(:other_organization) { create(:organization) }
      let_it_be(:other_org_dashboard) do
        create(:dashboard, organization: other_organization, namespace: nil)
      end

      it 'does not return dashboards from other organizations' do
        expect(dashboards).not_to include(other_org_dashboard)
      end
    end

    context 'with search filter' do
      let(:params) { { search: 'Sales' } }

      it 'returns only dashboards matching the search term' do
        expect(dashboards).to contain_exactly(org_dashboard1)
      end

      it 'does not return dashboards that do not match the search term' do
        expect(dashboards).not_to include(org_dashboard2)
      end

      context 'when user has namespace access' do
        before do
          namespace_dashboard
          namespace.add_reporter(user)
        end

        it 'returns matching dashboards across org and namespace scope' do
          expect(dashboards).to contain_exactly(org_dashboard1)
        end
      end

      context 'with combined search and created_by filter' do
        let(:params) { { search: 'Marketing', created_by_id: user.id } }

        it 'applies both filters correctly' do
          expect(dashboards).to contain_exactly(org_dashboard2)
        end
      end

      context 'when search term does not match any dashboard' do
        let(:params) { { search: 'Nonexistent' } }

        it 'returns empty result' do
          expect(dashboards).to be_empty
        end
      end
    end
  end
end
