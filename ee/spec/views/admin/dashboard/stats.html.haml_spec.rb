# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/dashboard/stats', feature_category: :seat_cost_management do
  let_it_be(:users_statistics) do
    build(:users_statistics, without_groups_and_projects: 10,
      with_highest_role_planner: 5,
      with_highest_role_reporter: 15,
      with_highest_role_security_manager: 3,
      with_highest_role_developer: 25,
      with_highest_role_maintainer: 20,
      with_highest_role_owner: 3,
      with_highest_role_guest: 30,
      bots: 7,
      blocked: 5,
      with_highest_role_minimal_access: 5,
      with_highest_role_guest_with_custom_role: 2
    )
  end

  before_all do
    assign(:users_statistics, users_statistics)
  end

  before do
    create_current_license(plan: License::PREMIUM_PLAN)

    render
  end

  describe 'billable users section' do
    it 'renders billable users section' do
      expect(rendered).to have_selector('[data-testid="billable-users-table"]')
      expect(rendered).to have_content('Billable users')
    end

    it 'displays main users with highest role for each role type' do
      within('[data-testid="billable-users-table"]') do
        expect(rendered).to have_content('Users with highest role Planner')
        expect(rendered).to have_content('5')

        expect(rendered).to have_content('Users with highest role Reporter')
        expect(rendered).to have_content('15')

        expect(rendered).to have_content('Users with highest role Security Manager')
        expect(rendered).to have_content('3')

        expect(rendered).to have_content('Users with highest role Developer')
        expect(rendered).to have_content('25')

        expect(rendered).to have_content('Users with highest role Maintainer')
        expect(rendered).to have_content('20')

        expect(rendered).to have_content('Users with highest role Owner')
        expect(rendered).to have_content('3')
      end
    end

    it 'displays guest users' do
      within('[data-testid="billable-users-table"]') do
        expect(rendered).to have_content('Users with highest role Guest')
        expect(rendered).to have_content('30')
      end
    end

    it 'renders minimal_access users under billable users' do
      within('[data-testid="billable-users-table"]') do
        expect(page).to have_content('Users with highest role Minimal access')
      end
    end
  end

  describe 'non-billable users section' do
    it 'renders non-billable users section' do
      expect(rendered).to have_selector('[data-testid="non-billable-users-table"]')
      expect(rendered).to have_content('Non-Billable users')
    end

    it 'displays users without groups and projects' do
      within('[data-testid="non-billable-users-table"]') do
        expect(rendered).to have_content('Users without a Group and Project')
        expect(rendered).to have_content('10')
      end
    end

    it 'displays the number of bots' do
      expect(rendered).to have_content('Bots')
      expect(rendered).to have_content('7')
    end
  end

  it 'renders the correct totals' do
    expect(rendered).to have_content('Active users (total billable + total non-billable) 123')
    expect(rendered).to have_content('Blocked users 5')
    expect(rendered).to have_content('Total users (active users + blocked users) 128')
  end

  context 'when there is an ultimate license' do
    before do
      create_current_license(plan: License::ULTIMATE_PLAN)

      render
    end

    it 'renders minimal_access users under non-billable users' do
      within('[data-testid="non-billable-users-table"]') do
        expect(page).to have_content('Users with highest role Minimal access')
      end
    end

    it 'does not render minimal_access users under billable users' do
      within('[data-testid="billable-users-table"]') do
        expect(page).not_to have_content('Users with highest role Minimal access')
      end
    end

    it 'renders the correct totals' do
      expect(rendered).to have_content('Active users (total billable + total non-billable) 123')
      expect(rendered).to have_content('Blocked users 5')
      expect(rendered).to have_content('Total users (active users + blocked users) 128')
    end

    it 'does not displays guest users within billable users table' do
      within('[data-testid="billable-users-table"]') do
        expect(rendered).not_to have_content('Users with highest role Guest')
        expect(rendered).not_to have_content('30')
      end
    end

    it 'displays guest users within non-billable users table' do
      within('[data-testid="non-billable-users-table"]') do
        expect(rendered).to have_content('Users with highest role Guest')
        expect(rendered).to have_content('30')
      end
    end
  end
end
