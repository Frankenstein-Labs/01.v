import { s__ } from '~/locale';
import { logError } from '~/lib/logger';
import { captureException } from '~/sentry/sentry_browser_wrapper';

// This object maps flow type IDs to localized titles
//
// It should stay synchronized with the flow types defined in the Customers portal codebase:
// https://gitlab.com/gitlab-org/customers-gitlab-com/-/blob/main/app/models/billing/usage/flow_types.rb
//
// Note: When new flow types are added to the API but not yet included here,
// we will fall back to using the English title from the API response.
const LOCALIZED_FLOW_TYPES = {
  ai_catalog_agent: s__('UsageBillingFlowType|AI Catalog based Agent or Flow'),
  ai_gateway_proxy_use: s__('UsageBillingFlowType|AI Gateway Proxy'),
  amazon_q_integration: s__('UsageBillingFlowType|Duo with Amazon Q'),
  analytics_agent: s__('UsageBillingFlowType|Analytics Agent'),
  chat: s__('UsageBillingFlowType|Agentic Chat'),
  code_review: s__('UsageBillingFlowType|Code Review Flow'),
  code_suggestions: s__('UsageBillingFlowType|Code Suggestions'),
  convert_to_gl_ci: s__('UsageBillingFlowType|Convert to GitLab CI/CD Flow'),
  dap_feature_legacy: s__('UsageBillingFlowType|DAP Feature (Legacy)'),
  developer: s__('UsageBillingFlowType|Developer Flow'),
  duo_chat_classic: s__('UsageBillingFlowType|Duo Chat (Classic)'),
  duo_planner: s__('UsageBillingFlowType|Duo Planner'),
  fix_pipeline: s__('UsageBillingFlowType|Fix Pipeline Flow'),
  issue_to_merge_request: s__('UsageBillingFlowType|Issue to Merge Request Flow'),
  other_ai_usage: s__('UsageBillingFlowType|Other AI Usage'),
  resolve_sast_vulnerability: s__('UsageBillingFlowType|SAST Vulnerability Resolution Flow'),
  sast_fp_detection: s__('UsageBillingFlowType|SAST FP Detection Flow'),
  secrets_fp_detection: s__('UsageBillingFlowType|Secrets FP Detection'),
  security_analyst_agent: s__('UsageBillingFlowType|Security Analyst Agent'),
  software_development: s__('UsageBillingFlowType|Software Development Flow'),
};

/**
 * Transforms API response into a format suitable for the UI.
 *
 * @param {{id:string, title:string}[]} rawFlowTypes
 */
export function processFlowTypes(rawFlowTypes) {
  const idsMissingLocalisation = [];
  const localisedFlowTypes = rawFlowTypes.map((rawFlowType) => {
    const value = rawFlowType.id;
    // Find the localized title or fall back to the English title from the API
    let text = LOCALIZED_FLOW_TYPES[rawFlowType.id];
    if (!text) {
      idsMissingLocalisation.push(rawFlowType.id);
      text = rawFlowType.title;
    }
    return { value, text };
  });

  if (idsMissingLocalisation.length) {
    const error = new Error(`Missing localized flow type: ${idsMissingLocalisation.join(', ')}`);
    logError(error);
    captureException(error);
  }
  return localisedFlowTypes;
}
