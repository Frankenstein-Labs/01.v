# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project', :js, :with_current_organization, feature_category: :groups_and_projects do
  describe 'storage pre_enforcement alert', :js do
    include NamespaceStorageHelpers

    let_it_be_with_refind(:group) { create(:group, :with_root_storage_statistics) }
    let_it_be_with_refind(:user) { create(:user) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:storage_banner_text) { "A namespace storage limit of 5 GiB will soon be enforced" }

    before do
      stub_ee_application_setting(automatic_purchased_storage_allocation: true)
      stub_saas_features(namespaces_storage_limit: true)
      set_notification_limit(group, megabytes: 1000)
      set_dashboard_limit(group, megabytes: 5_120)

      group.root_storage_statistics.update!(
        storage_size: 5.gigabytes
      )
      group.add_maintainer(user)
      sign_in(user)
    end

    context 'when storage is over the notification limit' do
      it 'displays the alert in the project page' do
        visit project_path(project)

        expect(page).to have_text storage_banner_text
      end

      context 'when in a subgroup project page' do
        let_it_be(:subgroup) { create(:group, parent: group) }
        let_it_be(:project) { create(:project, namespace: subgroup) }

        it 'displays the alert' do
          visit project_path(project)

          expect(page).to have_text storage_banner_text
        end
      end

      context 'when in a user namespace project page' do
        let_it_be_with_refind(:project) { create(:project, namespace: user.namespace) }

        before do
          create(
            :namespace_root_storage_statistics,
            namespace: user.namespace,
            storage_size: 5.gigabytes
          )
        end

        it 'displays the alert' do
          visit project_path(project)

          expect(page).to have_text storage_banner_text
        end
      end

      it 'does not display the alert in a paid group project page' do
        allow_next_found_instance_of(Group) do |group|
          allow(group).to receive(:paid?).and_return(true)
        end

        visit project_path(project)

        expect(page).not_to have_text storage_banner_text
      end
    end

    context 'when storage is under the notification limit' do
      before do
        set_notification_limit(group, megabytes: 10_000)
      end

      it 'does not display the alert in the group page' do
        visit project_path(project)

        expect(page).not_to have_text storage_banner_text
      end
    end
  end
end
