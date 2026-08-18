import { helpPagePath } from '~/helpers/help_page_helper';
import { __, s__ } from '~/locale';
import { PROMO_URL } from '~/constants';

export const GEO_INFO_URL = helpPagePath('administration/geo/_index.md');

export const HELP_SITE_HEALTH_URL = helpPagePath(
  'administration/geo/replication/troubleshooting/common.html',
  { anchor: 'check-the-health-of-the-geo-sites' },
);

export const GEO_TROUBLESHOOTING_URL = helpPagePath(
  'administration/geo/replication/troubleshooting/_index.md',
);

export const HELP_INFO_URL = helpPagePath(
  'administration/geo/disaster_recovery/background_verification.html',
  { anchor: 'repository-verification' },
);

export const REPLICATION_PAUSE_URL = helpPagePath('administration/geo/_index.html', {
  anchor: 'pausing-and-resuming-replication',
});

export const HEALTH_STATUS_UI = {
  healthy: {
    icon: 'status_success',
    variant: 'success',
    text: s__('Geo|Healthy'),
  },
  unhealthy: {
    icon: 'status_failed',
    variant: 'danger',
    text: s__('Geo|Unhealthy'),
  },
  disabled: {
    icon: 'status_canceled',
    variant: 'neutral',
    text: s__('Geo|Disabled'),
  },
  unknown: {
    icon: 'status_notfound',
    variant: 'neutral',
    text: s__('Geo|Unknown'),
  },
  offline: {
    icon: 'status_canceled',
    variant: 'neutral',
    text: s__('Geo|Offline'),
  },
};

export const REPLICATION_STATUS_UI = {
  enabled: {
    color: 'gl-text-success',
    text: __('Enabled'),
  },
  paused: {
    color: 'gl-text-warning',
    text: __('Paused'),
  },
  disabled: {
    color: 'gl-text-danger',
    text: __('Disabled'),
  },
};

export const DB_CONNECTION_TYPE_UI = {
  direct: {
    text: __('Direct'),
  },
  replicating: {
    text: s__('Geo|Replicating'),
  },
};

export const STATUS_DELAY_THRESHOLD_MS = 600000;

export const REMOVE_SITE_MODAL_ID = 'remove-site-modal';

export const STATUS_FILTER_QUERY_PARAM = 'status';

export const VIEW_ADMIN_GEO_SITES_PAGELOAD = 'view_admin_geo_sites_pageload';

export const GITLAB_PRICING_URL = `${PROMO_URL}/pricing/`;
