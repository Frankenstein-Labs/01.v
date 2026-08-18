# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project show page', :with_trial_types, :feature, feature_category: :groups_and_projects do
  include BillableMembersHelpers

  let_it_be(:user) { create(:user) }

  describe 'stat button existence' do
    describe 'populated project' do
      let(:project) { create(:project, :public, :repository) }

      describe 'as a maintainer' do
        before do
          project.add_maintainer(user)
          sign_in(user)
        end

        it '"Kubernetes cluster" button linked to clusters page' do
          create(:cluster, :provided_by_gcp, projects: [project])
          create(:cluster, :provided_by_gcp, :production_environment, projects: [project])

          visit project_path(project)

          page.within('.project-buttons') do
            expect(page).to have_link('Kubernetes', href: project_clusters_path(project))
          end
        end
      end
    end
  end

  describe 'pull mirroring information' do
    let_it_be(:project) do
      create(:project, :repository, mirror: true, mirror_user: user, import_url: 'http://user:pass@test.com')
    end

    context 'for developer' do
      before do
        project.add_developer(user)
        sign_in(user)

        visit project_path(project)
      end

      it 'displays mirrored from url' do
        expect(page).to have_content("Mirrored from http://*****:*****@test.com")
      end
    end

    context 'for guest' do
      before do
        project.add_guest(user)
        sign_in(user)

        visit project_path(project)
      end

      it 'does not display mirrored from url' do
        expect(page).not_to have_content("Mirrored from http://*****:*****@test.com")
      end
    end
  end

  context 'when over free user limit', :saas do
    subject(:visit_page) { visit project_path(project) }

    context 'with group namespace' do
      let(:role) { :owner }
      let_it_be_with_refind(:group) { create(:group_with_plan, :private, plan: :free_plan) }

      before do
        group.add_member(user, role)
        sign_in(user)
      end

      context 'with repository' do
        let_it_be(:project) { create(:project, :repository, :private, group: group) }

        it_behaves_like 'over the free user limit alert'
      end

      context 'with empty repository' do
        let_it_be(:project) { create(:project, :empty_repo, :private, group: group) }

        it_behaves_like 'over the free user limit alert'
      end

      context 'without repository' do
        let_it_be(:project) { create(:project, :private, group: group) }

        it_behaves_like 'over the free user limit alert'
      end
    end
  end

  context "when user has no permissions" do
    let_it_be(:project) { create(:project, :public, :repository) }

    it 'does not render settings button if user has no permissions', :js do
      visit project_path(project)

      find_by_testid('projects-list-item-actions').click

      expect(page).not_to have_link(_('Edit'))
    end

    it 'renders settings button if user has permissions', :js do
      project.add_maintainer(user)
      sign_in(user)
      visit project_path(project)

      find_by_testid('projects-list-item-actions').click

      expect(page).to have_link(_('Edit'))
    end
  end

  describe 'all seats used alert', :saas, :use_clean_rails_memory_store_caching do
    let_it_be_with_refind(:group) { create(:group) }
    let_it_be(:project) { create(:project, namespace: group) }

    before do
      group.namespace_settings.update!(seat_control: :block_overages)
      sign_in(user)
    end

    context 'when all seats are used' do
      let_it_be(:subscription) { create(:gitlab_subscription, :premium, namespace: group, seats: 3) }

      context 'when the user is an owner' do
        before do
          group.add_owner(user)
          # Seat-limit alerts are suppressed for subscriptions of 2 seats or fewer, so use a 3-seat
          # subscription with 3 billable members to exercise the reached-seat-limit alert.
          group.add_developer(create(:user))
          group.add_developer(create(:user))
          stub_billable_members_reactive_cache(group)
        end

        it 'displays the reached seat count threshold alert' do
          visit project_path(project)

          expect(page).to have_css '[data-testid="reached-seat-count-threshold-alert"].gl-alert-warning'

          within_testid('reached-seat-count-threshold-alert') do
            expect(page).to have_css('[data-testid="close-icon"]')
            expect(page).to have_text "Your namespace has reached its seat limit"
            expect(page).to have_text "Your namespace has used all 3 seats. Restricted " \
                                        "access is blocking new users from being added to prevent overages. " \
                                        "Purchase more seats or turn off restricted access to allow new users."
            expect(page).to have_link 'Purchase more seats', href:
              help_page_path('subscriptions/manage_seats.md', anchor: 'buy-more-seats')
            expect(page).to have_link 'Turn off restricted access'
          end
        end
      end

      context 'when the user is not an owner' do
        let(:role) { :developer }

        it 'does not display the reached seat count threshold alert' do
          visit project_path(project)

          expect(page).not_to have_css '[data-testid="reached-seat-count-threshold-alert"]'
        end
      end
    end

    context 'with a free plan' do
      let_it_be(:subscription) { create(:gitlab_subscription, :free, namespace: group, seats: 1) }

      before do
        stub_billable_members_reactive_cache(group)
      end

      it 'does not display the reached seat count threshold alert' do
        visit project_path(project)

        expect(page).not_to have_css '[data-testid="reached-seat-count-threshold-alert"]'
      end
    end

    context 'when not all seats are used' do
      let_it_be(:subscription) { create(:gitlab_subscription, :premium, namespace: group, seats: 3) }

      before do
        stub_billable_members_reactive_cache(group)
      end

      it 'does not display any seat alert' do
        visit project_path(project)

        expect(page).not_to have_css '[data-testid="reached-seat-count-threshold-alert"]'
        expect(page).not_to have_css '[data-testid="approaching-seat-count-threshold-alert"]'
      end
    end
  end

  describe 'pages deployments limit alert' do
    let_it_be_with_refind(:group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, :public, :repository, namespace: group) }
    let(:user) { create(:user) }
    let(:limit) { 10 }

    before do
      allow(License).to receive(:feature_available?).and_return(true)
      stub_pages_setting(enabled: true)
      group.add_member(user, role)
      sign_in(user)
      project.actual_limits.update!(active_versioned_pages_deployments_limit_by_namespace: limit)
      project.project_setting.update!(pages_unique_domain_enabled: false)
      deployments.times do |n|
        create(:pages_deployment, project: project, path_prefix: "foo_#{n}")
      end
    end

    context 'when the user can edit pages deployments' do
      let(:role) { :maintainer }

      context 'when there are fewer deployments than 80% of the limit' do
        let(:deployments) { 1 }

        it 'does not display any warning' do
          visit project_path(project)

          expect(page).not_to have_text "You are almost out of Pages parallel deployments"
          expect(page).not_to have_text "You are out of Pages parallel deployments"
        end
      end

      context 'when there are more deployments than 80% of the limit' do
        let(:deployments) { 9 }

        it 'does display the 80% warning' do
          visit project_path(project)

          expect(page).to have_text "You are almost out of Pages parallel deployments"
          expect(page).not_to have_text "You are out of Pages parallel deployments"
        end
      end

      context 'when there are as many deployments as the limit' do
        let(:deployments) { 10 }

        it 'does display the "out of deployments" warning' do
          visit project_path(project)

          expect(page).not_to have_text "You are almost out of Pages parallel deployments"
          expect(page).to have_text "You are out of Pages parallel deployments"
        end
      end

      context 'when there are more deployments than the limit' do
        let(:deployments) { 11 }

        it 'does display the "out of deployments" warning' do
          visit project_path(project)

          expect(page).not_to have_text "You are almost out of Pages parallel deployments"
          expect(page).to have_text "You are out of Pages parallel deployments"
        end
      end

      context 'when the limit is 0' do
        let(:limit) { 0 }
        let(:deployments) { 0 }

        it 'does not display any warning' do
          visit project_path(project)

          expect(page).not_to have_text "You are almost out of Pages parallel deployments"
          expect(page).not_to have_text "You are out of Pages parallel deployments"
        end
      end
    end

    context 'when the user cannot edit pages deployments' do
      let(:role) { :guest }
      let(:limit) { 10 }

      context 'when there are more deployments than 80% of the limit' do
        let(:deployments) { 9 }

        it 'does not display any warning' do
          visit project_path(project)

          expect(page).not_to have_text "You are almost out of Pages parallel deployments"
          expect(page).not_to have_text "You are out of Pages parallel deployments"
        end
      end

      context 'when there are as many deployments as the limit' do
        let(:deployments) { 10 }

        it 'does not display any warning' do
          visit project_path(project)

          expect(page).not_to have_text "You are almost out of Pages parallel deployments"
          expect(page).not_to have_text "You are out of Pages parallel deployments"
        end
      end
    end
  end

  context 'with free tier badge', :js, :saas do
    let(:path) { project_path(project) }
    let(:tier_badge_selector) { '[data-testid="group-tier-badge"]' }
    let(:tier_badge_element) { page.find(tier_badge_selector) }
    let(:popover_element) { page.find('.gl-popover') }

    before do
      project.add_maintainer(user)
      sign_in(user)
      visit path
    end

    context 'when project is part of a group' do
      let_it_be(:group) { create(:group, :private, owners: user) }
      let_it_be(:project) { create(:project, :repository, namespace: group) }

      it 'renders the tier badge and popover when clicked', :aggregate_failures do
        expect(tier_badge_element).to be_present

        tier_badge_element.click

        expect(popover_element.text).to include('Enhance team productivity')
        expect(popover_element.text).to include('This project uses the Free GitLab tier.')
      end
    end

    context 'when project is not part of a group' do
      let_it_be(:project) { create(:project, :repository, namespace: user.namespace) }

      it 'does not render the tier badge' do
        expect(page).to have_current_path(project_path(project))
        expect(page).not_to have_selector(tier_badge_selector)
      end
    end
  end
end
