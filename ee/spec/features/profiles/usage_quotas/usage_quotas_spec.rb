# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Profile > Usage Quota', :js, feature_category: :consumables_cost_management do
  include ::Ci::MinutesHelpers
  include UsageQuotasHelpers

  using RSpec::Parameterized::TableSyntax

  let_it_be_with_reload(:user) { create(:user, :with_namespace) }
  let_it_be_with_reload(:namespace) { user.namespace }
  let_it_be_with_reload(:statistics) { create(:namespace_statistics, namespace: namespace) }
  let_it_be_with_reload(:project) { create(:project, namespace: namespace) }

  before do
    setup_usage_quotas_env(namespace.id)
    stub_ee_application_setting(should_check_namespace_plan: true)
    sign_in(user)
  end

  describe 'shared runners use' do
    let(:no_shared_runners_text) do
      'No compute usage data because Instance runners are disabled, ' \
        'or there are no projects in this group.'
    end

    where(:used, :quota, :usage_text) do
      300  | nil | '300 / Unlimited compute minutes'
      300  | 500 | '300 / 500 compute minutes'
      1000 | 500 | '1,000 / 500 compute minutes'
    end

    with_them do
      before do
        project.update!(shared_runners_enabled: true)
        set_ci_minutes_used(namespace, used, project: project)
        namespace.update!(shared_runners_minutes_limit: quota)

        visit_usage_quotas_page
        wait_for_requests
      end

      it 'shows the correct quota status' do
        within_testid('pipelines-tab-app') do
          expect(page).to have_content(usage_text)
        end
      end

      it 'shows the correct per-project metrics' do
        within_testid('pipelines-quota-tab-project-table') do
          expect(page).to have_content(project.name)
          expect(page).not_to have_content(no_shared_runners_text)
        end
      end
    end

    context 'when the instance runners are disabled' do
      before do
        project.update!(shared_runners_enabled: false)
        set_ci_minutes_used(namespace, 300, project: project)
        namespace.update!(shared_runners_minutes_limit: 500)

        visit_usage_quotas_page
        wait_for_requests
      end

      it 'shows an info alert message' do
        within_testid('instance-runners-disabled-alert') do
          expect(page).to have_content('Instance runners are disabled in all projects in this namespace.')
        end
      end

      it 'shows the correct quota status' do
        within_testid('pipelines-tab-app') do
          expect(page).to have_content('300 compute minutes / Not supported')
        end
      end

      it 'shows the correct per-project metrics' do
        within_testid('pipelines-quota-tab-project-table') do
          expect(page).to have_content(project.name)
          expect(page).to have_content(no_shared_runners_text)
        end
      end
    end

    context 'with pagination' do
      let(:per_page) { 1 }
      let(:item_selector) { '.js-project-link' }
      let(:prev_button_selector) { '[data-testid="prevButton"]' }
      let(:next_button_selector) { '[data-testid="nextButton"]' }
      let!(:projects) { create_list(:project, 3, :with_ci_minutes, amount_used: 5, namespace: namespace) }

      before do
        allow(Kaminari.config).to receive(:default_per_page).and_return(per_page)
      end

      context 'on storage tab' do
        before do
          visit_usage_quotas_page('storage-quota-tab')
        end

        it_behaves_like 'correct pagination'
      end

      context 'on pipelines tab', feature_category: :continuous_integration do
        let(:item_selector) { '[data-testid="pipelines-quota-tab-project-name"]' }

        context 'when namespace_monthly_usage exists' do
          before do
            create(:ci_namespace_monthly_usage, namespace: namespace)
            visit_usage_quotas_page
          end

          it_behaves_like 'correct pagination'
        end
      end
    end
  end

  def visit_usage_quotas_page(anchor = 'pipelines-quota-tab')
    visit profile_usage_quotas_path(namespace, anchor: anchor)
  end
end
