# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with read_admin_monitoring', :enable_admin_mode, feature_category: :permissions do
  using RSpec::Parameterized::TableSyntax

  around do |example|
    Gitlab::ExclusiveLease.skipping_transaction_check do
      example.run
    end
  end

  let!(:current_user) { create(:user) }
  let!(:permission) { :read_admin_monitoring }
  let!(:role) { create(:admin_member_role, permission, user: current_user) }

  before do
    stub_licensed_features(admin_audit_log: true, custom_roles: true)
    sign_in(current_user)
  end

  describe Admin::BackgroundMigrationsController do
    it "GET #index" do
      get admin_background_migrations_path

      expect(response).to have_gitlab_http_status(:ok)
    end

    it "GET #show" do
      migration = create(:batched_background_migration_job)
      get admin_background_migration_path(migration)

      expect(response).to have_gitlab_http_status(:ok)
    end
  end

  describe Admin::DataManagementController do
    let_it_be(:model) { create(:project) }
    let_it_be(:model_name) { Gitlab::Geo::ModelMapper.convert_to_name(model.class).pluralize }
    let_it_be(:show_path) { "#{admin_data_management_path}/#{model_name}/#{model.id}" }

    where(:geo_enabled, :data_management_enabled, :expected_status) do
      true  | true  | :ok
      true  | false | :not_found
      false | true  | :not_found
      false | false | :not_found
    end

    with_them do
      before do
        stub_licensed_features(admin_audit_log: true, custom_roles: true, data_management: data_management_enabled)
        allow(::Gitlab::Geo).to receive(:enabled?).and_return(geo_enabled)
      end

      it "GET #index" do
        get admin_data_management_path

        expect(response).to have_gitlab_http_status(expected_status)
      end

      it 'GET #show' do
        get show_path

        expect(response).to have_gitlab_http_status(expected_status)
      end
    end
  end

  describe Admin::GitalyServersController do
    it "GET #index", quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/9375' do
      get admin_gitaly_servers_path

      expect(response).to have_gitlab_http_status(:ok)
    end
  end

  describe Admin::HealthCheckController do
    it "GET #show" do
      get admin_health_check_path

      expect(response).to have_gitlab_http_status(:ok)
    end
  end

  describe Admin::SystemInfoController do
    it "GET #show", quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/9377' do
      get admin_system_info_path

      expect(response).to have_gitlab_http_status(:ok)
    end
  end

  describe Admin::DashboardController do
    describe "#index" do
      it 'user has access via a custom role' do
        get admin_root_path

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to render_template(:index)
      end
    end
  end
end
