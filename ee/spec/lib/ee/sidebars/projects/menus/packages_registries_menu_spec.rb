# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Projects::Menus::PackagesRegistriesMenu, feature_category: :container_registry do
  let_it_be_with_reload(:project) { create(:project) }

  let_it_be_with_refind(:artifact_registry_integration) do
    create(:google_cloud_platform_artifact_registry_integration, project: project)
  end

  let_it_be_with_refind(:wlif_integration) do
    create(:google_cloud_platform_workload_identity_federation_integration, project: project)
  end

  let(:user) { project.first_owner }
  let(:context) { Sidebars::Projects::Context.new(current_user: user, container: project) }

  describe 'Menu items' do
    subject { described_class.new(context).renderable_items.find { |i| i.item_id == item_id } }

    shared_examples 'the menu item gets added to list of menu items' do
      it 'adds the menu item' do
        is_expected.not_to be_nil
      end
    end

    shared_examples 'the menu item is not added to list of menu items' do
      it 'does not add the menu item' do
        is_expected.to be_nil
      end
    end

    describe 'Google Artifact Registry' do
      before do
        stub_saas_features(google_cloud_support: true)
      end

      let(:item_id) { :google_artifact_registry }

      it_behaves_like 'the menu item gets added to list of menu items'

      context 'when feature is unavailable' do
        before do
          stub_saas_features(google_cloud_support: false)
        end

        it_behaves_like 'the menu item is not added to list of menu items'
      end

      context 'when user is guest' do
        let_it_be(:user) { create(:user) }

        before_all do
          project.add_guest(user)
        end

        it_behaves_like 'the menu item is not added to list of menu items'
      end

      context 'when user is anonymous' do
        let(:user) { nil }

        it_behaves_like 'the menu item is not added to list of menu items'
      end

      %i[wlif artifact_registry].each do |integration_type|
        context "with the #{integration_type} integration" do
          let(:integration) { public_send("#{integration_type}_integration") }

          context 'when not present' do
            before do
              integration.destroy!
            end

            it_behaves_like 'the menu item is not added to list of menu items'
          end

          context 'when inactive' do
            before do
              integration.update_column(:active, false)
            end

            it_behaves_like 'the menu item is not added to list of menu items'
          end
        end
      end
    end
  end
end
