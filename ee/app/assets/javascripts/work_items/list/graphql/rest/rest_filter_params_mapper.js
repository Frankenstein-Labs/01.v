import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import {
  convertGraphQLVarsToRestParams as ceConvertGraphQLVarsToRestParams,
  WILDCARD_MAP as CE_WILDCARD_MAP,
} from '~/work_items/list/graphql/rest/rest_filter_params_mapper';

/* eslint-disable @gitlab/require-i18n-strings */
const WILDCARD_MAP = {
  ...CE_WILDCARD_MAP,
  CURRENT: 'Current',
};
/* eslint-enable @gitlab/require-i18n-strings */

const HEALTH_STATUS_GRAPHQL_TO_REST = {
  onTrack: 'on_track',
  needsAttention: 'needs_attention',
  atRisk: 'at_risk',
  NONE: 'none',
  ANY: 'any',
};

function mapHealthStatus(value) {
  if (Array.isArray(value)) {
    return value.map((v) => HEALTH_STATUS_GRAPHQL_TO_REST[v] ?? v);
  }
  return HEALTH_STATUS_GRAPHQL_TO_REST[value] ?? value;
}

function appendParam(params, key, value) {
  if (value === null || value === undefined) return;
  if (Array.isArray(value)) {
    value.forEach((v) => {
      if (v !== null && v !== undefined) params.append(`${key}[]`, v);
    });
  } else {
    params.append(key, value);
  }
}

export function convertGraphQLVarsToRestParams(vars) {
  const {
    healthStatusFilter: notHealthStatus,
    iterationWildcardId: notIterationWildcardId,
    ...notRest
  } = vars.not ?? {};
  const {
    healthStatusFilter: orHealthStatus,
    iterationWildcardId: orIterationWildcardId,
    ...orRest
  } = vars.or ?? {};

  const params = ceConvertGraphQLVarsToRestParams({
    ...vars,
    not: vars.not ? notRest : vars.not,
    or: vars.or ? orRest : vars.or,
  });

  appendParam(params, 'not[health_status_filter]', mapHealthStatus(notHealthStatus));
  appendParam(params, 'or[health_status_filter]', mapHealthStatus(orHealthStatus));
  appendParam(params, 'not[iteration_wildcard_id]', WILDCARD_MAP[notIterationWildcardId]);
  appendParam(params, 'or[iteration_wildcard_id]', WILDCARD_MAP[orIterationWildcardId]);

  appendParam(params, 'weight', vars.weight);
  appendParam(params, 'weight_wildcard_id', WILDCARD_MAP[vars.weightWildcardId]);
  appendParam(params, 'health_status_filter', mapHealthStatus(vars.healthStatusFilter));
  appendParam(params, 'iteration_id', vars.iterationId);
  appendParam(params, 'iteration_wildcard_id', WILDCARD_MAP[vars.iterationWildcardId]);
  appendParam(
    params,
    'iteration_cadence_id',
    Array.isArray(vars.iterationCadenceId)
      ? vars.iterationCadenceId.map((id) => getIdFromGraphQLId(id))
      : getIdFromGraphQLId(vars.iterationCadenceId),
  );

  if (vars.status) {
    if (vars.status.id) {
      params.append('status[id]', vars.status.id);
    }
    if (vars.status.name) {
      params.append('status[name]', vars.status.name);
    }
  }

  if (vars.customField?.length) {
    vars.customField.forEach((field) => {
      const customFieldId = getIdFromGraphQLId(field.customFieldId);
      if (!customFieldId) return;

      params.append('custom_field[][custom_field_id]', customFieldId);

      (field.selectedOptionIds ?? []).forEach((optionGid) => {
        const optionId = getIdFromGraphQLId(optionGid);
        if (optionId) {
          params.append('custom_field[][selected_option_ids][]', optionId);
        }
      });
    });
  }

  return params;
}
