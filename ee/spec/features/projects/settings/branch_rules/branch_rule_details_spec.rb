# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Projects > Settings > Repository > Branch rules > Branch rule details', :js, feature_category: :source_code_management do
  include Spec::Support::Helpers::ModalHelpers
  include ListboxHelpers

  let_it_be(:user) { create(:user) }

  let_it_be_with_reload(:branch_rule) do
    create(
      :protected_branch,
      code_owner_approval_required: true,
      allow_force_push: false
    )
  end

  let_it_be(:project) { branch_rule.project }

  before_all do
    project.add_maintainer(user)
  end

  before do
    sign_in(user)
  end

  context 'when not licensed' do
    before do
      stub_licensed_features(merge_request_approvers: false, external_status_checks: false,
        multiple_approval_rules: false, protected_refs_for_users: false)
    end

    context 'with custom rule' do
      before do
        visit_branch_rule_details
        wait_for_requests
      end

      it 'does not render licensed feature additions', :aggregate_failures do
        within_testid('allowed-to-push-content') do
          expect(page).to have_button('Edit')
          click_button 'Edit'
        end

        within('.gl-drawer') do
          expect(page).not_to have_css '[data-testid="users-selector"]', text: 'Users'
          expect(page).not_to have_css '[data-testid="groups-selector"]', text: 'Groups'
        end

        expect(page).not_to have_css('[data-testid="code-owners-content"]')
        expect(page).not_to have_text 'Approval rules'
        expect(page).not_to have_text 'Status checks'
      end
    end
  end

  context 'when licensed' do
    before do
      stub_licensed_features(merge_request_approvers: true, external_status_checks: true,
        multiple_approval_rules: true, protected_refs_for_users: true, branch_rule_squash_options: true)
    end

    context 'with custom rule' do
      let!(:external_status_check) do
        create(:external_status_check, project: project, protected_branches: [branch_rule])
      end

      before do
        visit_branch_rule_details
        wait_for_requests
      end

      it 'renders EE-specific rule details' do
        expect(page).to have_text 'Approval rules'
        expect(page).to have_text 'Status checks'
      end

      it 'renders users and groups selectors in access control drawer', :aggregate_failures do
        within_testid('allowed-to-push-content') do
          click_button 'Edit'
        end

        within('.gl-drawer') do
          expect(page).to have_css '[data-testid="users-selector"]', text: 'Users'
          expect(page).to have_css '[data-testid="groups-selector"]', text: 'Groups'
        end
      end

      describe 'Access control - users and groups' do
        let_it_be(:other_user) { create(:user, name: 'Jane Doe') }
        let_it_be(:group) { create(:group, name: 'Test Group') }
        let_it_be(:deploy_key) { create(:deploy_key, user: user, write_access_to: project) }

        before_all do
          project.add_developer(other_user)
          project.project_group_links.create!(group: group, group_access: Gitlab::Access::DEVELOPER)
        end

        context 'for Allowed to merge' do
          it 'can add combination of roles, users, and groups', :aggregate_failures do
            within_testid('allowed-to-merge-content') do
              click_button 'Edit'
            end

            within('.gl-drawer') do
              check 'Maintainers'

              within_testid('users-selector') do
                find('.form-control').click
                find('.gl-new-dropdown-item', text: other_user.name).click
              end

              within_testid('groups-selector') do
                find('.form-control').click
                find('.gl-new-dropdown-item', text: group.name).click
              end

              click_button 'Save changes'
            end

            wait_for_requests

            within_testid('allowed-to-merge-content') do
              expect(page).to have_text 'Maintainers'
              expect(page).to have_link(other_user.name)
              expect(page).to have_link(group.name)
            end
          end
        end

        context 'for Allowed to push and merge' do
          it 'can add combination of roles, users, groups, and deploy keys', :aggregate_failures do
            within_testid('allowed-to-push-content') do
              click_button 'Edit'
            end

            within('.gl-drawer') do
              check 'Maintainers'

              within_testid('users-selector') do
                find('.form-control').click
                find('.gl-new-dropdown-item', text: other_user.name).click
              end

              within_testid('groups-selector') do
                find('.form-control').click
                find('.gl-new-dropdown-item', text: group.name).click
              end

              within_testid('deploy-keys-selector') do
                find('.form-control').click
                find('.gl-new-dropdown-item', text: deploy_key.title).click
              end

              click_button 'Save changes'
            end

            wait_for_requests

            within_testid('allowed-to-push-content') do
              expect(page).to have_text 'Maintainers'
              expect(page).to have_link(other_user.name)
              expect(page).to have_link(group.name)
              expect(page).to have_text deploy_key.title
            end
          end
        end
      end

      describe 'Code Owner Approval toggle' do
        before do
          stub_licensed_features(code_owner_approval_required: true)
        end

        it 'can toggle code owner approval value' do
          branch_rule.update!(code_owner_approval_required: false)
          visit_branch_rule_details
          wait_for_requests

          within_testid('code-owners-content') do
            find('button').click
          end

          wait_for_requests
          visit_branch_rule_details
          wait_for_requests

          within_testid('code-owners-content') do
            toggle = find('button')
            expect(toggle[:class]).to include('is-checked')
          end
        end
      end

      describe 'Status checks' do
        it 'can create status check', :aggregate_failures do
          within_testid('status-checks-table') do
            click_button('Add status check')
          end

          within_testid('status-checks-drawer') do
            fill_in 'Service name', with: 'QA'
            fill_in 'API to check', with: 'https://example.com'
            click_button('Save changes')
          end

          wait_for_requests

          within_testid('status-checks-table') do
            within_testid('crud-body') do
              expect(page).to have_content('QA')
              expect(page).to have_content('https://example.com')
            end
          end
        end

        it 'can update status check', :aggregate_failures do
          within_testid('status-checks-table') do
            click_button "Edit #{external_status_check.name}"
          end

          within_testid('status-checks-drawer') do
            fill_in 'Service name', with: 'QA'
            fill_in 'API to check', with: 'https://example2.com'
            click_button('Save changes')
          end

          wait_for_requests

          within_testid('status-checks-table') do
            within_testid('crud-body') do
              expect(page).to have_content('QA')
              expect(page).to have_content('https://example2.com')
            end
          end
        end

        it 'can delete status check', :aggregate_failures do
          within_testid('status-checks-table') do
            click_button "Delete"
          end

          click_button "Delete status check"
          wait_for_requests

          within_testid('status-checks-table') do
            within_testid('crud-body') do
              expect(page).not_to have_content(external_status_check.name)
              expect(page).not_to have_content(external_status_check.external_url)
            end
          end
        end
      end

      describe 'Squash commits settings' do
        it 'renders squash commits section with edit button' do
          within_testid('squash-setting-content') do
            expect(page).to have_text 'Squash commits when merging'
            expect(page).to have_button 'Edit'
          end
        end
      end

      it 'passes axe automated accessibility testing with users and groups drawer' do
        within_testid('allowed-to-merge-content') do
          click_button 'Edit'
        end

        within('.gl-drawer') do
          expect(page).to be_axe_clean.skipping :'link-in-text-block'
        end
      end
    end
  end

  def visit_branch_rule_details
    visit project_settings_repository_branch_rules_path(project, params: { branch: branch_rule.name })
  end
end
