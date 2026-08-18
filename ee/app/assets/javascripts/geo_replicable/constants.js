import { GlFilteredSearchToken } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { SORT_DIRECTION } from 'ee/geo_shared/constants';
import { OPERATORS_IS } from '~/vue_shared/components/filtered_search_bar/constants';

export const FILTER_STATES = {
  ALL: {
    label: __('All'),
    value: '',
  },
  STARTED: {
    label: __('Started'),
    value: 'started',
  },
  PENDING: {
    label: __('In progress'),
    value: 'pending',
  },
  SYNCED: {
    label: __('Synced'),
    value: 'synced',
  },
  FAILED: {
    label: __('Failed'),
    value: 'failed',
  },
};

export const FILTER_OPTIONS = Object.values(FILTER_STATES);

export const DEFAULT_STATUS = 'never';

export const STATUS_ICON_NAMES = {
  [FILTER_STATES.STARTED.value]: 'clock',
  [FILTER_STATES.SYNCED.value]: 'check-circle-filled',
  [FILTER_STATES.PENDING.value]: 'status_pending',
  [FILTER_STATES.FAILED.value]: 'status_failed',
  [DEFAULT_STATUS]: 'status_notfound',
};

export const STATUS_ICON_CLASS = {
  [FILTER_STATES.STARTED.value]: 'gl-text-warning',
  [FILTER_STATES.SYNCED.value]: 'gl-text-success',
  [FILTER_STATES.PENDING.value]: 'gl-text-warning',
  [FILTER_STATES.FAILED.value]: 'gl-text-danger',
  [DEFAULT_STATUS]: 'gl-text-subtle',
};

export const DEFAULT_SEARCH_DELAY = 500;

export const ACTION_TYPES = {
  RESYNC: 'resync',
  REVERIFY: 'reverify',
  RESYNC_ALL: 'resync_all',
  RESYNC_ALL_FAILED: 'resync_all_failed',
  REVERIFY_ALL: 'reverify_all',
  REVERIFY_ALL_FAILED: 'reverify_all_failed',
};

export const PREV = 'prev';

export const NEXT = 'next';

export const DEFAULT_PAGE_SIZE = 20;

export const GEO_BULK_ACTION_MODAL_ID = 'geo-bulk-action';

export const GEO_TROUBLESHOOTING_LINK = helpPagePath(
  'administration/geo/replication/troubleshooting/_index.md',
);

export const GEO_SHARED_STATUS_STATES = {
  PENDING: {
    title: s__('Geo|Pending'),
    value: 'pending',
    order: 0,
  },
  STARTED: {
    title: s__('Geo|Started'),
    value: 'started',
    order: 1,
  },
  FAILED: {
    title: s__('Geo|Failed'),
    value: 'failed',
    order: 3,
  },
  UNKNOWN: {
    title: s__('Geo|Unknown'),
    value: null,
    order: 5,
  },
};

export const REPLICATION_STATUS_STATES = {
  ...GEO_SHARED_STATUS_STATES,
  SYNCED: {
    title: s__('Geo|Synced'),
    value: 'synced',
    order: 2,
  },
};

export const VERIFICATION_STATUS_STATES = {
  ...GEO_SHARED_STATUS_STATES,
  SUCCEEDED: {
    title: s__('Geo|Succeeded'),
    value: 'succeeded',
    order: 2,
  },
  DISABLED: {
    title: s__('Geo|Disabled'),
    value: 'disabled',
    order: 4,
  },
};

export const REPLICATION_STATUS_STATES_ARRAY = Object.values(REPLICATION_STATUS_STATES).sort(
  (a, b) => a.order - b.order,
);

export const VERIFICATION_STATUS_STATES_ARRAY = Object.values(VERIFICATION_STATUS_STATES).sort(
  (a, b) => a.order - b.order,
);

export const TOKEN_TYPES = {
  REPLICABLE_TYPE: 'replicable_type',
  IDS: 'ids',
  REPLICATION_STATUS: 'replication_status',
  VERIFICATION_STATUS: 'verification_status',
};

export const FILTERED_SEARCH_TOKENS = [
  {
    title: s__('Geo|Replication status'),
    type: TOKEN_TYPES.REPLICATION_STATUS,
    icon: 'substitute',
    token: GlFilteredSearchToken,
    operators: OPERATORS_IS,
    unique: true,
    options: REPLICATION_STATUS_STATES_ARRAY,
  },
  {
    title: s__('Geo|Verification status'),
    type: TOKEN_TYPES.VERIFICATION_STATUS,
    icon: 'check-circle',
    token: GlFilteredSearchToken,
    operators: OPERATORS_IS,
    unique: true,
    options: VERIFICATION_STATUS_STATES_ARRAY,
  },
];

export const ADDITIONAL_RESYNC_BULK_ACTIONS = [
  {
    id: 'geo-bulk-action-resync-failed',
    action: ACTION_TYPES.RESYNC_ALL_FAILED,
    text: s__('Geo|Resync all failed'),
    modal: {
      title: s__('Geo|Resync all failed %{type}'),
      description: s__(
        'Geo|This will schedule a future job to retry the synchronization process for all %{type} that have a failed replication status. It may take some time to complete. Are you sure you want to continue?',
      ),
      helpLink: {
        text: s__('Geo|Learn more about manual resynchronization'),
        href: helpPagePath(
          'administration/geo/replication/troubleshooting/synchronization_verification',
          { anchor: 'manually-retry-replication-or-verification' },
        ),
      },
    },
    successMessage: s__(
      'Geo|Scheduled all %{replicableType} with a failed replication status for resynchronization.',
    ),
    errorMessage: s__(
      'Geo|There was an error scheduling all %{replicableType} with a failed replication status for resynchronization.',
    ),
  },
];

export const ADDITIONAL_REVERIFY_BULK_ACTIONS = [
  {
    id: 'geo-bulk-action-reverify-failed',
    action: ACTION_TYPES.REVERIFY_ALL_FAILED,
    text: s__('Geo|Reverify all failed'),
    modal: {
      title: s__('Geo|Reverify all failed %{type}'),
      description: s__(
        'Geo|This will schedule a future job to retry the secondary verification process for all %{type} that have a failed verification status. It may take some time to complete. Are you sure you want to continue?',
      ),
      helpLink: {
        text: s__('Geo|Learn more about manual reverification'),
        href: helpPagePath(
          'administration/geo/replication/troubleshooting/synchronization_verification',
          { anchor: 'manually-retry-replication-or-verification' },
        ),
      },
    },
    successMessage: s__(
      'Geo|Scheduled all %{replicableType} with a failed verification status for reverification.',
    ),
    errorMessage: s__(
      'Geo|There was an error scheduling all %{replicableType} with a failed verification status for reverification.',
    ),
  },
];

export const BULK_ACTIONS = [
  {
    id: 'geo-bulk-action-resync',
    action: ACTION_TYPES.RESYNC_ALL,
    text: s__('Geo|Resync all'),
    icon: 'retry',
    modal: {
      title: s__('Geo|Resync all %{type}'),
      description: s__(
        'Geo|This will schedule a future job to retry the synchronization process for all %{type}. It may take some time to complete. Are you sure you want to continue?',
      ),
      helpLink: {
        text: s__('Geo|Learn more about manual resynchronization'),
        href: helpPagePath(
          'administration/geo/replication/troubleshooting/synchronization_verification',
          { anchor: 'manually-retry-replication-or-verification' },
        ),
      },
    },
    successMessage: s__('Geo|Scheduled all %{replicableType} for resynchronization.'),
    errorMessage: s__(
      'Geo|There was an error scheduling all %{replicableType} for resynchronization.',
    ),
    additionalActions: ADDITIONAL_RESYNC_BULK_ACTIONS,
  },
  {
    id: 'geo-bulk-action-reverify',
    action: ACTION_TYPES.REVERIFY_ALL,
    text: s__('Geo|Reverify all'),
    modal: {
      title: s__('Geo|Reverify all %{type}'),
      description: s__(
        'Geo|This will schedule a future job to retry the secondary verification process for all %{type}. It may take some time to complete. Are you sure you want to continue?',
      ),
      helpLink: {
        text: s__('Geo|Learn more about manual reverification'),
        href: helpPagePath(
          'administration/geo/replication/troubleshooting/synchronization_verification',
          { anchor: 'manually-retry-replication-or-verification' },
        ),
      },
    },
    successMessage: s__('Geo|Scheduled all %{replicableType} for reverification.'),
    errorMessage: s__(
      'Geo|There was an error scheduling all %{replicableType} for reverification.',
    ),
    additionalActions: ADDITIONAL_REVERIFY_BULK_ACTIONS,
  },
];

export const DEFAULT_CURSOR = {
  before: '',
  after: '',
  first: DEFAULT_PAGE_SIZE,
  last: null,
};

export const SORT_OPTIONS = {
  ID: {
    text: s__('Geo|Registry ID'),
    value: 'id',
  },
  LAST_SYNCED_AT: {
    text: s__('Geo|Last synced at'),
    value: 'last_synced_at',
  },
  LAST_VERIFIED_AT: {
    text: s__('Geo|Last verified at'),
    value: 'verified_at',
  },
};

export const DEFAULT_SORT = {
  value: SORT_OPTIONS.ID.value,
  direction: SORT_DIRECTION.ASC,
};

export const SORT_OPTIONS_ARRAY = Object.values(SORT_OPTIONS);
