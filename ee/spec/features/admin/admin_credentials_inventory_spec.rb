# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin::CredentialsInventory', feature_category: :user_management do
  include Features::ResponsiveTableHelpers

  before do
    admin = create(:admin)
    sign_in(admin)
    enable_admin_mode!(admin)
  end

  context 'unlicensed' do
    before do
      stub_licensed_features(credentials_inventory: false)
    end

    it 'returns 404' do
      visit admin_credentials_path

      expect(page.status_code).to eq(404)
    end
  end

  context 'licensed' do
    before do
      stub_licensed_features(credentials_inventory: true)
    end

    context 'links', :js do
      before do
        visit admin_credentials_path
      end

      it 'has Credentials Inventory link in sidebar' do
        within_testid('super-sidebar') do
          expect(page).to have_link('Credentials', href: admin_credentials_path)
        end
      end

      context 'tabs' do
        it 'contains the relevant filter tabs' do
          expect(page).to have_link('Personal access tokens', href: admin_credentials_path(filter: 'personal_access_tokens'))
          expect(page).to have_link('SSH keys', href: admin_credentials_path(filter: 'ssh_keys'))
          expect(page).to have_link('GPG keys', href: admin_credentials_path(filter: 'gpg_keys'))
          expect(page).to have_link('Project and group access tokens', href: admin_credentials_path(filter: 'resource_access_tokens'))
        end
      end
    end

    context 'filtering' do
      context 'by personal access tokens' do
        let(:credentials_path) { admin_credentials_path(filter: 'personal_access_tokens') }

        it_behaves_like 'credentials inventory personal access tokens'

        context 'with granular tokens' do
          let_it_be(:user) { create(:user) }
          let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }
          let_it_be(:granular_personal_access_token) { create(:granular_pat, user: user, boundary: Authz::Boundary.for(create(:project)), permissions: :read_member_role) }

          it 'avoids N+1 queries', :request_store, :use_sql_query_cache do
            visit credentials_path

            control = ActiveRecord::QueryRecorder.new(skip_cached: false) { visit credentials_path }

            create_list(:personal_access_token, 3, user: create(:user))
            create_list(:granular_pat, 3, user: create(:user), boundary: Authz::Boundary.for(create(:project)), permissions: :read_member_role)

            expect { visit credentials_path }.to issue_same_number_of_queries_as(control)
          end
        end
      end

      context 'by SSH keys' do
        let(:credentials_path) { admin_credentials_path(filter: 'ssh_keys') }

        it_behaves_like 'credentials inventory SSH keys'
      end

      context 'by resource access tokens',
        quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/3361' do
        let_it_be(:credentials_path) { admin_credentials_path(filter: 'resource_access_tokens') }
        let_it_be(:group) { create(:group) }

        it_behaves_like 'credentials inventory resource access tokens'
      end

      context 'by GPG keys' do
        let(:credentials_path) { admin_credentials_path(filter: 'gpg_keys') }

        context 'when a GPG key is verified' do
          let_it_be(:user) { create(:user, name: 'User Name', email: GpgHelpers::User1.emails.first) }

          before_all do
            create(:gpg_key, user: user, key: GpgHelpers::User1.public_key)
          end

          before do
            visit credentials_path
          end

          it 'shows the details', :aggregate_failures do
            expect(first_row.text).to include('User Name')
            expect(first_row.text).to include(GpgHelpers::User1.primary_keyid)
            expect(first_row.text).to include('Verified')
          end
        end

        context 'when a GPG key is unverified' do
          let_it_be(:user) { create(:user, name: 'User Name', email: 'random@example.com') }

          before_all do
            create(:another_gpg_key, user: user)
          end

          before do
            visit credentials_path
          end

          it 'shows the details', :aggregate_failures do
            expect(first_row.text).to include('User Name')
            expect(first_row.text).to include(GpgHelpers::User1.primary_keyid2)
            expect(first_row.text).to include('Unverified')
          end
        end
      end
    end
  end
end
