# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Virtual registry', :aggregate_failures, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax
  include ListboxHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(packages_virtual_registry: true, container_virtual_registry: true)
    sign_in(user)
  end

  describe 'list page' do
    subject(:url) { group_virtual_registries_path(group) }

    context 'when user is not group member' do
      it 'renders 404' do
        visit url

        expect(page).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user is a guest' do
      before_all do
        group.add_guest(user)
      end

      it_behaves_like 'virtual registry is unavailable'

      context 'when both `packages_virtual_registry` & `container_virtual_registry` license is invalid' do
        before do
          stub_licensed_features(packages_virtual_registry: false, container_virtual_registry: false)
        end

        it 'renders 404' do
          visit url

          expect(page).to have_gitlab_http_status(:not_found)
        end
      end

      [
        { license: :packages_virtual_registry, enabled: false, other: :container_virtual_registry },
        { license: :container_virtual_registry, enabled: false, other: :packages_virtual_registry }
      ].each do |config|
        context "when `#{config[:license]}` license is invalid" do
          before do
            stub_licensed_features(config[:license] => config[:enabled], config[:other] => true)
          end

          it 'renders page' do
            visit url

            expect(page).to have_gitlab_http_status(:ok)
          end
        end
      end
    end

    context 'when user is a guest', :js do
      before_all do
        group.add_guest(user)
      end

      it 'sidebar menu is open' do
        visit url
        wait_for_requests

        within_testid 'super-sidebar' do
          expect(page).to have_link('Virtual registry', href: group_virtual_registries_path(group))
        end
      end

      it 'renders empty state' do
        visit url
        wait_for_requests

        expect(page).to have_text('Get started with virtual registries')
        expect(page).not_to have_button(/Create/)
      end

      where(:feature_flag) do
        [
          :container_virtual_registries,
          :maven_virtual_registry
        ]
      end

      with_them do
        context "when #{params[:feature_flag]} feature flag is disabled" do
          before do
            stub_feature_flags(feature_flag => false)
          end

          it 'renders empty state' do
            visit url
            wait_for_requests

            expect(page).to have_text('Get started with virtual registries')
            expect(page).not_to have_button(/Create/)
          end
        end
      end

      it 'passes accessibility tests' do
        visit url
        wait_for_requests

        expect(page).to be_axe_clean.skipping :'link-in-text-block'
      end

      context 'when Maven and Container virtual registries exist' do
        before do
          create(:virtual_registries_packages_maven_registry, group: group)
          create(:virtual_registries_container_registry, group: group)
        end

        it 'renders virtual registries page with both registry types' do
          visit url
          wait_for_requests

          expect(page).to have_selector('h1', text: 'Virtual registry')
          expect(page).to have_text('Maven')
          expect(page).to have_link('View registries',
            href: group_virtual_registries_maven_registries_and_upstreams_path(group))
          expect(page).to have_text('Container')
          expect(page).to have_link('View registries',
            href: group_virtual_registries_container_registries_path(group))
          expect(page).not_to have_button('Create registry')
        end

        it 'passes accessibility tests' do
          visit url
          wait_for_requests

          expect(page).to be_axe_clean
        end

        where(:feature_flag, :visible_registry, :hidden_registry, :link_type) do
          :container_virtual_registries        | 'Maven'     | 'Container' | :maven
          :maven_virtual_registry              | 'Container' | 'Maven'     | :container
        end

        with_them do
          let(:link_path) do
            case link_type
            when :maven then group_virtual_registries_maven_registries_and_upstreams_path(group)
            when :container then group_virtual_registries_container_registries_path(group)
            end
          end

          context "when #{params[:feature_flag]} is disabled" do
            before do
              stub_feature_flags(feature_flag => false)
            end

            it "only shows #{params[:visible_registry]} registry" do
              visit url
              wait_for_requests

              expect(page).to have_selector('h1', text: 'Virtual registry')
              expect(page).to have_text(visible_registry)
              expect(page).to have_link('View registries', href: link_path)
              expect(page).not_to have_text(hidden_registry)
            end
          end
        end
      end
    end

    context 'when user is a maintainer', :js do
      before_all do
        group.add_maintainer(user)
      end

      it 'renders dropdown to select registry type' do
        visit url
        wait_for_requests

        click_button('Maven')
        select_item('Maven')

        expect(page).to have_link('Create registry', href: new_group_virtual_registries_maven_registry_path(group))
      end

      it 'allows selecting container registry type' do
        visit url
        wait_for_requests

        click_button('Maven')
        select_item('Container')

        expect(page).to have_link('Create registry', href: new_group_virtual_registries_container_registry_path(group))
      end

      it 'passes accessibility tests' do
        visit url
        wait_for_requests

        expect(page).to be_axe_clean.skipping :'link-in-text-block'
      end

      where(:feature_flag, :visible_registry, :hidden_registry, :link_type) do
        :container_virtual_registries        | 'Maven'     | 'Container' | :maven
        :maven_virtual_registry              | 'Container' | 'Maven'     | :container
      end

      with_them do
        let(:link_path) do
          case link_type
          when :maven then new_group_virtual_registries_maven_registry_path(group)
          when :container then new_group_virtual_registries_container_registry_path(group)
          end
        end

        context "when #{params[:feature_flag]} is disabled" do
          before do
            stub_feature_flags(feature_flag => false)
          end

          it "dropdown contains only #{params[:visible_registry]} option" do
            visit url
            wait_for_requests

            expect(page).to have_link('Create registry', href: link_path)

            click_button(visible_registry)
            expect(page).not_to have_selector('[data-testid="registry-name"]', text: hidden_registry)
          end
        end
      end

      context 'when Maven and Container virtual registries exist' do
        before do
          create(:virtual_registries_packages_maven_registry, group: group)
          create(:virtual_registries_container_registry, group: group)
        end

        it 'renders virtual registries page with both registry types' do
          visit url
          wait_for_requests

          expect(page).to have_selector('h1', text: 'Virtual registry')
          expect(page).to have_text('Maven')
          expect(page).to have_link('View registries',
            href: group_virtual_registries_maven_registries_and_upstreams_path(group))
          expect(page).to have_text('Container')
          expect(page).to have_link('View registries',
            href: group_virtual_registries_container_registries_path(group))

          click_button 'Create registry'
          expect(page).to have_link('Maven', href: new_group_virtual_registries_maven_registry_path(group))
          expect(page).to have_link('Container',
            href: new_group_virtual_registries_container_registry_path(group))
        end

        it 'passes accessibility tests' do
          visit url
          wait_for_requests

          expect(page).to be_axe_clean
        end
      end
    end
  end

  private

  def select_item(text)
    find_by_testid('registry-name', text: text).click
  end
end
