import { humanizeTimeInterval } from '~/lib/utils/datetime_utility';
import { humanize } from '~/lib/utils/text_utility';
import {
  FLOW_ITEM_STAGE,
  FLOW_ITEM_STEP,
  ROLLOUT_STAGE_STEP_TYPE,
  STEP_ACTION_CATEGORIES,
  STEP_FINISHED_STATES,
  STAGE_FALLBACK_TITLE,
} from './constants';

const TYPE_NAMESPACE = 'com.gitlab.cd.';
const IMPLIED_PROVIDERS = ['argo', 'steps'];

const isStageStep = (rolloutStep) => rolloutStep.stepType === ROLLOUT_STAGE_STEP_TYPE;

const stepAction = (stepType = '') => stepType.split('.').at(-1);

const stepCategory = (rolloutStep) =>
  STEP_ACTION_CATEGORIES[stepAction(rolloutStep.stepType)] ?? null;

const stepWeight = (rolloutStep) => {
  const weights = new Set(
    (rolloutStep.params?.services ?? [])
      .map((service) => service.weight)
      .filter((weight) => weight != null),
  );

  return weights.size === 1 ? [...weights][0] : null;
};

const stepQualifier = (rolloutStep) => {
  const weight = stepWeight(rolloutStep);

  if (weight != null) {
    return `${weight}%`;
  }

  const { seconds } = rolloutStep.params ?? {};

  return seconds == null ? null : humanizeTimeInterval(seconds, { abbreviated: true });
};

const typeWords = (stepType = '') => {
  const [provider, ...rest] = stepType.replace(TYPE_NAMESPACE, '').split('.');

  return IMPLIED_PROVIDERS.includes(provider) && rest.length ? rest : [provider, ...rest];
};

const stepTitle = (rolloutStep) => {
  if (rolloutStep.name) {
    return rolloutStep.name;
  }

  const qualifier = stepQualifier(rolloutStep);
  const words = typeWords(rolloutStep.stepType);
  const label = qualifier && words.length > 1 ? words.slice(0, -1) : words;

  return [humanize(label.join(' ')), qualifier].filter(Boolean).join(' ');
};

const toStep = (rolloutStep) => ({
  category: stepCategory(rolloutStep),
  state: rolloutStep.state,
  title: stepTitle(rolloutStep),
  subtitle: rolloutStep.environment?.name ?? '',
});

const environmentsCount = (rolloutSteps) =>
  new Set((rolloutSteps ?? []).map((step) => step.environment?.name).filter(Boolean)).size;

const toStage = (rolloutStep) => ({
  kind: FLOW_ITEM_STAGE,
  id: rolloutStep.id,
  title: rolloutStep.name || STAGE_FALLBACK_TITLE,
  state: rolloutStep.state,
  environmentsCount: environmentsCount(rolloutStep.steps),
  steps: (rolloutStep.steps ?? []).map(toStep),
});

const toBareStep = (rolloutStep) => ({
  kind: FLOW_ITEM_STEP,
  ...toStep(rolloutStep),
});

export const flowFromRolloutSteps = (rolloutSteps) =>
  (rolloutSteps ?? []).map((rolloutStep) =>
    isStageStep(rolloutStep) ? toStage(rolloutStep) : toBareStep(rolloutStep),
  );

const countableSteps = (rolloutSteps) =>
  (rolloutSteps ?? []).flatMap((rolloutStep) =>
    isStageStep(rolloutStep) ? (rolloutStep.steps ?? []) : [rolloutStep],
  );

export const rolloutProgress = (rolloutSteps) => {
  const steps = countableSteps(rolloutSteps);

  return {
    completed: steps.filter((step) => STEP_FINISHED_STATES.includes(step.state)).length,
    total: steps.length,
  };
};
