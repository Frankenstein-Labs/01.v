# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin::Credentials', :with_current_organization, feature_category: :user_management do
  include Features::AdminUsersHelpers

  let_it_be(:admin) { create(:admin, organizations: [current_organization]) }

  before do
    sign_in(admin)
    enable_admin_mode!(admin)
    stub_licensed_features(credentials_inventory: true)
  end

  describe 'GET /admin/credentials' do
    before do
      visit admin_credentials_path
    end

    it "is ok and shows no personal access tokens" do
      expect(page).to have_current_path(admin_credentials_path)
      expect(page).to have_content(s_('CredentialsInventory|No credentials found'))
    end

    describe 'search and filter', :js do
      before_all do
        create(:personal_access_token, name: 'my personal access token', user: admin, scopes: [:read_api],
          expires_at: 10.days.from_now)
        create(:personal_access_token, user: admin, scopes: [:manage_runner], revoked: true,
          expires_at: 10.days.from_now)
        create(:personal_access_token, user: admin, scopes: [:k8s_proxy], created_at: 1.day.ago,
          expires_at: 10.days.from_now)
        create(:personal_access_token, user: admin, scopes: [:read_repository], created_at: 1.day.from_now,
          expires_at: 10.days.from_now)
        create(:personal_access_token, user: admin, scopes: [:write_repository], last_used_at: 2.days.ago,
          expires_at: 10.days.from_now)
        create(:personal_access_token, user: admin, scopes: [:ai_features], last_used_at: 1.day.ago,
          expires_at: 10.days.from_now)
        create(:personal_access_token, user: admin, scopes: [:create_runner], expires_at: 2.days.from_now)
        create(:personal_access_token, user: admin, scopes: [:sudo], expires_at: 200.days.from_now)
      end

      it 'searches by token name' do
        expect_all_rows

        input_filtered_search_keys('my personal access token')

        expect_one_row_with_content('read_api')
      end

      it 'filters by type' do
        expect_all_rows

        input_filtered_search_filter_is_only(s_('CredentialsInventory|Type'), s_('CredentialsInventory|SSH keys'))

        expect(page).to have_content(s_('CredentialsInventory|No credentials found'))
      end

      it 'filters by state' do
        expect_all_rows

        input_filtered_search_filter_is_only(s_('CredentialsInventory|State'), s_('CredentialsInventory|Inactive'))

        expect_one_row_with_content('manage_runner')
      end

      it 'filters by revoke' do
        expect_all_rows

        input_filtered_search_filter_is_only(s_('CredentialsInventory|Revoked'), s_('CredentialsInventory|Yes'))

        expect_one_row_with_content('manage_runner')
      end

      describe 'created date' do
        it 'filters date before' do
          expect_all_rows

          input_filtered_search_filter_is_before(s_('CredentialsInventory|Created date'), 0.days.ago.to_date)

          expect_one_row_with_content('k8s_proxy')
        end

        it 'filters by date after' do
          expect_all_rows

          input_filtered_search_filter_is_after(s_('CredentialsInventory|Created date'), 1.day.from_now.to_date)

          expect_one_row_with_content('read_repository')
        end
      end

      describe 'expiration date' do
        it 'filters date before' do
          expect_all_rows

          input_filtered_search_filter_is_before(s_('CredentialsInventory|Expiration date'), 3.days.from_now.to_date)

          expect_one_row_with_content('create_runner')
        end

        it 'filters by date after' do
          expect_all_rows

          input_filtered_search_filter_is_after(s_('CredentialsInventory|Expiration date'), 200.days.from_now.to_date)

          expect_one_row_with_content('sudo')
        end
      end

      describe 'last used date' do
        it 'filters date before' do
          expect_all_rows

          input_filtered_search_filter_is_before(s_('CredentialsInventory|Last used date'), 1.day.ago.to_date)

          expect_one_row_with_content('write_repository')
        end

        it 'filters by date after' do
          expect_all_rows

          input_filtered_search_filter_is_after(s_('CredentialsInventory|Last used date'), 1.day.ago.to_date)

          expect_one_row_with_content('ai_features')
        end
      end

      describe 'shows correct search and filters based on the URL parameters' do
        it 'shows search' do
          visit admin_credentials_path(search: 'my personal access token')

          within_testid(filtered_search) do
            expect(page).to have_content('my personal access token')
          end
        end

        it 'shows type filter' do
          visit admin_credentials_path(filter: 'personal_access_tokens')

          within_testid(filtered_search) do
            expect(page).to have_content(
              "#{s_('CredentialsInventory|Type')} = #{s_('CredentialsInventory|Personal access tokens')}")
          end
        end

        it 'shows state filter' do
          visit admin_credentials_path(state: 'active')

          within_testid(filtered_search) do
            expect(page).to have_content("#{s_('CredentialsInventory|State')} = #{s_('CredentialsInventory|Active')}")
          end
        end

        it 'shows revoked filter' do
          visit admin_credentials_path(revoked: 'true')

          within_testid(filtered_search) do
            expect(page).to have_content("#{s_('CredentialsInventory|Revoked')} = #{s_('CredentialsInventory|Yes')}")
          end
        end

        describe 'created date' do
          it 'shows created date before filter' do
            visit admin_credentials_path(created_before: '2025-01-01')

            within_testid(filtered_search) do
              expect(page).to have_content("#{s_('CredentialsInventory|Created date')} < 2025-01-01")
            end
          end

          it 'shows created date before filter' do
            visit admin_credentials_path(created_after: '2025-01-01')

            within_testid(filtered_search) do
              expect(page).to have_content("#{s_('CredentialsInventory|Created date')} ≥ 2025-01-01")
            end
          end
        end

        describe 'expiration date' do
          it 'shows created date before filter' do
            visit admin_credentials_path(expires_before: '2025-01-01')

            within_testid(filtered_search) do
              expect(page).to have_content("#{s_('CredentialsInventory|Expiration date')} < 2025-01-01")
            end
          end

          it 'shows created date before filter' do
            visit admin_credentials_path(expires_after: '2025-01-01')

            within_testid(filtered_search) do
              expect(page).to have_content("#{s_('CredentialsInventory|Expiration date')} ≥ 2025-01-01")
            end
          end
        end

        describe 'last used date' do
          it 'shows last used date before filter' do
            visit admin_credentials_path(last_used_before: '2025-01-01')

            within_testid(filtered_search) do
              expect(page).to have_content("#{s_('CredentialsInventory|Last used date')} < 2025-01-01")
            end
          end

          it 'shows last used date before filter' do
            visit admin_credentials_path(last_used_after: '2025-01-01')

            within_testid(filtered_search) do
              expect(page).to have_content("#{s_('CredentialsInventory|Last used date')} ≥ 2025-01-01")
            end
          end
        end

        it 'ignores unknown filters' do
          visit admin_credentials_path(my_filter: 'true')

          within_testid(filtered_search) do
            expect(page).to have_content('')
          end
        end
      end
    end
  end

  def content_body
    '#content-body'
  end

  def expect_all_rows
    within(content_body) do
      expect(all_rows.size).to eq(8)
    end
  end

  def expect_one_row_with_content(content)
    within(content_body) do
      expect(all_rows.size).to eq(1)
      expect(page).to have_content(content)
    end
  end

  def all_rows
    page.all('.table-holder .gl-responsive-table-row:not(.table-row-header)[role="row"]')
  end

  def filtered_search
    'filtered-search-input'
  end

  # The filters must be clicked first to be able to receive events
  # See: https://gitlab.com/gitlab-org/gitlab-services/design.gitlab.com/-/issues/2799 [CLOSED]
  def focus_filtered_search
    page.find('.gl-filtered-search-term-token').click
  end

  def input_filtered_search_keys(search_term)
    within_testid(filtered_search) do
      focus_filtered_search

      send_keys(search_term)
      send_keys(:enter)

      click_on 'Search'
    end
  end

  def input_filtered_search_filter_is_only(filter, value)
    within_testid(filtered_search) do
      focus_filtered_search

      click_on filter

      # For OPERATORS_IS, clicking the filter
      # immediately preselects "=" operator
      send_keys(value)
      send_keys(:enter)

      click_on 'Search'
    end
  end

  def input_filtered_search_filter_is_before(filter, value)
    within_testid(filtered_search) do
      focus_filtered_search

      click_on filter

      send_keys('<')
      send_keys(value)
      send_keys(:enter)

      click_on 'Search'
    end
  end

  def input_filtered_search_filter_is_after(filter, value)
    within_testid(filtered_search) do
      focus_filtered_search

      click_on filter

      send_keys('≥')
      send_keys(value)
      send_keys(:enter)

      click_on 'Search'
    end
  end
end
