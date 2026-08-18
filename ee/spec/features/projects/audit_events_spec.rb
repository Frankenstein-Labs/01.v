# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Projects > Audit events', :js, feature_category: :audit_events do
  include Features::MembersHelpers
  include ListboxHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:pete) { create(:user, name: 'Pete') }
  let_it_be_with_reload(:project) { create(:project, :repository, namespace: user.namespace) }

  before do
    project.add_maintainer(user)
    stub_feature_flags(show_role_details_in_drawer: false)
    sign_in(user)
  end

  context 'unlicensed' do
    before do
      stub_licensed_features(audit_events: false)
    end

    it 'returns 404' do
      reqs = inspect_requests do
        visit project_audit_events_path(project)
      end

      expect(reqs.first.status_code).to eq(404)
    end

    it 'does not have audit events button in head nav bar' do
      visit edit_project_path(project)

      expect(page).not_to have_link('Audit events')
    end
  end

  context 'unlicensed but we show promotions' do
    before do
      stub_licensed_features(audit_events: false)
      allow(License).to receive(:current).and_return(nil)
      stub_application_setting(check_namespace_plan: false)
      allow(LicenseHelper).to receive(:show_promotions?).and_return(true)
    end

    include_context '"Security and compliance" permissions' do
      let(:response) { inspect_requests { visit project_audit_events_path(project) }.first }
    end

    it 'returns 200' do
      reqs = inspect_requests do
        visit project_audit_events_path(project)
      end

      expect(reqs.first.status_code).to eq(200)
    end

    it 'has audit events button in head nav bar' do
      visit project_audit_events_path(project)

      expect(page).to have_link('Audit events')
    end

    it 'does not have Project audit events in the header' do
      visit project_audit_events_path(project)

      expect(page).not_to have_content('Project audit events')
    end
  end

  it 'has audit events button in head nav bar' do
    visit project_audit_events_path(project)

    expect(page).to have_link('Audit events')
  end

  it 'has Project audit events in the header' do
    visit project_audit_events_path(project)

    expect(page).to have_content('Project audit events')
  end

  describe 'adding an SSH key' do
    let(:ssh_key) { Gitlab::SSHPublicKey.new(SSHData::PrivateKey::RSA.generate(3072).public_key.openssh).key_text }

    it "appears in the project's audit events" do
      stub_licensed_features(audit_events: true)

      visit new_project_deploy_key_path(project)
      click_button 'Add new key'

      fill_in 'deploy_key_title', with: 'laptop'
      fill_in 'deploy_key_key', with: "#{ssh_key} user@laptop"

      click_button 'Add key'

      within_testid('project-deploy-keys-container') do
        expect(page).to have_content('laptop')
        click_button 'Remove'
      end

      click_button 'Remove deploy key'

      expect(page).not_to have_button('Remove deploy key', wait: 10)

      visit project_audit_events_path(project)

      wait_for('Audit event background creation job is done', polling_interval: 0.5, reload: true) do
        page.has_content?('Added deploy key', wait: 0) &&
          page.has_content?('Removed deploy key', wait: 0)
      end
    end
  end

  describe 'changing a user access level' do
    before do
      project.add_developer(pete)
    end

    it "appears in the project's audit events" do
      visit project_project_members_path(project)

      page.within find_member_row(pete) do
        select_from_listbox 'Maintainer', from: 'Developer'
      end

      wait_for_all_requests

      visit project_audit_events_path(project)

      page.within('.audit-log-table') do
        expect(page).to have_content 'Changed access level from Default role: Developer to Default role: Maintainer'
        expect(page).to have_content(project.first_owner.name)
        expect(page).to have_content('Pete')
      end
    end
  end

  describe 'changing merge request approval permission for authors and reviewers' do
    before do
      stub_licensed_features(merge_request_approvers: true)
      project.add_developer(pete)
    end

    it "appears in the project's audit events", :js do
      visit project_settings_merge_requests_path(project)

      expect(page).to have_checked_field('Prevent approval by merge request creator')
      expect(page).to have_unchecked_field('Prevent approvals by users who add commits')

      within_testid('merge-request-approval-settings') do
        find_field('Prevent approval by merge request creator').set(false)
        find_field('Prevent approvals by users who add commits').set(true)
        click_button 'Save changes'
      end

      expect(page).to have_content('Merge request approval settings have been updated')

      visit project_audit_events_path(project)

      page.within('.audit-log-table') do
        expect(page).to have_content(project.first_owner.name)
        expect(page).to have_content('Changed prevent merge request approval from authors')
        expect(page).to have_content('Changed prevent merge request approval from committers')
        expect(page).to have_content(project.name)
      end
    end
  end

  describe 'combined list of authenticated and unauthenticated users' do
    let_it_be(:audit_event_1) { create(:audit_events_project_audit_event, :unauthenticated, project_id: project.id) }
    let_it_be(:audit_event_2) { create(:audit_events_project_audit_event, author_id: non_existing_record_id, project_id: project.id) }
    let_it_be(:audit_event_3) { create(:audit_events_project_audit_event, project_id: project.id) }

    it 'displays the correct authors names' do
      visit project_audit_events_path(project)

      wait_for_all_requests

      page.within('.audit-log-table') do
        expect(page).to have_content('An unauthenticated user')
        expect(page).to have_content("#{audit_event_2.author_name} (removed)")
        expect(page).to have_content(audit_event_3.user.name)
      end
    end
  end

  describe 'audit event filter' do
    let_it_be(:events_path) { :project_audit_events_path }
    let_it_be(:entity) { project }

    describe 'filter by date' do
      let_it_be(:audit_event_1) { create(:audit_events_project_audit_event, project_id: project.id, created_at: 5.days.ago) }
      let_it_be(:audit_event_2) { create(:audit_events_project_audit_event, project_id: project.id, created_at: 3.days.ago) }
      let_it_be(:audit_event_3) { create(:audit_events_project_audit_event, project_id: project.id, created_at: Date.current) }

      it_behaves_like 'audit events date filter'
    end

    context 'signed in as a developer' do
      before do
        project.add_developer(pete)
        sign_in(pete)
      end

      describe 'filter by author' do
        let_it_be(:audit_event_1) { create(:audit_events_project_audit_event, project_id: project.id, created_at: Date.today, ip_address: '1.1.1.1', author_id: pete.id) }
        let_it_be(:audit_event_2) { create(:audit_events_project_audit_event, project_id: project.id, created_at: Date.today, ip_address: '0.0.0.0', author_id: user.id) }
        let_it_be(:author) { user }

        it_behaves_like 'audit events author filtering without entity admin permission'
      end
    end
  end
end
