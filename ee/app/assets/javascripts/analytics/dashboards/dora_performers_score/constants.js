import { GREEN_400, ORANGE_400, RED_400, GRAY_400 } from '@gitlab/ui/src/tokens/build/js/tokens';
import { s__, n__, sprintf } from '~/locale';

export const DORA_PERFORMERS_SCORE_CATEGORY_TYPES = {
  HIGH: 'highProjectsCount',
  MEDIUM: 'mediumProjectsCount',
  LOW: 'lowProjectsCount',
  NO_DATA: 'noDataProjectsCount',
};

export const DORA_PERFORMERS_SCORE_CATEGORIES = {
  [DORA_PERFORMERS_SCORE_CATEGORY_TYPES.HIGH]: s__('DORA4Metrics|High'),
  [DORA_PERFORMERS_SCORE_CATEGORY_TYPES.MEDIUM]: s__('DORA4Metrics|Medium'),
  [DORA_PERFORMERS_SCORE_CATEGORY_TYPES.LOW]: s__('DORA4Metrics|Low'),
  [DORA_PERFORMERS_SCORE_CATEGORY_TYPES.NO_DATA]: s__('DORA4Metrics|Not included'),
};

export const DORA_PERFORMERS_SCORE_METRICS = [
  // score definitions are listed in order from 'High' to 'Low' and accessed using the series index
  {
    label: s__('DORA4Metrics|Deployment frequency (Velocity)'),
    scoreDefinitions: [
      s__('DORA4Metrics|Have 30 or more deploys to production per day.'),
      s__('DORA4Metrics|Have between 1 to 29 deploys to production per day.'),
      s__('DORA4Metrics|Have less than 1 deploy to production per day.'),
    ],
  },
  {
    label: s__('DORA4Metrics|Lead time for changes (Velocity)'),
    scoreDefinitions: [
      s__(
        'DORA4Metrics|Took 7 days or less to go from code committed to code successfully running in production.',
      ),
      s__(
        'DORA4Metrics|Took between 8 to 29 days to go from code committed to code successfully running in production.',
      ),
      s__(
        'DORA4Metrics|Took more than 30 days to go from code committed to code successfully running in production.',
      ),
    ],
  },
  {
    label: s__('DORA4Metrics|Time to restore service (Quality)'),
    scoreDefinitions: [
      s__(
        'DORA4Metrics|Took 1 day or less to restore service when a service incident or a defect that impacts users occurs.',
      ),
      s__(
        'DORA4Metrics|Took between 2 to 6 days to restore service when a service incident or a defect that impacts users occurs.',
      ),
      s__(
        'DORA4Metrics|Took more than 7 days to restore service when a service incident or a defect that impacts users occurs.',
      ),
    ],
  },
  {
    label: s__('DORA4Metrics|Change failure rate (Quality)'),
    scoreDefinitions: [
      sprintf(
        s__('DORA4Metrics|Made 15%% or less changes to production resulted in degraded service.'),
      ),
      sprintf(
        s__(
          'DORA4Metrics|Made between 16%% to 44%% of changes to production resulted in degraded service.',
        ),
      ),
      sprintf(
        s__(
          'DORA4Metrics|Made more than 45%% of changes to production resulted in degraded service.',
        ),
      ),
    ],
  },
];

export const DORA_PERFORMERS_SCORE_PANEL_TITLE_WITH_PROJECTS_COUNT = s__(
  'DORA4Metrics|Total projects (%{count}) with DORA metrics',
);

export const DORA_PERFORMERS_SCORE_TOOLTIP_PROJECTS_COUNT_TITLE = (count) =>
  n__('DORA4Metrics|%d project', 'DORA4Metrics|%d projects', count);

export const DORA_PERFORMERS_SCORE_NOT_INCLUDED = (count) =>
  n__('DORA4Metrics|Has no calculated data.', 'DORA4Metrics|Have no calculated data.', count);

export const DORA_PERFORMERS_SCORE_LOADING_ERROR = s__(
  'DORA4Metrics|Failed to load DORA performance scores for Group: %{fullPath}',
);

export const DORA_PERFORMERS_SCORE_CHART_COLOR_PALETTE = [GREEN_400, ORANGE_400, RED_400, GRAY_400];
