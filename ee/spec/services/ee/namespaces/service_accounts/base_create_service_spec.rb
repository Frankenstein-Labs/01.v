# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::ServiceAccounts::BaseCreateService, feature_category: :user_management do
  let_it_be(:organization) { create(:common_organization) }
  let_it_be(:admin) { create(:admin) }
  let_it_be(:group) { create(:group) }
  let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }

  let(:current_user) { admin }
  let(:params) { { organization_id: organization.id } }
  let(:resource_for_test) { group }

  let(:test_service_class) do
    test_resource = resource_for_test
    Class.new(described_class) do
      define_method(:resource) { test_resource }

      def resource_type
        'group'
      end

      def provisioning_params
        return {} unless resource

        { group_id: resource.id, provisioned_by_group_id: resource.id }
      end
    end
  end

  subject(:service) { test_service_class.new(current_user, params) }

  before do
    allow(License).to receive(:current).and_return(license)
  end

  describe '#creation_allowed?' do
    context 'when SaaS', :saas do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      it 'delegates to Authn::ServiceAccounts.creation_allowed_for_saas?', :enable_admin_mode do
        expect(::Authn::ServiceAccounts).to receive(:creation_allowed_for_saas?)
          .with(group)
          .and_call_original

        service.execute
      end
    end

    context 'when not SaaS (self-managed)' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it 'delegates to parent creation_allowed? (SM check)', :enable_admin_mode do
        expect(::Authn::ServiceAccounts).to receive(:creation_allowed_for_sm?)
          .and_call_original

        service.execute
      end
    end
  end

  context 'when resource is nil (root_namespace is nil)' do
    let(:resource_for_test) { nil }

    context 'on SaaS', :saas, :enable_admin_mode do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      it 'returns an error due to nil resource' do
        result = service.execute

        expect(result.status).to eq(:error)
        expect(result.message).to include('does not have permission')
      end
    end

    context 'on self-managed', :enable_admin_mode do
      it 'returns an error due to nil resource' do
        result = service.execute

        expect(result.status).to eq(:error)
        expect(result.message).to include('does not have permission')
      end
    end
  end
end
