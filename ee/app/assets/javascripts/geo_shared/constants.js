import { s__ } from '~/locale';

const GEO_SHARED_STATUS_STATES = {
  PENDING: {
    title: s__('Geo|Pending'),
    value: 'PENDING',
    variant: 'warning',
    icon: 'status-scheduled',
  },
  STARTED: {
    title: s__('Geo|Started'),
    value: 'STARTED',
    variant: 'info',
    icon: 'status-running',
  },
  FAILED: {
    title: s__('Geo|Failed'),
    value: 'FAILED',
    variant: 'danger',
    icon: 'status-failed',
  },
  UNKNOWN: {
    title: s__('Geo|Unknown'),
    value: null,
    variant: 'neutral',
    icon: 'status-neutral',
  },
};

export const REPLICATION_STATUS_STATES = {
  ...GEO_SHARED_STATUS_STATES,
  SYNCED: {
    title: s__('Geo|Synced'),
    value: 'SYNCED',
    variant: 'success',
    icon: 'status-success',
  },
};

export const VERIFICATION_STATUS_STATES = {
  ...GEO_SHARED_STATUS_STATES,
  SUCCEEDED: {
    title: s__('Geo|Succeeded'),
    value: 'SUCCEEDED',
    variant: 'success',
    icon: 'status-success',
  },
  DISABLED: {
    title: s__('Geo|Disabled'),
    value: 'DISABLED',
    variant: 'neutral',
    icon: 'status-canceled',
  },
};

export const ACTION_TYPES = {
  REVERIFY: 'REVERIFY',
  RESYNC: 'RESYNC',
};

export const REPLICATION_STATUS_LABELS = {
  PENDING: s__('Geo|Sync pending'),
  STARTED: s__('Geo|Syncing'),
  SYNCED: s__('Geo|Synced'),
  FAILED: s__('Geo|Sync failed'),
  UNKNOWN: s__('Geo|Sync unknown'),
};

export const VERIFICATION_STATUS_LABELS = {
  PENDING: s__('Geo|Verification pending'),
  STARTED: s__('Geo|Verifying'),
  SUCCEEDED: s__('Geo|Verified'),
  FAILED: s__('Geo|Verification failed'),
  DISABLED: s__('Geo|Verification disabled'),
  UNKNOWN: s__('Geo|Verification unknown'),
};

export const SORT_DIRECTION = {
  ASC: 'asc',
  DESC: 'desc',
};
