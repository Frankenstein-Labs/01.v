# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Protected Environments', :js, feature_category: :environment_management do
  let_it_be_with_refind(:organization) { create(:group, :private) }
  let_it_be(:developer_group) { create(:group, :private, name: 'developer-group', parent: organization) }
  let_it_be(:operator_group) { create(:group, :private, name: 'operator-group', parent: organization) }
  let_it_be(:unrelated_group) { create(:group) }
  let_it_be(:organization_owner) { create(:user, owner_of: organization) }
  let_it_be(:organization_maintainer) { create(:user, maintainer_of: organization) }

  let(:current_user) { organization_owner }

  before do
    stub_licensed_features(protected_environments: true)
    sign_in(current_user)

    visit group_settings_ci_cd_path(organization)
  end

  it 'shows Protected Environments settings' do
    expect(page).to have_selector(".protected-environments-settings")
  end

  it 'shows environment tiers in the creation form' do
    within_testid('new-protected-environment') do
      click_button('Protect an environment')
      expect(page).to have_content('Select environment tier')
    end
  end

  it 'shows all subgroups of the organization in the deployers select after selecting a tier' do
    select_environment_tier

    within_testid('create-deployer-dropdown') do
      click_button('Select users')
      expect(page).to have_content(developer_group.name)
      expect(page).to have_content(operator_group.name)
      expect(page).not_to have_content(unrelated_group.name)
    end
  end

  it 'shows all subgroups of the organization in the approvers select after selecting a tier' do
    select_environment_tier

    within_testid('create-approver-dropdown') do
      click_button('Select users')
      expect(page).to have_content(developer_group.name)
      expect(page).to have_content(operator_group.name)
      expect(page).not_to have_content(unrelated_group.name)
    end
  end

  it 'allows to create a group-level protected environment' do
    select_environment_tier

    within_testid('create-deployer-dropdown') do
      click_button('Select users')
      click_button('operator-group')
    end

    click_on('Protect')

    wait_for_requests
    click_button('staging')
    within_testid('protected-environment-staging-deployers') do
      expect(page).to have_content('operator-group')
    end
  end

  context 'when no subgroups exist' do
    let(:public_organization) { create(:group) }

    before do
      public_organization.add_owner(current_user)
    end

    it 'shows search box without throwing an error' do
      visit group_settings_ci_cd_path(public_organization)
      select_environment_tier

      within_testid('create-deployer-dropdown') do
        click_button('Select users')
      end

      within('.gl-dropdown-inner') { find('.gl-search-box-by-type') }
    end
  end

  context 'when protected environments already exist' do
    before do
      deploy_access_level = build(:protected_environment_deploy_access_level, group: operator_group)

      create(
        :protected_environment,
        :group_level,
        name: 'production',
        group: organization,
        deploy_access_levels: [deploy_access_level]
      )

      visit group_settings_ci_cd_path(organization)
    end

    it 'allows user to change the allowed groups' do
      within_testid('protected-environments-list') do
        expect(page).to have_content('production')
        click_button('production')
        click_button('Add deployment rules')
        wait_for_requests

        click_button('Select users')
        click_button('developer-group') # Select developer-group
        send_keys(:escape) # Close the access level dropdown

        click_button('Save')
        wait_for_requests

        within("[data-testid='protected-environment-production-deployers'] > table > tbody > tr:nth-child(1)") do
          click_button('Delete deployer rule') # Unselect operator-group
          wait_for_requests
        end

        expect(page).to have_content('developer-group')
        expect(page).not_to have_content('operator-group')
      end
    end

    it 'allows user to destroy the entry' do
      within_testid('protected-environments-list') do
        click_button('production')
        click_on('Unprotect')
      end

      find('.js-modal-action-primary').click

      within_testid('protected-environments-list') do
        expect(page).not_to have_content('production')
      end
    end
  end

  context 'when license does not exist' do
    before do
      stub_licensed_features(protected_environments: false)

      visit group_settings_ci_cd_path(organization)
    end

    it 'does not show the Protected Environments settings' do
      expect(page).not_to have_selector(".protected-environments-settings")
    end
  end

  context 'when the user has maintainer role' do
    let(:current_user) { organization_maintainer }

    it 'does not show the Protected Environments settings' do
      expect(page).not_to have_selector(".protected-environments-settings")
    end
  end

  def select_environment_tier
    within_testid('new-protected-environment') do
      click_button('Protect an environment')

      click_button('Select environment tier')
      find_by_testid('listbox-item-staging').click
    end
  end
end
