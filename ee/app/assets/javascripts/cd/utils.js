import {
  SERVICE_HEALTH_SEVERITY_ORDER,
  SERVICE_HEALTH_VARIANTS,
  SERVICE_HEALTH_LABELS,
  SERVICE_HEALTH_DOT_CLASSES,
  EMPTY_PLACEHOLDER,
  ROLLOUT_STATE_VARIANTS,
  ROLLOUT_STATE_LABELS,
  ROLLOUT_STATE_DOT_CLASSES,
  NEUTRAL_BG_CLASS,
  ROW_CLASS,
} from './constants';

const worstHealth = (healths) =>
  SERVICE_HEALTH_SEVERITY_ORDER.find((health) => healths.includes(health)) ?? null;

export const worstRolloutHealth = (rollout) =>
  worstHealth(
    rollout?.rolloutEnvironments?.nodes?.flatMap(
      (rolloutEnvironment) =>
        rolloutEnvironment.environment?.serviceEnvironmentHealths?.nodes?.map(
          (serviceHealth) => serviceHealth.health,
        ) ?? [],
    ) ?? [],
  );

export const environmentHealth = (environment) =>
  worstHealth(
    environment?.serviceEnvironmentHealths?.nodes?.map((serviceHealth) => serviceHealth.health) ??
      [],
  );

// Cd::Service.serviceEnvironmentHealths is ordered worst-first by the backend
// (ordered_by_severity default scope), so the first node is the worst health.
export const worstServiceHealth = (service) =>
  service?.serviceEnvironmentHealths?.nodes?.[0]?.health ?? null;

export const healthVariant = (health) => SERVICE_HEALTH_VARIANTS[health] ?? 'neutral';

export const healthLabel = (health) => SERVICE_HEALTH_LABELS[health] ?? EMPTY_PLACEHOLDER;

export const healthDotClass = (health) =>
  SERVICE_HEALTH_DOT_CLASSES[health] ?? SERVICE_HEALTH_DOT_CLASSES.UNKNOWN;

export const rolloutStateVariant = (state) => ROLLOUT_STATE_VARIANTS[state] ?? 'neutral';

export const rolloutStateLabel = (state) => ROLLOUT_STATE_LABELS[state] ?? '';

export const rolloutStateDotClass = (state) => ROLLOUT_STATE_DOT_CLASSES[state] ?? NEUTRAL_BG_CLASS;

export const buildRowClass = (id, matchers) => {
  const match = matchers.find(([matchId]) => matchId != null && matchId === id);
  return match ? [ROW_CLASS, match[1]] : ROW_CLASS;
};
