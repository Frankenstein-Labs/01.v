import { AGENT_STEP_PILL_VARIANTS } from './constants';

export const getVariantColor = (variant) =>
  AGENT_STEP_PILL_VARIANTS[variant] ?? AGENT_STEP_PILL_VARIANTS.neutral;
