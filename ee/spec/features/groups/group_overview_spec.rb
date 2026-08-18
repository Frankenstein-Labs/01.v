# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group information', :with_trial_types, :js, :aggregate_failures, feature_category: :groups_and_projects do
  include BillableMembersHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { create(:user) }
  let_it_be(:group, freeze: false) { create(:group) }

  let(:role) { :owner }

  subject(:visit_page) { visit group_path(group) }

  before do
    group.add_member(user, role)
    sign_in(user)
  end

  context 'when the default value of "Group information content" preference is used' do
    it 'displays the Details view' do
      visit_page

      page.within(find('.content')) do
        expect(page).to have_content _('Subgroups and projects')
        expect(page).to have_content _('Shared projects')
        expect(page).to have_content _('Inactive')
      end
    end
  end

  context 'when Security Dashboard view is set as default' do
    before do
      stub_licensed_features(security_dashboard: true)
      enable_namespace_license_check!
    end

    let(:user) { create(:user, group_view: :security_dashboard) }

    context 'and Security Dashboard feature is not available for a group', :saas do
      let(:group) { create(:group_with_plan, plan: :bronze_plan) }

      it 'falls back to the Details view' do
        visit_page

        page.within(find('.content')) do
          expect(page).to have_content _('Subgroups and projects')
        end
      end
    end
  end

  describe 'qrtly reconciliation alert' do
    context 'on self-managed' do
      before do
        visit_page
      end

      it_behaves_like 'a hidden qrtly reconciliation alert'
    end

    context 'on dotcom', :saas do
      before do
        stub_ee_application_setting(should_check_namespace_plan: true)
      end

      context 'when qrtly reconciliation is available' do
        let!(:upcoming_reconciliation) { create(:upcoming_reconciliation, :saas, namespace: group) }

        before do
          visit_page
        end

        it_behaves_like 'a visible dismissible qrtly reconciliation alert'
      end

      context 'when qrtly reconciliation is not available' do
        before do
          visit_page
        end

        it_behaves_like 'a hidden qrtly reconciliation alert'
      end
    end
  end

  context 'when over free user limit', :saas do
    let_it_be(:group, freeze: false) { create(:group_with_plan, :private, plan: :free_plan) }

    it_behaves_like 'over the free user limit alert'
  end

  context 'with all seats used alert', :saas, :use_clean_rails_memory_store_caching do
    context 'when all seats are used' do
      let_it_be(:subscription) { create(:gitlab_subscription, :premium, namespace: group, seats: 3) }

      before_all do
        # Seat-limit alerts are suppressed for subscriptions of 2 seats or fewer, so use a 3-seat
        # subscription with 3 billable members to exercise the reached-seat-limit alert.
        group.add_developer(create(:user))
        group.add_developer(create(:user))
      end

      before do
        stub_billable_members_reactive_cache(group)
      end

      context 'with seat block overages enabled' do
        before do
          group.namespace_settings.update!(seat_control: :block_overages)
        end

        it 'displays the reached seat count threshold alert' do
          visit_page

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
        where(:role) do
          ::Gitlab::Access.sym_options.keys.map(&:to_sym)
        end

        with_them do
          it 'does not display the reached seat count threshold alert' do
            visit_page

            expect(page).not_to have_css '[data-testid="reached-seat-count-threshold-alert"]'
          end
        end
      end
    end

    context 'when not all seats are used' do
      let_it_be(:subscription) { create(:gitlab_subscription, :premium, namespace: group, seats: 5) }

      before do
        stub_billable_members_reactive_cache(group)
      end

      it 'does not display any seat alert' do
        visit_page

        expect(page).not_to have_css '[data-testid="reached-seat-count-threshold-alert"]'
        expect(page).not_to have_css '[data-testid="approaching-seat-count-threshold-alert"]'
      end
    end

    context 'with a free plan' do
      let_it_be(:subscription) { create(:gitlab_subscription, :free, namespace: group, seats: 1) }

      before do
        stub_billable_members_reactive_cache(group)
      end

      it 'does not display the reached seat count threshold alert' do
        visit_page

        expect(page).not_to have_css '[data-testid="reached-seat-count-threshold-alert"]'
      end
    end
  end
end
