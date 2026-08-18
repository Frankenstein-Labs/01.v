# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Organizations security routing', :routing, feature_category: :vulnerability_management do
  let_it_be(:organization) { build(:organization) }

  describe 'dashboard route' do
    # This path is also served by the organization-scoped clone of the instance security dashboard
    # (`organization_security_dashboard`). The organization route is drawn first and therefore wins,
    # which is intentional: the organization dashboard owns this path.
    specify 'to organizations/security/dashboard#show' do
      expect(get("/o/#{organization.path}/-/security/dashboard"))
        .to route_to('organizations/security/dashboard#show', organization_path: organization.path)
    end
  end

  describe 'instance security dashboard' do
    it 'is unaffected by the organization route' do
      expect(get('/-/security/dashboard')).to route_to('security/dashboard#show')
    end
  end

  describe 'policy store routes' do
    specify 'index routes to organizations/security/policy_store#index' do
      expect(get("/o/#{organization.path}/-/security/policy_store"))
        .to route_to('organizations/security/policy_store#index', organization_path: organization.path)
    end

    specify 'new routes to organizations/security/policy_store#new' do
      expect(get("/o/#{organization.path}/-/security/policy_store/new"))
        .to route_to('organizations/security/policy_store#new', organization_path: organization.path)
    end

    specify 'edit routes to organizations/security/policy_store#edit' do
      expect(get("/o/#{organization.path}/-/security/policy_store/1/edit"))
        .to route_to('organizations/security/policy_store#edit',
          organization_path: organization.path, id: '1')
    end
  end
end
