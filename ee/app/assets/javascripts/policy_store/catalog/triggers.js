import { s__ } from '~/locale';
import { CATEGORY_CI_CD } from './categories';

// Triggers a policy can respond to. `id` is persisted as the policy's `trigger_type`, so it
// is the wire value and must match what the metadata endpoint returns.
//
// The CD deployment gate experiment ships one trigger. See
// https://gitlab.com/gitlab-org/gitlab/-/issues/607341 for scope.
export const TRIGGER_DEPLOYMENT_REQUESTED = 'deployment_requested';

export const TRIGGERS = [
  {
    id: TRIGGER_DEPLOYMENT_REQUESTED,
    category: CATEGORY_CI_CD,
    label: s__('PolicyStore|Deployment'),
    description: s__('PolicyStore|When a deployment to a gated environment is requested'),
    icon: 'deployments',
    fields: [],
  },
];
