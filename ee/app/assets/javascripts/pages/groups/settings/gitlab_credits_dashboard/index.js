import { parseBoolean } from '~/lib/utils/common_utils';
import { initGitlabCreditsDashboard } from 'ee/usage_quotas/wallet_agnostic_credits_dashboard/index';
import { initUsageBillingDashboard } from 'ee/usage_quotas/usage_billing/index';

const el = document.getElementById('js-group-usage-billing-dashboard');
const isFree = parseBoolean(el?.dataset?.isFree);

if (gon?.features?.walletAgnosticCreditsDashboard && !isFree) {
  initGitlabCreditsDashboard(el);
} else {
  initUsageBillingDashboard(el);
}
