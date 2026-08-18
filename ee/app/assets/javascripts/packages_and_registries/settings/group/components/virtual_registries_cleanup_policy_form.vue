<script>
import {
  GlToggle,
  GlSprintf,
  GlLink,
  GlFormGroup,
  GlFormSelect,
  GlFormInput,
  GlFormCheckbox,
  GlButton,
  GlAlert,
  GlSkeletonLoader,
  GlForm,
} from '@gitlab/ui';
import { formValidators } from '@gitlab/ui/src/utils';
import { s__, sprintf } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { visitUrlWithAlerts, visitUrl } from '~/lib/utils/url_utility';
import { localeDateFormat } from '~/lib/utils/datetime_utility';
import { helpPagePath } from '~/helpers/help_page_helper';
import getVirtualRegistriesCleanupPolicyDetails from 'ee_component/packages_and_registries/settings/group/graphql/queries/get_virtual_registries_cleanup_policy_details.query.graphql';
import upsertVirtualRegistriesCleanupPolicy from 'ee_component/packages_and_registries/settings/group/graphql/mutations/upsert_virtual_registries_cleanup_policy.mutation.graphql';

const CADENCE_OPTIONS = [
  { value: 1, text: s__('VirtualRegistryCleanupPolicyForm|Every day') },
  { value: 7, text: s__('VirtualRegistryCleanupPolicyForm|Every week') },
  { value: 14, text: s__('VirtualRegistryCleanupPolicyForm|Every two weeks') },
  { value: 30, text: s__('VirtualRegistryCleanupPolicyForm|Every month') },
  { value: 90, text: s__('VirtualRegistryCleanupPolicyForm|Every three months') },
];

const MIN_DAYS = 1;
const MAX_DAYS = 365;

const DEFAULT_FORM_DATA = {
  enabled: false,
  cadence: 1,
  keepNDaysAfterDownload: 7,
  notifyOnSuccess: false,
  notifyOnFailure: false,
};

export default {
  name: 'VirtualRegistriesCleanupPolicyForm',
  CADENCE_OPTIONS,
  MIN_DAYS,
  MAX_DAYS,
  cleanupPoliciesHelpPath: helpPagePath('user/packages/virtual_registry/_index', {
    anchor: 'cleanup-policies',
  }),
  keepNDaysValidators: [
    formValidators.required(s__('VirtualRegistryCleanupPolicyForm|This field is required.')),
    formValidators.factory(s__('VirtualRegistryCleanupPolicyForm|Must be a whole number.'), (val) =>
      Number.isInteger(Number(val)),
    ),
    formValidators.factory(
      sprintf(s__('VirtualRegistryCleanupPolicyForm|Must be at least %{min} day.'), {
        min: MIN_DAYS,
      }),
      (val) => Number(val) >= MIN_DAYS,
    ),
    formValidators.factory(
      sprintf(s__('VirtualRegistryCleanupPolicyForm|Must be %{max} days or less.'), {
        max: MAX_DAYS,
      }),
      (val) => Number(val) <= MAX_DAYS,
    ),
  ],
  components: {
    GlToggle,
    GlSprintf,
    GlLink,
    GlFormGroup,
    GlFormSelect,
    GlFormInput,
    GlFormCheckbox,
    GlButton,
    GlAlert,
    GlSkeletonLoader,
    GlForm,
    PageHeading,
  },
  inject: ['groupPath', 'settingsPath'],
  apollo: {
    group: {
      query: getVirtualRegistriesCleanupPolicyDetails,
      variables() {
        return { fullPath: this.groupPath };
      },
      result({ data }) {
        const policy = data?.group?.virtualRegistriesCleanupPolicy;
        if (policy) {
          this.formData = {
            enabled: policy.enabled,
            cadence: policy.cadence,
            keepNDaysAfterDownload: policy.keepNDaysAfterDownload,
            notifyOnSuccess: policy.notifyOnSuccess,
            notifyOnFailure: policy.notifyOnFailure,
          };
          if (policy.nextRunAt && !this.initialNextRunAt) {
            this.initialNextRunAt = policy.nextRunAt;
          }
        }
      },
      error() {
        this.error = s__(
          'VirtualRegistryCleanupPolicyForm|Failed to load cleanup policy. Please try again.',
        );
      },
    },
  },
  data() {
    return {
      group: {},
      formData: { ...DEFAULT_FORM_DATA },
      error: null,
      cadenceChanged: false,
      keepNDaysBlurred: false,
      initialNextRunAt: null,
      mutationLoading: false,
    };
  },
  computed: {
    cleanupPolicy() {
      return this.group?.virtualRegistriesCleanupPolicy;
    },
    isLoading() {
      return this.$apollo.queries.group.loading;
    },
    isFieldDisabled() {
      return this.isLoading || !this.formData.enabled;
    },
    isFormValid() {
      if (!this.formData.enabled) {
        return true;
      }

      const value = this.formData.keepNDaysAfterDownload;
      return this.$options.keepNDaysValidators.every((validator) => !validator(value));
    },
    isCancelDisabled() {
      return this.isLoading;
    },
    nextRunBaseTime() {
      // Match the backend scheduling: next run is calculated relative to the
      // policy's last run (or creation time if it has never run) rather than
      // the current moment, so the preview reflects when cleanup will
      // actually execute.
      if (this.cleanupPolicy?.lastRunAt) {
        return new Date(this.cleanupPolicy.lastRunAt);
      }
      if (this.cleanupPolicy?.createdAt) {
        return new Date(this.cleanupPolicy.createdAt);
      }
      return new Date();
    },
    nextRunAt() {
      if (!this.formData.enabled) {
        return s__('VirtualRegistryCleanupPolicyForm|Not yet scheduled');
      }

      if (this.initialNextRunAt && !this.cadenceChanged) {
        return localeDateFormat.asDateTimeFull.format(new Date(this.initialNextRunAt));
      }

      if (!this.cleanupPolicy || this.cadenceChanged) {
        const nextRun = new Date(
          this.nextRunBaseTime.getTime() + this.formData.cadence * 24 * 60 * 60 * 1000,
        );

        const nextRunAt = localeDateFormat.asDateTimeFull.format(nextRun);
        return sprintf(
          s__('VirtualRegistryCleanupPolicyForm|%{nextRunAt} (estimated cleanup time)'),
          {
            nextRunAt,
          },
        );
      }

      return s__('VirtualRegistryCleanupPolicyForm|Not yet scheduled');
    },
    keepNDaysAfterDownloadInvalid() {
      if (!this.keepNDaysBlurred) {
        return null;
      }

      const value = this.formData.keepNDaysAfterDownload;
      for (const validator of this.$options.keepNDaysValidators) {
        const error = validator(value);
        if (error) {
          return error;
        }
      }

      return null;
    },
    keepNDaysAfterDownloadState() {
      return this.keepNDaysAfterDownloadInvalid ? false : null;
    },
    mutationVariables() {
      return {
        fullPath: this.groupPath,
        ...this.formData,
      };
    },
  },
  methods: {
    async handleSubmit() {
      this.keepNDaysBlurred = true;
      this.error = null;

      if (!this.isFormValid) {
        return;
      }

      this.mutationLoading = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: upsertVirtualRegistriesCleanupPolicy,
          variables: {
            input: this.mutationVariables,
          },
        });

        const errors = data?.virtualRegistriesCleanupPolicyUpsert?.errors;
        if (errors?.length > 0) {
          this.error = errors.join(', ');
        } else {
          visitUrlWithAlerts(this.settingsPath, [
            {
              id: 'virtual-registries-cleanup-policy-saved',
              message: s__(
                'VirtualRegistryCleanupPolicyForm|Cleanup policy has been successfully saved.',
              ),
              variant: 'success',
            },
          ]);
        }
      } catch (e) {
        this.error = s__(
          'VirtualRegistryCleanupPolicyForm|Failed to save cleanup policy. Please try again.',
        );
      } finally {
        this.mutationLoading = false;
      }
    },
    handleCancel() {
      visitUrl(this.settingsPath);
    },
    handleCadenceChange() {
      this.cadenceChanged = true;
    },
    handleKeepNDaysBlur() {
      this.keepNDaysBlurred = true;
    },
    dismissError() {
      this.error = null;
    },
  },
};
</script>

<template>
  <div class="gl-pt-5">
    <page-heading
      :heading="s__('VirtualRegistryCleanupPolicyForm|Virtual registry cache cleanup policy')"
    >
      <template #description>
        <gl-sprintf
          :message="
            s__(
              'VirtualRegistryCleanupPolicyForm|Save storage space by automatically deleting caches from the virtual registry and keeping the ones you want. %{linkStart}How does cleanup work?%{linkEnd}',
            )
          "
        >
          <template #link="{ content }">
            <gl-link :href="$options.cleanupPoliciesHelpPath">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </template>
    </page-heading>

    <gl-alert v-if="error" variant="danger" class="gl-mb-5" @dismiss="dismissError">
      {{ error }}
    </gl-alert>

    <gl-skeleton-loader
      v-if="isLoading"
      :lines="3"
      size="lg"
      class="gl-mt-5"
      :label="s__('VirtualRegistryCleanupPolicyForm|Loading cleanup policy')"
    />

    <gl-form v-else @submit.prevent="handleSubmit">
      <div class="gl-flex gl-items-center gl-gap-3">
        <span class="gl-font-bold">{{
          s__('VirtualRegistryCleanupPolicyForm|Enable cleanup policy')
        }}</span>
        <gl-toggle
          v-model="formData.enabled"
          :label="s__('VirtualRegistryCleanupPolicyForm|Enable cleanup policy')"
          label-position="hidden"
        />
      </div>
      <p class="gl-mt-2 gl-text-subtle">
        {{ s__('VirtualRegistryCleanupPolicyForm|Disabling does not delete caches.') }}
      </p>

      <div class="gl-mt-5">
        <div class="gl-grid gl-grid-cols-1 gl-gap-3 @sm/panel:gl-grid-cols-2 @sm/panel:gl-gap-5">
          <gl-form-group
            :label="s__('VirtualRegistryCleanupPolicyForm|Run cleanup')"
            label-for="cadence-select"
          >
            <gl-form-select
              id="cadence-select"
              v-model="formData.cadence"
              :options="$options.CADENCE_OPTIONS"
              :disabled="isFieldDisabled"
              @change="handleCadenceChange"
            />
          </gl-form-group>

          <div>
            <p id="next-run-label" class="gl-mb-2 gl-font-bold">
              {{ s__('VirtualRegistryCleanupPolicyForm|Next cleanup scheduled to run on') }}
            </p>
            <div
              class="gl-py-2 gl-text-default"
              data-testid="cleanup-policy-next-run"
              aria-labelledby="next-run-label"
            >
              {{ nextRunAt }}
            </div>
          </div>
        </div>

        <gl-form-group
          :label="
            s__('VirtualRegistryCleanupPolicyForm|Delete caches not accessed in the last (days)')
          "
          :invalid-feedback="keepNDaysAfterDownloadInvalid"
          :state="keepNDaysAfterDownloadState"
          label-for="keep-n-days-input"
          class="gl-mt-5"
        >
          <gl-form-input
            id="keep-n-days-input"
            v-model.number="formData.keepNDaysAfterDownload"
            type="number"
            :disabled="isFieldDisabled"
            :state="keepNDaysAfterDownloadState"
            class="gl-w-20"
            @blur="handleKeepNDaysBlur"
          />
        </gl-form-group>

        <gl-form-group
          :label="s__('VirtualRegistryCleanupPolicyForm|Email notifications')"
          class="gl-mt-5"
        >
          <gl-form-checkbox
            v-model="formData.notifyOnSuccess"
            :disabled="isFieldDisabled"
            data-testid="notify-on-success-checkbox"
          >
            {{ s__('VirtualRegistryCleanupPolicyForm|Send email notifications when cleanup runs') }}
          </gl-form-checkbox>
          <gl-form-checkbox
            v-model="formData.notifyOnFailure"
            :disabled="isFieldDisabled"
            data-testid="notify-on-failure-checkbox"
          >
            {{ s__('VirtualRegistryCleanupPolicyForm|Send email notifications if cleanup fails') }}
          </gl-form-checkbox>
        </gl-form-group>

        <div class="gl-mt-5 gl-flex gl-flex-wrap gl-items-center gl-gap-3">
          <gl-button
            class="js-no-auto-disable"
            type="submit"
            variant="confirm"
            :loading="isLoading || mutationLoading"
          >
            {{ s__('VirtualRegistryCleanupPolicyForm|Save changes') }}
          </gl-button>
          <gl-button :disabled="isCancelDisabled" @click="handleCancel">
            {{ s__('VirtualRegistryCleanupPolicyForm|Cancel') }}
          </gl-button>
          <span class="gl-basis-full gl-text-sm gl-text-subtle @sm/panel:gl-basis-auto">
            {{
              s__(
                'VirtualRegistryCleanupPolicyForm|Note: Any policy update changes the scheduled run date and time',
              )
            }}
          </span>
        </div>
      </div>
    </gl-form>
  </div>
</template>
