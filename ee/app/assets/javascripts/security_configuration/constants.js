import { s__ } from '~/locale';
import {
  featureToMutationMap as featureToMutationMapCE,
  SCAN_PROFILE_SCANNER_HEALTH_ACTIVE,
  SCAN_PROFILE_SCANNER_HEALTH_FAILED,
  SCAN_PROFILE_SCANNER_HEALTH_PENDING,
  SCAN_PROFILE_SCANNER_HEALTH_STALE,
  SCAN_PROFILE_SCANNER_HEALTH_UNCONFIGURED,
  SCAN_PROFILE_SCANNER_HEALTH_WARNING,
} from '~/security_configuration/constants';
import {
  REPORT_TYPE_DEPENDENCY_SCANNING,
  REPORT_TYPE_CONTAINER_SCANNING,
} from '~/vue_shared/security_reports/constants';
import configureDependencyScanningMutation from './graphql/configure_dependency_scanning.mutation.graphql';
import configureContainerScanningMutation from './graphql/configure_container_scanning.mutation.graphql';

export { FEATURE_DISABLED_TOOLTIP } from '~/security_configuration/constants';

export const SMALL = 'SMALL';
export const MEDIUM = 'MEDIUM';
export const LARGE = 'LARGE';

// The backend will supply sizes matching the keys of this map; the values
// correspond to values acceptable to the underlying components' size props.
export const SCHEMA_TO_PROP_SIZE_MAP = {
  [SMALL]: 'xs',
  [MEDIUM]: 'md',
  [LARGE]: 'xl',
};

export const CUSTOM_VALUE_MESSAGE = s__(
  "SecurityConfiguration|Using custom settings. You won't receive automatic updates on this variable. %{anchorStart}Restore to default%{anchorEnd}",
);

export const featureToMutationMap = {
  ...featureToMutationMapCE,
  [REPORT_TYPE_DEPENDENCY_SCANNING]: {
    mutationId: 'configureDependencyScanning',
    getMutationPayload: (projectPath) => ({
      mutation: configureDependencyScanningMutation,
      variables: {
        input: {
          projectPath,
        },
      },
    }),
  },
  [REPORT_TYPE_CONTAINER_SCANNING]: {
    mutationId: 'configureContainerScanning',
    getMutationPayload: (projectPath) => ({
      mutation: configureContainerScanningMutation,
      variables: {
        input: {
          projectPath,
        },
      },
    }),
  },
};

export const CONFIGURATION_SNIPPET_MODAL_ID = 'CONFIGURATION_SNIPPET_MODAL_ID';

export const ANALYZER_STATUSES_NOT_CONFIGURED = 'not_configured';
export const ANALYZER_STATUSES_SUCCESS = 'success';
export const ANALYZER_STATUSES_FAILED = 'failed';
export const ANALYZER_STATUSES_STALE = 'stale';

export const GROUP_STATUS_ENABLED = 'enabled';
export const GROUP_STATUS_NOT_ENABLED = 'not_enabled';
export const GROUP_STATUS_PENDING = 'pending';
export const GROUP_STATUS_WARNING = 'warning';
export const GROUP_STATUS_STALE = 'stale';
export const GROUP_STATUS_FAILED = 'failed';

export const GROUP_STATUSES_LABELS = {
  [GROUP_STATUS_ENABLED]: s__('SecurityConfiguration|Enabled'),
  [GROUP_STATUS_NOT_ENABLED]: s__('SecurityConfiguration|Not enabled'),
  [GROUP_STATUS_PENDING]: s__('SecurityConfiguration|Pending'),
  [GROUP_STATUS_WARNING]: s__('SecurityConfiguration|Warning'),
  [GROUP_STATUS_FAILED]: s__('SecurityConfiguration|Failed'),
  [GROUP_STATUS_STALE]: s__('SecurityConfiguration|Stale'),
};

export const STATUS_NORMALIZATION_MAP = {
  [SCAN_PROFILE_SCANNER_HEALTH_ACTIVE]: GROUP_STATUS_ENABLED,
  [ANALYZER_STATUSES_SUCCESS]: GROUP_STATUS_ENABLED,
  [SCAN_PROFILE_SCANNER_HEALTH_PENDING]: GROUP_STATUS_PENDING,
  [SCAN_PROFILE_SCANNER_HEALTH_UNCONFIGURED]: GROUP_STATUS_NOT_ENABLED,
  [ANALYZER_STATUSES_NOT_CONFIGURED]: GROUP_STATUS_NOT_ENABLED,
  [ANALYZER_STATUSES_FAILED]: GROUP_STATUS_FAILED,
  [SCAN_PROFILE_SCANNER_HEALTH_FAILED]: GROUP_STATUS_FAILED,
  [ANALYZER_STATUSES_STALE]: GROUP_STATUS_STALE,
  [SCAN_PROFILE_SCANNER_HEALTH_STALE]: GROUP_STATUS_STALE,
  [SCAN_PROFILE_SCANNER_HEALTH_WARNING]: GROUP_STATUS_WARNING,
};
