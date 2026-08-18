# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::PackagesHelper, feature_category: :package_registry do
  let_it_be(:project) { build_stubbed(:project) }
  let_it_be(:user) { project.creator }

  describe '#settings_data' do
    before do
      allow(helper).to receive(:current_user).and_return(user)
      allow(Ability).to receive(:allowed?).and_call_original
    end

    subject(:settings_data) { helper.settings_data(project) }

    context 'when the current user cannot admin dependency proxy packages settings' do
      before do
        allow(Ability).to receive(:allowed?).with(user, :admin_dependency_proxy_packages_settings,
          project.dependency_proxy_packages_setting)
          .and_return(false)
      end

      it 'returns the settings data' do
        expect(settings_data).to include(
          show_dependency_proxy_settings: 'false'
        )
      end
    end

    context 'when the current user can admin dependency proxy packages settings' do
      before do
        allow(Ability).to receive(:allowed?).with(user, :admin_dependency_proxy_packages_settings,
          project.dependency_proxy_packages_setting)
          .and_return(true)
      end

      it 'returns the settings data with show_dependency_proxy_settings set to true' do
        expect(settings_data).to include(
          show_dependency_proxy_settings: 'true'
        )
      end
    end
  end

  describe '#google_artifact_registry_data' do
    subject(:data) { helper.google_artifact_registry_data(project) }

    before do
      allow(helper).to receive(:current_user).and_return(user)
    end

    it { is_expected.to include(full_path: project.full_path) }

    it { is_expected.to include(endpoint: project_google_cloud_artifact_registry_index_path(project)) }

    describe 'settings_path' do
      before do
        stub_saas_features(google_cloud_support: true)
        allow(Ability).to receive(:allowed?).with(user, :admin_google_cloud_artifact_registry, project)
          .and_return(true)
      end

      it do
        is_expected.to include(settings_path: edit_project_settings_integration_path(project,
          ::Integrations::GoogleCloudPlatform::ArtifactRegistry))
      end

      context 'when google artifact registry feature is unavailable' do
        before do
          stub_saas_features(google_cloud_support: false)
        end

        it { is_expected.to include(settings_path: '') }
      end
    end
  end

  describe '#packages_and_registries_group_settings_template_data' do
    let_it_be(:group) { build_stubbed(:group) }

    before do
      allow(helper).to receive_messages(
        current_user: user,
        show_virtual_registries_setting?: true
      )
    end

    it 'includes group and dependency proxy paths and should_render_virtual_registries_setting' do
      expect(helper.packages_and_registries_group_settings_template_data(group)).to include(
        group_path: group.full_path,
        group_dependency_proxy_path: group_dependency_proxy_path(group),
        should_render_virtual_registries_setting: 'true'
      )
    end

    it 'includes the virtual registry cleanup policy path' do
      expect(helper.packages_and_registries_group_settings_template_data(group)).to include(
        virtual_registry_cleanup_policy_path:
          group_settings_packages_and_registries_virtual_registry_cleanup_policy_index_path(group)
      )
    end
  end
end
