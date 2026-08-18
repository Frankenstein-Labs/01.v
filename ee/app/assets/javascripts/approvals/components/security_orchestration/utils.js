import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import projectSecurityPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_security_policies.query.graphql';
import groupSecurityPoliciesQuery from 'ee/security_orchestration/graphql/queries/group_security_policies.query.graphql';
import { APPROVAL_POLICY_FILTER_TYPE } from 'ee/security_orchestration/components/policies/constants';
import { fromYaml } from 'ee/security_orchestration/components/utils';
import { flattenPolicies } from 'ee/security_orchestration/components/policies/utils';

export const securityPoliciesQuery = ({ isGroup = false, fullPath } = {}) => ({
  query: isGroup ? groupSecurityPoliciesQuery : projectSecurityPoliciesQuery,
  variables: () => ({ fullPath, type: APPROVAL_POLICY_FILTER_TYPE }),
  update(data) {
    return data?.namespace?.securityPolicies?.nodes ?? [];
  },
  error(error) {
    createAlert({
      message: s__(
        'SecurityOrchestration|An error occurred while fetching the scan result policies.',
      ),
    });
    Sentry.captureException(error);
  },
});

export const parsePolicies = (rawPolicies, fullPath) => {
  return flattenPolicies(rawPolicies)
    .map((rawPolicy) => {
      const parsed = fromYaml({ manifest: rawPolicy.yaml });
      if (!parsed.name) return null; // fromYaml catches parse errors and returns {}; no name means failed parse

      return {
        ...parsed,
        actionApprovers: rawPolicy.actionApprovers,
        editPath: rawPolicy.editPath,
        source: rawPolicy.source || { project: { fullPath } },
      };
    })
    .filter(Boolean);
};
