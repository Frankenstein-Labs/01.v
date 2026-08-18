<script>
import { GlAlert } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { __, s__ } from '~/locale';
import { joinPaths } from '~/lib/utils/url_utility';
import {
  HTTP_STATUS_UNAUTHORIZED,
  HTTP_STATUS_FORBIDDEN,
  HTTP_STATUS_NOT_FOUND,
} from '~/lib/utils/http_status';
// TODO: Replace the evaluations mock once the Policy Store exposes evaluation
// stats. Tracked in https://gitlab.com/gitlab-org/gitlab/-/work_items/604312
import { MOCK_EVALUATIONS_THIS_WEEK } from '../../mock_data';
import { fetchPolicies } from '../../policies';
import ListWrapper from './list_wrapper.vue';

// Expected when the viewer lacks read_govern_policy on the organization; the page
// itself is gated by a group-level ability, so the two can legitimately disagree.
const PERMISSION_STATUSES = [
  HTTP_STATUS_UNAUTHORIZED,
  HTTP_STATUS_FORBIDDEN,
  HTTP_STATUS_NOT_FOUND,
];

export default {
  name: 'PolicyStoreListRoot',
  components: {
    GlAlert,
    ListWrapper,
  },
  MOCK_EVALUATIONS_THIS_WEEK,
  i18n: {
    policiesError: s__('PolicyStore|The policies could not be fetched from the Policy Store API.'),
    retry: __('Retry'),
    policiesPermissionError: s__(
      'PolicyStore|You do not have permission to view the policies of this organization.',
    ),
  },
  // The per-policy detail path is derived from listPath and the policy id until the API exposes it.
  inject: {
    organizationId: {},
    newPolicyPath: { default: '' },
    listPath: { default: '' },
  },
  data() {
    return {
      policies: [],
      policiesLoading: false,
      policiesError: false,
      policiesErrorPermission: false,
    };
  },
  computed: {
    listPolicies() {
      return this.policies.map((policy) => ({
        ...policy,
        detailPath: this.listPath ? joinPaths(this.listPath, String(policy.id)) : '',
      }));
    },
    policiesErrorMessage() {
      return this.policiesErrorPermission
        ? this.$options.i18n.policiesPermissionError
        : this.$options.i18n.policiesError;
    },
    // Retrying cannot fix missing permissions, so the button only shows for
    // failures that might be transient.
    policiesErrorRetryText() {
      return this.policiesErrorPermission ? null : this.$options.i18n.retry;
    },
  },
  created() {
    this.loadPolicies();
  },
  methods: {
    async loadPolicies() {
      this.policiesLoading = true;
      this.policiesError = false;
      this.policiesErrorPermission = false;

      try {
        this.policies = await fetchPolicies(this.organizationId);
      } catch (error) {
        this.policiesErrorPermission = PERMISSION_STATUSES.includes(error?.response?.status);

        if (!this.policiesErrorPermission) {
          Sentry.captureException(error);
        }

        this.policies = [];
        this.policiesError = true;
      } finally {
        this.policiesLoading = false;
      }
    },
  },
};
</script>

<template>
  <div>
    <!-- eslint-disable vue/v-on-event-hyphenation -- GlAlert emits the camelCase `primaryAction` event, which must be matched exactly in Vue 2 compat mode -->
    <gl-alert
      v-if="policiesError"
      variant="danger"
      :dismissible="false"
      :primary-button-text="policiesErrorRetryText"
      class="gl-mt-4"
      data-testid="policies-error"
      @primaryAction="loadPolicies()"
    >
      {{ policiesErrorMessage }}
    </gl-alert>
    <!-- eslint-enable vue/v-on-event-hyphenation -->
    <list-wrapper
      :policies="listPolicies"
      :loading="policiesLoading"
      :error="policiesError"
      :evaluations-this-week="$options.MOCK_EVALUATIONS_THIS_WEEK"
      :new-policy-path="newPolicyPath"
    />
  </div>
</template>
