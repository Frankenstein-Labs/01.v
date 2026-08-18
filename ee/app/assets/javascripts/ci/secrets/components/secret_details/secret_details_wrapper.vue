<script>
import { GlAlert, GlButton, GlDisclosureDropdown, GlLoadingIcon } from '@gitlab/ui';
import { __, s__, sprintf } from '~/locale';
import { fetchPolicies } from '~/lib/graphql';
import { localeDateFormat } from '~/lib/utils/datetime_utility';
import { createAlert } from '~/alert';
import { InternalEvents } from '~/tracking';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { formatGraphQLError } from 'ee/ci/secrets/utils';
import {
  EDIT_ROUTE_NAME,
  ENTITLEMENT_STATE_TRIAL_ELIGIBLE,
  INDEX_ROUTE_NAME,
  PAGE_VISIT_SECRET_DETAILS,
  SECRET_ROTATION_STATUS,
} from 'ee/ci/secrets/constants';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import SecretDeleteModal from '../secret_delete_modal.vue';
import SecretDetails from './secret_details.vue';

export default {
  name: 'SecretDetailsWrapper',
  components: {
    GlAlert,
    GlButton,
    GlDisclosureDropdown,
    GlLoadingIcon,
    SecretDeleteModal,
    SecretDetails,
  },
  mixins: [glFeatureFlagsMixin(), InternalEvents.mixin(), glListenersMixin],
  inject: ['contextConfig', 'entitlement', 'fullPath', 'isReadOnly'],
  props: {
    secretName: {
      type: String,
      required: true,
    },
  },
  apollo: {
    secret: {
      skip() {
        return !this.secretName;
      },
      query() {
        return this.contextConfig.getSecretDetails.query;
      },
      variables() {
        return {
          fullPath: this.fullPath,
          name: this.secretName,
        };
      },
      update(data) {
        return data.secret || null;
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
  data() {
    return {
      secret: null,
      showDeleteModal: false,
    };
  },
  computed: {
    disclosureDropdownOptions() {
      return [
        {
          text: __('Delete'),
          variant: 'danger',
          action: () => {
            this.showDeleteModal = true;
          },
        },
      ];
    },
    isSecretLoading() {
      return this.$apollo.queries.secret.loading;
    },
    rotationAlertProperties() {
      const { rotationInfo } = this.secret;
      const status = rotationInfo?.status;

      if (status === SECRET_ROTATION_STATUS.approaching && rotationInfo?.nextReminderAt) {
        const formattedDate = localeDateFormat.asDate.format(new Date(rotationInfo.nextReminderAt));
        return {
          title: s__('SecretRotation|Rotation reminder'),
          message: sprintf(
            s__('SecretRotation|Update this secret by %{date} to maintain security.'),
            { date: formattedDate },
          ),
        };
      }

      if (status === SECRET_ROTATION_STATUS.overdue) {
        return {
          title: s__('SecretRotation|Secret overdue for rotation'),
          message: s__(
            'SecretRotation|This secret has not been rotated after the configured rotation reminder interval.',
          ),
        };
      }

      return null;
    },
  },
  mounted() {
    if (
      this.glFeatures.secretsManagerPaidExperience &&
      this.entitlement?.state === ENTITLEMENT_STATE_TRIAL_ELIGIBLE
    ) {
      this.$router.push({ name: INDEX_ROUTE_NAME });
      return;
    }

    const { eventTracking } = this.contextConfig;
    this.trackEvent(eventTracking.pageVisit, { label: PAGE_VISIT_SECRET_DETAILS });
  },
  methods: {
    goToEdit() {
      this.$router.push({ name: EDIT_ROUTE_NAME, params: { secretName: this.secretName } });
    },
    hideModal() {
      this.showDeleteModal = false;
    },
  },
};
</script>
<template>
  <div>
    <gl-loading-icon v-if="isSecretLoading" size="lg" class="gl-mt-5" />
    <div v-if="secret">
      <secret-delete-modal
        :full-path="fullPath"
        :secret-name="secret.name"
        :show-modal="showDeleteModal"
        @hide="hideModal"
        v-on="glListeners()"
      />
      <gl-alert
        v-if="rotationAlertProperties"
        class="gl-mb-5 gl-mt-5"
        :title="rotationAlertProperties.title"
        variant="warning"
      >
        {{ rotationAlertProperties.message }}
      </gl-alert>
      <div class="gl-flex gl-items-center gl-justify-between">
        <h1 class="page-title gl-text-size-h-display">{{ secret.name }}</h1>
        <div v-if="!isReadOnly">
          <gl-button
            icon="pencil"
            :aria-label="__('Edit')"
            data-testid="secret-edit-button"
            @click="goToEdit"
          />
          <gl-disclosure-dropdown
            category="tertiary"
            icon="ellipsis_v"
            no-caret
            :items="disclosureDropdownOptions"
          />
        </div>
      </div>
      <secret-details :secret="secret" />
    </div>
  </div>
</template>
