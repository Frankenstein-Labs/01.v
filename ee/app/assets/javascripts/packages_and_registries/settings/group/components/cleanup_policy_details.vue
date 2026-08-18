<script>
import { GlAlert, GlButton, GlBadge, GlIcon, GlLink, GlSprintf } from '@gitlab/ui';
import { n__, s__, sprintf } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { newDate } from '~/lib/utils/datetime_utility';
import { localeDateFormat } from '~/lib/utils/datetime/locale_dateformat';
import { numberToHumanSize } from '~/lib/utils/number_utils';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import getVirtualRegistriesCleanupPolicyDetails from 'ee_component/packages_and_registries/settings/group/graphql/queries/get_virtual_registries_cleanup_policy_details.query.graphql';

const STATUS_CONFIG = {
  enabled: {
    variant: 'success',
    icon: 'check-circle-filled',
    text: s__('VirtualRegistryCleanupPolicy|Enabled'),
  },
  disabled: {
    variant: 'neutral',
    icon: 'cancel',
    text: s__('VirtualRegistryCleanupPolicy|Disabled'),
  },
  running: {
    variant: 'info',
    icon: 'status_running',
    text: s__('VirtualRegistryCleanupPolicy|Running'),
  },
};

const CADENCE_TEXT = {
  1: s__('VirtualRegistryCleanupPolicy|Runs %{strongStart}every day%{strongEnd}:'),
  7: s__('VirtualRegistryCleanupPolicy|Runs %{strongStart}every week%{strongEnd}:'),
  14: s__('VirtualRegistryCleanupPolicy|Runs %{strongStart}every two weeks%{strongEnd}:'),
  30: s__('VirtualRegistryCleanupPolicy|Runs %{strongStart}every month%{strongEnd}:'),
  90: s__('VirtualRegistryCleanupPolicy|Runs %{strongStart}every three months%{strongEnd}:'),
};

const CLEANUP_POLICY_STATUS = {
  ENABLED: 'enabled',
  DISABLED: 'disabled',
  RUNNING: 'running',
  FAILED: 'failed',
};

export default {
  name: 'CleanupPolicyDetails',
  cleanupPoliciesHelpPath: helpPagePath('user/packages/virtual_registry/_index', {
    anchor: 'cleanup-policies',
  }),
  components: {
    CrudComponent,
    GlAlert,
    GlButton,
    GlBadge,
    GlIcon,
    GlLink,
    GlSprintf,
  },
  inject: ['virtualRegistryCleanupPolicyPath', 'groupPath'],
  props: {
    virtualRegistriesSettingEnabled: {
      type: Boolean,
      required: true,
    },
  },
  apollo: {
    group: {
      query: getVirtualRegistriesCleanupPolicyDetails,
      variables() {
        return {
          fullPath: this.groupPath,
        };
      },
      context: {
        batchKey: 'GroupPackagesSettings',
      },
      error(e) {
        this.fetchSettingsError = e;
      },
    },
  },
  data() {
    return {
      group: {},
      fetchSettingsError: false,
    };
  },
  computed: {
    cleanupPolicy() {
      return this.group?.virtualRegistriesCleanupPolicy;
    },
    buttonText() {
      return this.cleanupPolicy
        ? s__('VirtualRegistryCleanupPolicy|Edit policy')
        : s__('VirtualRegistryCleanupPolicy|Set policy');
    },
    isLoading() {
      return this.$apollo.queries.group.loading;
    },
    policyStatus() {
      if (this.cleanupPolicy?.status === CLEANUP_POLICY_STATUS.RUNNING.toUpperCase()) {
        return CLEANUP_POLICY_STATUS.RUNNING;
      }
      return this.cleanupPolicy?.enabled
        ? CLEANUP_POLICY_STATUS.ENABLED
        : CLEANUP_POLICY_STATUS.DISABLED;
    },
    statusBadgeConfig() {
      return STATUS_CONFIG[this.policyStatus];
    },
    formattedCadence() {
      return CADENCE_TEXT[this.cleanupPolicy?.cadence];
    },
    policyDescription() {
      const items = [];

      if (this.cleanupPolicy?.keepNDaysAfterDownload) {
        items.push(
          sprintf(
            n__(
              'VirtualRegistryCleanupPolicy|Delete caches not accessed in the last %{strongStart}day%{strongEnd}',
              'VirtualRegistryCleanupPolicy|Delete caches not accessed in the last %{strongStart}%{days} days%{strongEnd}',
              this.cleanupPolicy.keepNDaysAfterDownload,
            ),
            {
              days: this.cleanupPolicy.keepNDaysAfterDownload,
            },
          ),
        );
      }

      if (this.cleanupPolicy?.notifyOnFailure && this.cleanupPolicy?.notifyOnSuccess) {
        items.push(
          s__(
            'VirtualRegistryCleanupPolicy|Send email notifications %{strongStart}when cleanup runs%{strongEnd} and %{strongStart}if cleanup fails%{strongEnd}',
          ),
        );
      } else if (this.cleanupPolicy?.notifyOnFailure) {
        items.push(
          s__(
            'VirtualRegistryCleanupPolicy|Send email notifications %{strongStart}if cleanup fails%{strongEnd}',
          ),
        );
      } else if (this.cleanupPolicy?.notifyOnSuccess) {
        items.push(
          s__(
            'VirtualRegistryCleanupPolicy|Send email notifications %{strongStart}when cleanup runs%{strongEnd}',
          ),
        );
      }

      return items;
    },
    formattedNextRunAt() {
      if (this.cleanupPolicy?.status === CLEANUP_POLICY_STATUS.RUNNING.toUpperCase()) {
        return s__('VirtualRegistryCleanupPolicy|%{labelStart}Next cleanup:%{labelEnd} Running.');
      }
      if (!this.cleanupPolicy?.nextRunAt || !this.cleanupPolicy.enabled) {
        return s__(
          'VirtualRegistryCleanupPolicy|%{labelStart}Next cleanup:%{labelEnd} Not scheduled.',
        );
      }
      return sprintf(
        s__('VirtualRegistryCleanupPolicy|%{labelStart}Next cleanup:%{labelEnd} %{date}.'),
        { date: this.formatDateTimeWithTimezone(this.cleanupPolicy.nextRunAt) },
      );
    },
    formattedLastRunAt() {
      if (!this.cleanupPolicy?.lastRunAt) {
        return s__('VirtualRegistryCleanupPolicy|%{labelStart}Last cleanup:%{labelEnd} Never run.');
      }

      const formattedDate = this.formatDateTimeWithTimezone(this.cleanupPolicy.lastRunAt);

      if (this.cleanupPolicy?.status === 'FAILED') {
        return sprintf(
          s__(
            'VirtualRegistryCleanupPolicy|%{labelStart}Last cleanup:%{labelEnd} %{iconPlaceholder}Cleanup failed on %{date}.',
          ),
          { date: formattedDate },
        );
      }

      return sprintf(
        s__('VirtualRegistryCleanupPolicy|%{labelStart}Last cleanup:%{labelEnd} %{date}.'),
        { date: formattedDate },
      );
    },
    formattedDeletedSize() {
      const size = this.cleanupPolicy?.lastRunDeletedSize;
      if (!size) return null;

      return numberToHumanSize(size);
    },
    showDeletedSize() {
      return !this.isLastRunFailed && this.cleanupPolicy?.lastRunAt && this.formattedDeletedSize;
    },
    isLastRunFailed() {
      return (
        this.cleanupPolicy?.status === CLEANUP_POLICY_STATUS.FAILED.toUpperCase() &&
        this.cleanupPolicy?.lastRunAt
      );
    },
    failureMessage() {
      return this.cleanupPolicy?.failureMessage;
    },
    isRunning() {
      return this.policyStatus === CLEANUP_POLICY_STATUS.RUNNING;
    },
  },
  methods: {
    formatDateTimeWithTimezone(datetime) {
      const date = newDate(datetime);
      return localeDateFormat.asDateTimeFull.format(date);
    },
  },
};
</script>

<template>
  <crud-component
    :title="s__('VirtualRegistryCleanupPolicy|Virtual registry cache cleanup policy')"
    :is-loading="isLoading"
  >
    <template #description>
      <gl-sprintf
        :message="
          s__(
            'VirtualRegistryCleanupPolicy|Automatically delete unused caches from the virtual registry to save storage space. %{linkStart}How do cleanup policies work?%{linkEnd}',
          )
        "
      >
        <template #link="{ content }">
          <gl-link :href="$options.cleanupPoliciesHelpPath">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </template>
    <template #actions>
      <gl-button
        :href="virtualRegistryCleanupPolicyPath"
        :disabled="!virtualRegistriesSettingEnabled"
        category="secondary"
        size="small"
      >
        {{ buttonText }}
      </gl-button>
    </template>

    <gl-alert v-if="fetchSettingsError" variant="warning" :dismissible="false">
      {{
        s__('VirtualRegistryCleanupPolicy|Something went wrong while fetching the cleanup policy.')
      }}
    </gl-alert>

    <template v-else-if="cleanupPolicy">
      <gl-alert v-if="isLastRunFailed" variant="danger" :dismissible="false" class="gl-mb-5">
        <div class="gl-mb-2 gl-flex gl-items-center">
          <strong class="gl-text-base">
            {{
              s__(
                'VirtualRegistryCleanupPolicy|Cache cleanup failed. No cache entries were removed.',
              )
            }}
          </strong>
        </div>
        <div v-if="failureMessage" class="gl-text-sm">
          {{ failureMessage }}
        </div>
      </gl-alert>

      <div class="gl-grid gl-grid-cols-1 gl-gap-3 @sm/panel:gl-grid-cols-2 @sm/panel:gl-gap-5">
        <div class="gl-flex gl-flex-col gl-gap-3">
          <!-- ci-status-icon-running added to fix icon rendering in dark mode -->
          <div :class="{ 'ci-status-icon-running': isRunning }">
            <gl-badge
              v-if="statusBadgeConfig"
              :variant="statusBadgeConfig.variant"
              :icon="statusBadgeConfig.icon"
            >
              {{ statusBadgeConfig.text }}
            </gl-badge>
          </div>

          <p class="gl-mb-0" data-testid="cleanup-policy-next-run">
            <gl-sprintf :message="formattedNextRunAt">
              <template #label="{ content }">
                <span class="gl-font-bold gl-text-default">{{ content }}</span>
              </template>
            </gl-sprintf>
          </p>
          <p class="gl-mb-0" data-testid="cleanup-policy-last-run">
            <gl-sprintf :message="formattedLastRunAt">
              <template #label="{ content }">
                <span class="gl-font-bold gl-text-default">{{ content }}</span>
              </template>
              <template #iconPlaceholder>
                <gl-icon
                  v-if="isLastRunFailed"
                  name="error"
                  class="gl-mr-2 gl-fill-status-danger"
                />
              </template>
            </gl-sprintf>
            <span v-if="showDeletedSize" class="gl-ml-1">
              {{
                sprintf(s__('VirtualRegistryCleanupPolicy|%{size} saved.'), {
                  size: formattedDeletedSize,
                })
              }}
            </span>
          </p>
        </div>

        <div class="gl-flex gl-flex-col gl-gap-3">
          <p v-if="formattedCadence" class="gl-mb-0">
            <gl-sprintf :message="formattedCadence">
              <template #strong="{ content }">
                <strong>{{ content }}</strong>
              </template>
            </gl-sprintf>
          </p>
          <ul class="gl-mb-0 gl-mt-0 gl-pl-6" data-testid="cleanup-policy-rules">
            <li v-for="(item, index) in policyDescription" :key="index" class="gl-mb-1">
              <gl-sprintf :message="item">
                <template #strong="{ content }">
                  <strong>{{ content }}</strong>
                </template>
              </gl-sprintf>
            </li>
          </ul>
        </div>
      </div>
    </template>
    <template v-else>
      {{
        s__(
          'VirtualRegistryCleanupPolicy|No cleanup rule yet. Define when caches should be deleted to save space.',
        )
      }}
    </template>
  </crud-component>
</template>
