# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples_for 'credentials inventory personal access tokens' do
  let_it_be(:user, freeze: false) { defined?(enterprise_user) ? enterprise_user : create(:user, name: 'abc') }

  context 'when a personal access token has an expiry' do
    let_it_be(:expiry_date, freeze: false) { 1.day.since.to_date.to_s }

    before_all do
      create(
        :personal_access_token,
        user: user,
        group: user.enterprise_group,
        created_at: '2019-12-10',
        updated_at: '2020-06-22',
        expires_at: expiry_date
      )
    end

    before do
      visit credentials_path
    end

    it 'shows the details with an expiry date' do
      expect(first_row.text).to include(expiry_date)
    end

    it 'has an expiry icon' do
      expect(first_row).to have_selector('[data-testid="expiry-date-icon"]')
    end

    # `SELECT 1/LIMIT 1` query is less performant than the actual query.
    # Controller explicitly loads the query to avoid this.
    it 'does not run a select 1 query' do
      recorded_queries = ActiveRecord::QueryRecorder.new do
        visit credentials_path
      end

      found_query = recorded_queries.log.any? do |q|
        q.starts_with?(/SELECT 1 AS one FROM "personal_access_tokens"/) && q.include?("LIMIT 1 OFFSET 0")
      end

      expect(found_query).to be false
    end
  end

  context 'when a personal access token is revoked' do
    before_all do
      create(:personal_access_token,
        :revoked,
        user: user,
        group: user.enterprise_group,
        created_at: '2019-12-10',
        updated_at: '2020-06-22',
        expires_at: Time.zone.now)
    end

    before do
      visit credentials_path
    end

    it 'shows the details with a revoked date', :aggregate_failures do
      expect(first_row.text).to include('2020-06-22')
      expect(first_row).not_to have_selector('a.btn', text: 'Revoke')
    end
  end
end

RSpec.shared_examples_for 'credentials inventory SSH keys' do
  let_it_be(:user, freeze: false) { defined?(enterprise_user) ? enterprise_user : create(:user, name: 'abc') }

  context 'when a SSH key is active' do
    before_all do
      create(
        :personal_key,
        user: user,
        created_at: '2019-12-09',
        last_used_at: '2019-12-10',
        expires_at: nil
      )
    end

    before do
      visit credentials_path
    end

    it 'shows the details', :aggregate_failures do
      expect(first_row.text).to include('abc')
      expect(first_row.text).to include('2019-12-09')
      expect(first_row.text).to include('2019-12-10')
      expect(first_row.text).to include('Never')
    end

    it 'shows the delete button' do
      expect(first_row).to have_selector('.js-confirm-modal-button', text: _('Delete'))
    end

    context 'and the user clicks the delete button', :js do
      it 'deletes the key' do
        click_button('Delete')

        page.within('.modal') do
          page.click_button('Delete')
        end

        expect(page).to have_content('User key was successfully removed.')
        expect(page).to have_content('No credentials found')
      end
    end
  end

  context 'when a SSH key has an expiry' do
    let_it_be(:expiry_date, freeze: false) { 1.day.since.to_date.to_s }

    before_all do
      create(
        :personal_key,
        user: user,
        created_at: '2019-12-10',
        last_used_at: '2020-06-22',
        expires_at: expiry_date
      )
    end

    before do
      visit credentials_path
    end

    it 'shows the details with an expiry date' do
      expect(first_row.text).to include(expiry_date)
    end

    it 'has an expiry icon' do
      expect(first_row).to have_selector('[data-testid="expiry-date-icon"]')
    end
  end
end

RSpec.shared_examples_for 'credentials inventory resource access tokens' do
  let_it_be(:admin, freeze: false) { create(:admin) }
  let_it_be(:user, freeze: false) { create(:user, :project_bot) }

  before_all do
    user.update!(bot_namespace: group, created_by: admin)
    group.add_developer(user)
  end

  context 'when a resource access token has an expiry' do
    let_it_be(:expiry_date, freeze: false) { 1.day.since.to_date.to_s }
    let_it_be(:pat, freeze: false) do
      create(
        :personal_access_token,
        user: user,
        group: group,
        created_at: '2019-12-10',
        updated_at: '2020-06-22',
        expires_at: expiry_date
      )
    end

    before do
      visit credentials_path
    end

    it 'shows the details with an expiry date' do
      expect(first_row.text).to include(expiry_date)
    end

    # `SELECT 1/LIMIT 1` query is less performant than the actual query.
    # Controller explicitly loads the query to avoid this.
    it 'does not run a select 1 query' do
      recorded_queries = ActiveRecord::QueryRecorder.new do
        visit credentials_path
      end

      found_query = recorded_queries.log.any? do |q|
        q.starts_with?(/SELECT 1 AS one FROM "personal_access_tokens"/) && q.include?("LIMIT 1 OFFSET 0")
      end

      expect(found_query).to be false
    end

    it 'shows the details', :aggregate_failures do
      expect(first_row.text).to include(pat.name)
      expect(first_row.text).to include('2019-12-10')
      expect(first_row.text).to include(expiry_date)
      expect(first_row.text).to include('Never')
    end

    context 'and the user clicks the revoke button', :js do
      it 'deletes the token' do
        click_link('Revoke')

        page.within('.modal') do
          page.click_button('OK')
        end

        expect(page).to have_content('has been revoked')
        expect(page).to have_content('No credentials found')
      end
    end
  end
end
