<script>
import { GlIcon } from '@gitlab/ui';
import {
  SCAN_PROFILE_SCANNER_HEALTH_ACTIVE,
  SCAN_PROFILE_SCANNER_HEALTH_FAILED,
  SCAN_PROFILE_SCANNER_HEALTH_PENDING,
  SCAN_PROFILE_SCANNER_HEALTH_STALE,
  SCAN_PROFILE_SCANNER_HEALTH_UNCONFIGURED,
  SCAN_PROFILE_SCANNER_HEALTH_WARNING,
  SCAN_PROFILE_I18N,
} from '~/security_configuration/constants';
import { humanize } from '~/lib/utils/text_utility';
import { n__, s__, sprintf } from '~/locale';
import {
  GROUP_STATUS_ENABLED,
  GROUP_STATUS_FAILED,
  GROUP_STATUS_NOT_ENABLED,
  GROUP_STATUS_PENDING,
  GROUP_STATUSES_LABELS,
} from 'ee/security_configuration/constants';

const COMBINABLE_PROFILE_STATUSES = [GROUP_STATUS_ENABLED, GROUP_STATUS_PENDING];

const STATUS_ICONS = {
  [SCAN_PROFILE_SCANNER_HEALTH_PENDING]: 'status-waiting',
  [SCAN_PROFILE_SCANNER_HEALTH_UNCONFIGURED]: 'clear',
  [GROUP_STATUS_NOT_ENABLED]: 'clear',
  [SCAN_PROFILE_SCANNER_HEALTH_ACTIVE]: 'status-success',
  [GROUP_STATUS_ENABLED]: 'status-success',
  [SCAN_PROFILE_SCANNER_HEALTH_WARNING]: 'status_warning',
  [SCAN_PROFILE_SCANNER_HEALTH_FAILED]: 'status-failed',
  [SCAN_PROFILE_SCANNER_HEALTH_STALE]: 'status-scheduled',
};

const STATUS_ICON_CLASSES = {
  [SCAN_PROFILE_SCANNER_HEALTH_PENDING]: 'gl-text-subtle',
  [SCAN_PROFILE_SCANNER_HEALTH_UNCONFIGURED]: 'gl-text-subtle',
  [GROUP_STATUS_NOT_ENABLED]: 'gl-text-subtle',
  [SCAN_PROFILE_SCANNER_HEALTH_ACTIVE]: 'gl-text-success',
  [GROUP_STATUS_ENABLED]: 'gl-text-success',
  [SCAN_PROFILE_SCANNER_HEALTH_WARNING]: 'gl-text-warning',
  [SCAN_PROFILE_SCANNER_HEALTH_FAILED]: 'gl-text-danger',
  [SCAN_PROFILE_SCANNER_HEALTH_STALE]: 'gl-text-subtle',
};

export default {
  name: 'ScannerStatusIcon',
  components: { GlIcon },
  props: {
    status: {
      type: String,
      required: true,
    },
    profileStatus: {
      type: String,
      required: false,
      default: '',
    },
    consecutiveSuccessCount: {
      type: Number,
      required: false,
      default: 0,
    },
    consecutiveFailureCount: {
      type: Number,
      required: false,
      default: 0,
    },
  },
  computed: {
    iconName() {
      return STATUS_ICONS[this.status?.toLowerCase()] || 'status_failed';
    },
    iconClass() {
      return STATUS_ICON_CLASSES[this.status?.toLowerCase()] || 'gl-text-subtle';
    },
    scannerStatus() {
      if (!this.status) return '';
      // Surface both facts when an analyzer failure is layered on top of an
      // enabled/pending profile: enablement is what we intended, failure is
      // what actually happened. Both belong in the label. Other profile
      // statuses (warning, failed, stale) already convey a scan concern, so
      // combining them with "last scan failed" would read as redundant.
      if (
        this.status === GROUP_STATUS_FAILED &&
        COMBINABLE_PROFILE_STATUSES.includes(this.profileStatus)
      ) {
        const profileLabel =
          GROUP_STATUSES_LABELS[this.profileStatus] ?? humanize(this.profileStatus);
        return sprintf(s__('SecurityConfiguration|%{profileLabel}, last scan failed'), {
          profileLabel,
        });
      }
      return GROUP_STATUSES_LABELS[this.status] ?? humanize(this.status);
    },
    scannerStatusDetail() {
      switch (this.status) {
        case SCAN_PROFILE_SCANNER_HEALTH_PENDING:
          return SCAN_PROFILE_I18N.awaitingFirstPipeline;
        case SCAN_PROFILE_SCANNER_HEALTH_UNCONFIGURED:
        case GROUP_STATUS_NOT_ENABLED:
          return SCAN_PROFILE_I18N.applyToEnable;
        case SCAN_PROFILE_SCANNER_HEALTH_ACTIVE:
        case GROUP_STATUS_ENABLED:
          if (!this.consecutiveSuccessCount) return '';
          return n__(
            'SecurityProfiles|Last %d scan successful',
            'SecurityProfiles|Last %d scans successful',
            this.consecutiveSuccessCount,
          );
        case SCAN_PROFILE_SCANNER_HEALTH_WARNING:
        case SCAN_PROFILE_SCANNER_HEALTH_FAILED:
          if (!this.consecutiveFailureCount) return '';
          return n__(
            'SecurityProfiles|Last %d scan failed',
            'SecurityProfiles|Last %d scans failed',
            this.consecutiveFailureCount,
          );
        case SCAN_PROFILE_SCANNER_HEALTH_STALE:
          return SCAN_PROFILE_I18N.coverageMayBeOutdated;
        default:
          return '';
      }
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-items-center">
    <gl-icon
      class="gl-self-start"
      :name="iconName"
      :class="[
        iconClass,
        {
          'gl-mr-3': scannerStatusDetail,
          'gl-mr-2': !scannerStatusDetail,
        },
      ]"
    />
    <div class="gl-flex gl-flex-col">
      <span class="gl-font-weight-bold" data-testid="scanner-status">
        {{ scannerStatus }}
      </span>
      <span class="gl-mt-1 gl-text-sm gl-text-subtle" data-testid="scanner-status-details">
        {{ scannerStatusDetail }}
      </span>
    </div>
  </div>
</template>
