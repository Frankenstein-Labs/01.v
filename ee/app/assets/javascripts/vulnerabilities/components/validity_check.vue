<script>
import { GlButton, GlTooltip } from '@gitlab/ui';
import { InternalEvents } from '~/tracking';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import { TYPENAME_VULNERABILITY } from '~/graphql_shared/constants';
import TokenValidityBadge from 'ee/vue_shared/security_reports/components/token_validity_badge.vue';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import refreshSecurityFindingTokenStatusMutation from 'ee/security_dashboard/graphql/mutations/refresh_security_finding_token_status.mutation.graphql';
import { FINDING_MODAL_ERROR_CONTAINER_ID } from 'ee/security_dashboard/constants';
import refreshFindingTokenStatusMutation from '../graphql/mutations/refresh_finding_token_status.mutation.graphql';

export default {
  name: 'ValidityCheck',
  components: {
    GlButton,
    TimeAgoTooltip,
    TokenValidityBadge,
    GlTooltip,
  },
  mixins: [glFeatureFlagMixin(), InternalEvents.mixin()],
  props: {
    findingTokenStatus: {
      type: Object,
      required: false,
      default: null,
    },
    vulnerabilityId: {
      type: Number,
      required: false,
      default: null,
    },
    securityFindingUuid: {
      type: String,
      required: false,
      default: null,
    },
    /** Turn off where the surrounding layout explains the validity check itself. */
    showHelpPopover: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  data() {
    return {
      isLoading: false,
      latestVerifiedAt: null,
      latestStatus: null,
    };
  },
  computed: {
    lastVerifiedAt() {
      return this.latestVerifiedAt || this.findingTokenStatus?.lastVerifiedAt;
    },
    tokenValidityStatus() {
      return this.latestStatus || this.findingTokenStatus?.status || 'unknown';
    },
    isVulnerabilityDetailsPage() {
      return Boolean(this.vulnerabilityId);
    },
    parentPageType() {
      return this.isVulnerabilityDetailsPage ? 'VulnerabilityDetails' : 'SecurityDashboard';
    },
    mutation() {
      if (this.isVulnerabilityDetailsPage) {
        return refreshFindingTokenStatusMutation;
      }

      return refreshSecurityFindingTokenStatusMutation;
    },
    mutationVariables() {
      if (this.isVulnerabilityDetailsPage) {
        return {
          vulnerabilityId: convertToGraphQLId(TYPENAME_VULNERABILITY, this.vulnerabilityId),
        };
      }
      return { securityFindingUuid: this.securityFindingUuid };
    },
    responseKey() {
      return this.isVulnerabilityDetailsPage
        ? 'refreshFindingTokenStatus'
        : 'refreshSecurityFindingTokenStatus';
    },
  },
  methods: {
    async refreshValidityCheck() {
      this.isLoading = true;

      try {
        this.trackEvent('click_refresh_token_status_button', {
          label: this.parentPageType,
        });
        const { data } = await this.$apollo.mutate({
          mutation: this.mutation,
          variables: this.mutationVariables,
        });

        const { errors, findingTokenStatus } = data?.[this.responseKey] || {};

        if (errors?.length) {
          throw new Error(errors.join('. '));
        } else if (findingTokenStatus) {
          const { lastVerifiedAt, status } = findingTokenStatus;

          this.latestVerifiedAt = lastVerifiedAt;
          this.latestStatus = status;
        }
      } catch (error) {
        this.createErrorAlert(error);
      } finally {
        this.isLoading = false;
      }
    },
    createErrorAlert(error) {
      const message = error.message || error.response?.data?.message;
      const defaultMessage = s__(
        'VulnerabilityManagement|Could not refresh the validity check. Please try again.',
      );

      const alertOptions = {
        message: message || defaultMessage,
        captureError: true,
        error,
      };

      if (!this.isVulnerabilityDetailsPage) {
        alertOptions.containerSelector = `#${FINDING_MODAL_ERROR_CONTAINER_ID}`;
      }

      createAlert(alertOptions);
    },
  },
};
</script>

<template>
  <span>
    <token-validity-badge :status="tokenValidityStatus" :show-help-popover="showHelpPopover" />
    <div class="gl-mt-4 gl-text-sm">
      <span class="gl-mr-2" data-testid="validity-last-checked">
        {{ s__('VulnerabilityManagement|Last checked:') }}
        <span class="gl-inline-block gl-min-w-[5.2rem]">
          <template v-if="lastVerifiedAt"><time-ago-tooltip :time="lastVerifiedAt" /></template>
          <template v-else> {{ s__('VulnerabilityManagement|No data available') }}</template>
        </span>
      </span>
      <gl-button
        id="vulnerability-validity-check-button"
        :disabled="!mutation"
        :loading="isLoading"
        category="tertiary"
        size="small"
        icon="retry"
        :aria-label="s__('VulnerabilityManagement|Recheck')"
        @click="refreshValidityCheck"
      />
      <gl-tooltip
        v-if="!isLoading"
        target="vulnerability-validity-check-button"
        placement="top"
        triggers="hover focus"
      >
        {{ s__('VulnerabilityManagement|Recheck') }}
      </gl-tooltip>
    </div>
  </span>
</template>
