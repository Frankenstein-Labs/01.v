import { s__, sprintf } from '~/locale';
import { DUO_CHAT_AGENT_GITLAB_DUO } from 'ee/ai/constants';

export const buildWorkPlanPrompt = (workItemUrl) =>
  sprintf(
    s__(
      `AgentPlan|You are here to help refine a plan for the user from the Work Item context to a Markdown output with key information required for Agent to pick off the work. This plan is for the work item %{workItemUrl}. Use this exact work item as your context, regardless of any other panels or items visible in the UI. The template should have a Why, How, What format with key insights and list of steps. If the issue is lacking details, start by reading the comments. Then, ask clarifying questions to the users in Chat until you are confident. If there are pending questions, please preserve them inside the plan. Then, please proceed with updating the work item 'Workplan' widget with your output. You can erase everything was there before and add your new plan entirely. Don't preserve existing notes if they dont align with what you wrote. If there is enough information but the title or description is lacking, please propose to update it minimally with key insights. Try to preserve anything that is already present, just add on top and dont repeat the full plan. What is important is syncing up enough to preserve the intent and adding data where we had none before.`,
    ),
    { workItemUrl },
  );

export const buildWorkPlanChatCommand = (workItemUrl) => ({
  agent: { name: DUO_CHAT_AGENT_GITLAB_DUO },
  agenticPrompt: buildWorkPlanPrompt(workItemUrl),
});

// Extra goal context passed to the "Generate MR with Duo" action so the
// agent treats the saved workplan as the primary spec instead of starting
// from the work-item description.
export const WORKPLAN_GOAL_PREFIX =
  'The work item has an agent_plan widget containing a workplan authored for you. Treat that plan as the primary specification: define your tasks and approach from it, and only fall back to the description or comments for additional context when the plan is unclear.';

export const GENERATE_MR_BUTTON_OPTIONS = {
  size: 'medium',
  variant: 'confirm',
  category: 'primary',
};

export const PLAN_CONFIDENCE_LEVELS = {
  LOW: {
    value: 'LOW',
    barsToFill: 1,
    variant: 'error',
  },
  MEDIUM: {
    value: 'MEDIUM',
    barsToFill: 2,
    variant: 'warning',
  },
  HIGH: {
    value: 'HIGH',
    barsToFill: 3,
    variant: 'success',
  },
};

export const AGENT_STEP_PILL_VARIANTS = {
  error: 'var(--gl-status-danger-icon-color)',
  warning: 'var(--gl-status-warning-icon-color)',
  info: 'var(--gl-status-info-icon-color)',
  success: 'var(--gl-status-success-icon-color)',
  neutral: 'var(--gl-status-neutral-background-color)',
};

export const CONFIDENCE_SCORE_BAR_COUNT = 3;

export const CONFIDENCE_SCORE_MEDIUM_THRESHOLD = 0.4;

export const CONFIDENCE_SCORE_HIGH_THRESHOLD = 0.8;
