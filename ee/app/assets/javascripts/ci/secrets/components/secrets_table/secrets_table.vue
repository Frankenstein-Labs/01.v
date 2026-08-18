<script>
import {
  GlBadge,
  GlButton,
  GlIcon,
  GlLabel,
  GlLoadingIcon,
  GlLink,
  GlTableLite,
  GlTooltipDirective,
} from '@gitlab/ui';
import { InternalEvents } from '~/tracking';
import { helpPagePath } from '~/helpers/help_page_helper';
import { __ } from '~/locale';
import { fetchPolicies } from '~/lib/graphql';
import { createAlert } from '~/alert';
import { formatGraphQLError } from 'ee/ci/secrets/utils';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import UserDate from '~/vue_shared/components/user_date.vue';
import { convertEnvironmentScope } from '~/ci/common/private/ci_environments_dropdown';
import {
  ALL_BRANCHES_OPTION,
  ALL_BRANCHES_TOGGLE_TEXT,
  DETAILS_ROUTE_NAME,
  EDIT_ROUTE_NAME,
  ENTITLEMENT_STATE_TRIAL_ELIGIBLE,
  NEW_ROUTE_NAME,
  PAGE_VISIT_SECRETS_TABLE,
  SCOPED_LABEL_COLOR,
  SECRET_MANAGER_STATUS_ACTIVE,
  SECRET_ROTATION_STATUS,
  SECRET_STATUS,
  SECRET_STATUS_ICONS_OPTICALLY_ALIGNED,
} from 'ee/ci/secrets/constants';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import SecretDeleteModal from '../secret_delete_modal.vue';
import SecretsEmptyState from '../secrets_empty_state.vue';
import SecretsTrialEmptyState from './secrets_trial_empty_state.vue';
import ActionsCell from './secret_actions_cell.vue';
import SecretsAlertBanner from './secrets_alert_banner.vue';

export default {
  name: 'SecretsTable',
  components: {
    ActionsCell,
    CrudComponent,
    SecretsEmptyState,
    SecretsTrialEmptyState,
    GlBadge,
    GlButton,
    GlIcon,
    GlLabel,
    GlLoadingIcon,
    GlLink,
    GlTableLite,
    SecretDeleteModal,
    SecretsAlertBanner,
    UserDate,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [InternalEvents.mixin(), glListenersMixin],
  inject: [
    'contextConfig',
    'entitlement',
    'fullPath',
    'isOpenbaoHealthy',
    'isReadOnly',
    'isTrialOnboarding',
    'secretManagerStatus',
  ],
  data() {
    return {
      secrets: [],
      secretsNeedingRotation: [],
      secretToDelete: '',
      showDeleteModal: false,
    };
  },
  apollo: {
    secrets: {
      query() {
        return this.contextConfig.getSecrets.query;
      },
      skip() {
        return !this.isOpenbaoHealthy || !this.isSecretsManagerActive;
      },
      variables() {
        return {
          fullPath: this.fullPath,
          first: this.contextConfig.getSecrets.first,
        };
      },
      update(data) {
        const { edges } = data.secretsList;
        return edges.map((e) => e.node) || [];
      },
      error(e) {
        createAlert({
          message: formatGraphQLError(e.message),
          captureError: true,
          error: e,
        });
      },
      fetchPolicy: fetchPolicies.NETWORK_ONLY,
    },
    secretsNeedingRotation: {
      query() {
        return this.contextConfig.getSecretsNeedingRotation.query;
      },
      skip() {
        return !this.isOpenbaoHealthy || !this.isSecretsManagerActive;
      },
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      update(data) {
        return data.secretsNeedingRotation?.nodes || [];
      },
      error(e) {
        createAlert({
          message: formatGraphQLError(e.message),
          captureError: true,
          error: e,
        });
      },
      fetchPolicy: fetchPolicies.NETWORK_ONLY,
    },
  },
  computed: {
    areActionsAllowed() {
      return this.isOpenbaoHealthy && !this.isReadOnly;
    },
    showRotationApproachingIcon() {
      return (rotationInfo) => rotationInfo?.status === SECRET_ROTATION_STATUS.approaching;
    },
    showRotationOverdueIcon() {
      return (rotationInfo) => rotationInfo?.status === SECRET_ROTATION_STATUS.overdue;
    },
    isLoading() {
      return this.isOpenbaoHealthy && this.$apollo.queries.secrets.loading;
    },
    isSecretsManagerActive() {
      return this.secretManagerStatus === SECRET_MANAGER_STATUS_ACTIVE;
    },
    isTrialEligible() {
      return this.entitlement?.state === ENTITLEMENT_STATE_TRIAL_ELIGIBLE;
    },
    showEmptyState() {
      return !this.isOpenbaoHealthy || this.secrets.length === 0;
    },
    tableFields() {
      const fields = [
        {
          key: 'name',
          label: __('Name'),
        },
        {
          key: 'createdAt',
          label: __('Created'),
        },
        {
          key: 'status',
          label: __('Status'),
        },
      ];

      if (this.areActionsAllowed) {
        fields.push({
          key: 'actions',
          label: '',
          tdClass: 'gl-text-right !gl-p-3',
        });
      }

      return fields;
    },
  },
  mounted() {
    const { eventTracking } = this.contextConfig;
    this.trackEvent(eventTracking.pageVisit, { label: PAGE_VISIT_SECRETS_TABLE });
  },
  methods: {
    branchesText(branch) {
      return branch === ALL_BRANCHES_OPTION.value ? ALL_BRANCHES_TOGGLE_TEXT : branch;
    },
    deleteSecret(secretName) {
      this.secretToDelete = secretName;
      this.showDeleteModal = true;
    },
    getDetailsRoute: (secretName) => ({ name: DETAILS_ROUTE_NAME, params: { secretName } }),
    getEditRoute: (secretName) => ({ name: EDIT_ROUTE_NAME, params: { secretName } }),
    environmentLabelText(environment) {
      const environmentText = convertEnvironmentScope(environment);
      return `${__('env')}::${environmentText}`;
    },
    hideModal() {
      this.secretToDelete = '';
      this.showDeleteModal = false;
    },
    refetchSecrets() {
      this.$apollo.queries.secrets.refetch();
      this.hideModal();
    },
  },
  LEARN_MORE_LINK: helpPagePath('ci/secrets/secrets_manager/_index'),
  NEW_ROUTE_NAME,
  OPEN_BETA_FEEDBACK_LINK: 'https://gitlab.com/gitlab-org/gitlab/-/work_items/598100',
  SCOPED_LABEL_COLOR,
  SECRET_STATUS,
  SECRET_STATUS_ICONS_OPTICALLY_ALIGNED,
};
</script>
<template>
  <div>
    <h1 class="page-title gl-text-size-h-display">
      {{ s__('SecretsManager|GitLab Secrets Manager') }}
    </h1>
    <p>
      {{
        s__(
          'SecretsManager|Secrets can be items like API tokens, database credentials, or private keys. Unlike CI/CD variables, secrets must be explicitly requested by a job.',
        )
      }}
    </p>
    <gl-loading-icon v-if="isLoading" size="lg" class="gl-mt-5" />
    <secrets-trial-empty-state
      v-else-if="(entitlement && isTrialEligible) || isTrialOnboarding"
      v-on="glListeners()"
    />
    <secrets-empty-state
      v-else-if="showEmptyState"
      :can-create-secret="areActionsAllowed"
      v-on="glListeners()"
    />
    <crud-component v-else :title="s__('SecretsManager|Stored secrets')">
      <secrets-alert-banner
        v-if="secretsNeedingRotation.length"
        :secrets-to-rotate="secretsNeedingRotation"
      />
      <template #actions>
        <gl-button
          v-if="areActionsAllowed"
          size="small"
          :to="$options.NEW_ROUTE_NAME"
          data-testid="new-secret-button"
        >
          {{ s__('SecretsManager|New secret') }}
        </gl-button>
      </template>
      <gl-table-lite :fields="tableFields" :items="secrets" stacked="md" class="gl-mb-0">
        <template
          #cell(name)="{
            item: { name, branch, protected: isProtected, environment, rotationInfo },
          }"
        >
          <div class="gl-block gl-pb-3">
            <router-link data-testid="secret-details-link" :to="getDetailsRoute(name)">
              {{ name }}
            </router-link>
            <gl-icon
              v-if="showRotationApproachingIcon(rotationInfo)"
              v-gl-tooltip
              :title="
                s__('SecretRotation|Rotation reminder: This secret needs to be updated soon.')
              "
              name="warning"
              variant="warning"
              data-testid="rotation-approaching-icon"
            />
            <gl-icon
              v-else-if="showRotationOverdueIcon(rotationInfo)"
              v-gl-tooltip
              :title="s__('SecretRotation|Rotation overdue')"
              name="warning-solid"
              variant="danger"
              data-testid="rotation-overdue-icon"
            />
          </div>
          <div class="gl-flex gl-flex-wrap gl-items-center gl-gap-2">
            <gl-label
              :title="environmentLabelText(environment)"
              :background-color="$options.SCOPED_LABEL_COLOR"
              data-testid="secret-environments"
              scoped
            />
            <code v-if="branch">
              <gl-icon name="branch" data-testid="secret-branches" :size="12" class="gl-mr-1" />
              {{ branchesText(branch) }}
            </code>
            <gl-badge
              v-if="isProtected"
              icon="branch"
              icon-size="sm"
              variant="info"
              data-testid="secret-protected-badge"
            >
              {{ __('Protected') }}
            </gl-badge>
          </div>
        </template>
        <template #cell(createdAt)="{ item: { createdAt } }">
          <user-date :date="createdAt" data-testid="secret-created-at" />
        </template>
        <template #cell(actions)="{ item: { name } }">
          <actions-cell
            :edit-route="getEditRoute(name)"
            :secret-name="name"
            @delete-secret="deleteSecret"
          />
        </template>
        <template #cell(status)="{ item: { status } }">
          <gl-badge
            v-gl-tooltip
            :title="$options.SECRET_STATUS[status].description"
            :icon="$options.SECRET_STATUS[status].icon"
            :icon-size="$options.SECRET_STATUS[status].iconSize"
            :variant="$options.SECRET_STATUS[status].variant"
            :icon-optically-aligned="
              $options.SECRET_STATUS_ICONS_OPTICALLY_ALIGNED.includes(status)
            "
            data-testid="secret-health-status"
          >
            {{ $options.SECRET_STATUS[status].text }}
          </gl-badge>
        </template>
      </gl-table-lite>
    </crud-component>
    <div v-if="!isTrialEligible" class="gl-mt-5 gl-text-center">
      <gl-link :href="$options.OPEN_BETA_FEEDBACK_LINK" data-testid="feedback-link">{{
        __('Leave feedback')
      }}</gl-link>
      |
      <gl-link :href="$options.LEARN_MORE_LINK" data-testid="documentation-link">{{
        __('Documentation')
      }}</gl-link>
    </div>
    <secret-delete-modal
      :secret-name="secretToDelete"
      :show-modal="showDeleteModal"
      @hide="hideModal"
      @refetch-secrets="refetchSecrets"
      v-on="glListeners()"
    />
  </div>
</template>
