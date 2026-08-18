import { shallowMount } from '@vue/test-utils';
import FreeTrialBillingWithDapMonthlyCommitApp from 'ee/groups/billing/components/app_with_dap_monthly_commit.vue';
import CurrentPlanCard from 'ee/groups/billing/components/components_with_dap_monthly_commit/current_plan_card.vue';
import DapMonthlyCreditCard from 'ee/groups/billing/components/components_with_dap_monthly_commit/dap_monthly_credit_card.vue';

describe('FreeTrialBillingWithDapMonthlyCommitApp', () => {
  let wrapper;

  const findCurrentPlanCard = () => wrapper.findComponent(CurrentPlanCard);
  const findDapMonthlyCreditCard = () => wrapper.findComponent(DapMonthlyCreditCard);

  const createComponent = () => {
    wrapper = shallowMount(FreeTrialBillingWithDapMonthlyCommitApp);
  };

  it('renders current plan and credit card components', () => {
    createComponent();

    expect(findCurrentPlanCard().exists()).toBe(true);
    expect(findDapMonthlyCreditCard().exists()).toBe(true);
  });
});
