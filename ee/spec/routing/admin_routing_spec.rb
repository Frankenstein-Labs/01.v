# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'EE-specific admin routing' do
  describe Admin::Geo::ReplicablesController, 'routing' do
    Gitlab::Geo.replication_enabled_replicator_classes.map(&:replicable_name_plural).each do |replicable_name_plural|
      it "routes /admin/geo/replication/#{replicable_name_plural} to replicables#index" do
        expect(get("/admin/geo/replication/#{replicable_name_plural}"))
          .to route_to('admin/geo/replicables#index', replicable_name_plural: replicable_name_plural)
      end
    end
  end

  describe Admin::Geo::NodesController, 'routing' do
    let(:geo_node) { create(:geo_node) }

    it 'routes / to #index' do
      expect(get('/admin/geo')).to route_to('admin/geo/nodes#index')
    end

    it 'routes /sites to #index' do
      expect(get('/admin/geo/sites')).to route_to('admin/geo/nodes#index')
    end

    it 'routes /new to #new' do
      expect(get('/admin/geo/sites/new')).to route_to('admin/geo/nodes#new')
    end

    it 'routes /edit to #edit' do
      expect(get("/admin/geo/sites/#{geo_node.id}/edit")).to route_to('admin/geo/nodes#edit', id: geo_node.to_param)
    end

    it 'routes post / to #create' do
      expect(post('/admin/geo/sites/')).to route_to('admin/geo/nodes#create')
    end

    it 'routes patch /:id to #update' do
      expect(patch("/admin/geo/sites/#{geo_node.id}")).to route_to('admin/geo/nodes#update', id: geo_node.to_param)
    end
  end

  describe Admin::GitlabDuo::ModelSelectionController, 'routing' do
    it 'routes / to #index' do
      expect(get('/admin/gitlab_duo/model_selection')).to route_to('admin/gitlab_duo/model_selection#index')
    end

    it 'routes / with vue route params to #index' do
      expect(get('/admin/gitlab_duo/model_selection/features')).to route_to('admin/gitlab_duo/model_selection#index',
        vueroute: 'features')
    end

    it 'routes /duo_self_hosted/toggle_beta_models to terms_and_conditions#toggle_beta_models' do
      expect(post('/admin/ai/duo_self_hosted/toggle_beta_models'))
        .to route_to('admin/ai/terms_and_conditions#toggle_beta_models')
    end
  end

  describe Admin::GitlabCreditsDashboardController, 'routing', feature_category: :consumables_cost_management do
    it 'routes / to #index' do
      expect(get('/admin/gitlab_credits_dashboard')).to route_to('admin/gitlab_credits_dashboard#index')
    end
  end

  describe Admin::GitlabCreditsDashboard::UsersController, 'routing', feature_category: :consumables_cost_management do
    it 'routes / to #show' do
      expect(get('/admin/gitlab_credits_dashboard/users/john_doe')).to route_to(
        'admin/gitlab_credits_dashboard/users#show', username: 'john_doe')
    end

    it 'routes correctly when username contains a period' do
      expect(get('/admin/gitlab_credits_dashboard/users/john.doe')).to route_to(
        'admin/gitlab_credits_dashboard/users#show', username: 'john.doe')
    end
  end

  describe Admin::Geo::SettingsController, 'routing' do
    it 'routes / to #show' do
      expect(get('/admin/geo/settings')).to route_to('admin/geo/settings#show')
    end

    it 'routes patch / to #update' do
      expect(patch('/admin/geo/settings')).to route_to('admin/geo/settings#update')
    end
  end

  describe Admin::EmailsController, 'routing' do
    it 'routes to #show' do
      expect(get('/admin/email')).to route_to('admin/emails#show')
    end

    it 'routes to #create' do
      expect(post('/admin/email')).to route_to('admin/emails#create')
    end
  end

  describe Admin::ApplicationSettingsController, 'routing' do
    it 'redirects #geo to #geo_redirection' do
      expect(get('/admin/application_settings/geo')).to route_to('admin/geo/settings#show')
    end

    it 'routes to #templates' do
      expect(get('/admin/application_settings/templates')).to route_to('admin/application_settings#templates')
      expect(patch('/admin/application_settings/templates')).to route_to('admin/application_settings#templates')
    end

    it 'redirects /advanced_search to #search' do
      expect(get('/admin/application_settings/search')).to route_to('admin/application_settings#search')
    end

    it 'redirects /search to #search' do
      expect(get('/admin/application_settings/search')).to route_to('admin/application_settings#search')
      expect(patch('/admin/application_settings/search')).to route_to('admin/application_settings#search')
    end

    it 'redirects /security_and_compliance to #security_and_compliance' do
      expect(get('/admin/application_settings/security_and_compliance'))
        .to route_to('admin/application_settings#security_and_compliance')
      expect(patch('/admin/application_settings/security_and_compliance'))
        .to route_to('admin/application_settings#security_and_compliance')
    end

    it 'redirects /namespace_storage to #namespace_storage' do
      expect(get('/admin/application_settings/namespace_storage'))
        .to route_to('admin/application_settings#namespace_storage')
      expect(patch('/admin/application_settings/namespace_storage'))
        .to route_to('admin/application_settings#namespace_storage')
    end
  end

  describe Admin::ApplicationSettings::RolesAndPermissionsController, 'routing' do
    it 'routes to the new member role' do
      expect(get('/admin/application_settings/roles_and_permissions/new'))
        .to route_to('admin/application_settings/roles_and_permissions#new')
    end
  end

  describe Admin::ApplicationSettings::ServiceAccountsController, 'routing' do
    it 'routes to service accounts' do
      expect(get('/admin/application_settings/service_accounts'))
        .to route_to('admin/application_settings/service_accounts#index')
    end

    it 'routes to the vue route' do
      expect(get('/admin/application_settings/service_accounts/access_tokens'))
        .to route_to('admin/application_settings/service_accounts#index', vueroute: 'access_tokens')
    end
  end

  describe Admin::TargetedMessagesController, 'routing' do
    let(:targeted_message) { create(:targeted_message) }

    it 'routes to #index' do
      expect(get('/admin/targeted_messages')).to route_to('admin/targeted_messages#index')
    end

    it 'routes to #new' do
      expect(get('/admin/targeted_messages/new')).to route_to('admin/targeted_messages#new')
    end

    it 'routes to #create' do
      expect(post('/admin/targeted_messages')).to route_to('admin/targeted_messages#create')
    end

    it 'routes to #edit' do
      expect(get("/admin/targeted_messages/#{targeted_message.id}/edit")).to route_to('admin/targeted_messages#edit',
        id: targeted_message.to_param)
    end

    it 'routes patch /:id to #update' do
      expect(patch("/admin/targeted_messages/#{targeted_message.id}")).to route_to('admin/targeted_messages#update',
        id: targeted_message.to_param)
    end

    it 'routes delete /:id to #destroy' do
      expect(delete("/admin/targeted_messages/#{targeted_message.id}")).to route_to('admin/targeted_messages#destroy',
        id: targeted_message.to_param)
    end
  end

  describe Admin::DataManagementController, 'routing' do
    where(model_classes: Gitlab::Geo::ModelMapper.available_models)

    with_them do
      let(:model_name) { Gitlab::Geo::ModelMapper.convert_to_name(model_classes).pluralize }

      it 'routes to #show' do
        expect(get("/admin/data_management/#{model_name}/1")).to route_to('admin/data_management#show',
          model_name: model_name,
          id: '1')
      end

      it 'routes to #index' do
        expect(get('/admin/data_management')).to route_to('admin/data_management#index')
        expect(get("/admin/data_management/#{model_name}")).to route_to('admin/data_management#index', model_name:)
      end
    end
  end
end
