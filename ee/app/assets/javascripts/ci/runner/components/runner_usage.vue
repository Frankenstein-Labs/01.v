<script>
import {
  GlAvatar,
  GlButton,
  GlLink,
  GlTableLite,
  GlLoadingIcon,
  GlDaterangePicker,
  GlToastMixin,
} from '@gitlab/ui';
import { createAlert } from '~/alert';
import { s__, sprintf, n__, formatNumber } from '~/locale';
import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal';
import { INSTANCE_TYPE, GROUP_TYPE } from '~/ci/runner/constants';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import TooltipOnTruncate from '~/vue_shared/directives/tooltip_on_truncate';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';

import RunnerUsageQuery from '../graphql/performance/runner_usage.query.graphql';
import RunnerUsageByProjectQuery from '../graphql/performance/runner_usage_by_project.query.graphql';
import RunnerUsageExportMutation from '../graphql/performance/runner_usage_export.mutation.graphql';

const thClass = ['!gl-text-sm', '!gl-text-subtle'];

const defaultDatetimeRange = () => {
  const now = new Date();

  // Use UTC times, daily aggregates we use daily aggregates for large time windows
  const beginningOfPrevMonth = new Date(Date.UTC(now.getFullYear(), now.getMonth() - 1, 1));
  const endOfPrevMonth = new Date(Date.UTC(now.getFullYear(), now.getMonth(), 0));

  return { fromDate: beginningOfPrevMonth, toDate: endOfPrevMonth, maxToDate: now };
};

const DAYS_PER_YEAR = 365;

export default {
  name: 'RunnerUsage',
  components: {
    GlAvatar,
    GlButton,
    GlLink,
    GlTableLite,
    GlLoadingIcon,
    GlDaterangePicker,
  },
  directives: {
    TooltipOnTruncate,
  },
  mixins: [GlToastMixin],
  props: {
    scope: {
      type: String,
      required: true,
    },
    groupFullPath: {
      type: String,
      required: false,
      default: null,
    },
  },
  data() {
    const { fromDate, toDate, maxToDate } = defaultDatetimeRange();
    return {
      fromDate,
      toDate,
      maxToDate,
      exporting: false,
      topProjects: [],
      topRunners: [],
    };
  },
  apollo: {
    topProjects: {
      query: RunnerUsageByProjectQuery,
      variables() {
        return this.queryVariables;
      },
      update({ runnerUsageByProject }) {
        if (runnerUsageByProject.length) {
          return runnerUsageByProject;
        }
        return [{ project: null, ciDuration: null }];
      },
    },
    topRunners: {
      query: RunnerUsageQuery,
      variables() {
        return this.queryVariables;
      },
      update({ runnerUsage }) {
        if (runnerUsage.length) {
          return runnerUsage;
        }
        return [{ runner: null, ciDuration: null }];
      },
    },
  },
  computed: {
    queryVariables() {
      const ISODateRange = {
        fromDate: this.fromDate?.toISOString(),
        toDate: this.toDate?.toISOString(),
      };

      if (this.scope === INSTANCE_TYPE) {
        return {
          ...ISODateRange,
          runnerType: INSTANCE_TYPE,
        };
      }
      if (this.scope === GROUP_TYPE) {
        return {
          ...ISODateRange,
          fullPath: this.groupFullPath,
          runnerType: GROUP_TYPE,
        };
      }
      return null;
    },
    loading() {
      return this.$apollo.queries.topProjects.loading || this.$apollo.queries.topRunners.loading;
    },
    runnerField() {
      const labels = {
        [INSTANCE_TYPE]: s__('Runners|Most used instance runners'),
        [GROUP_TYPE]: s__('Runners|Most used group runners'),
      };

      return {
        key: 'runner',
        label: labels[this.scope],
        thClass: [...thClass, 'gl-width-full'],
      };
    },
    projectField() {
      const labels = {
        [INSTANCE_TYPE]: s__('Runners|Top projects consuming runners'),
        [GROUP_TYPE]: s__('Runners|Top projects consuming group runners'),
      };

      return {
        key: 'project',
        label: labels[this.scope],
        thClass: [...thClass, 'gl-width-full'],
      };
    },
    ciDurationField() {
      return {
        key: 'ciDuration',
        label: s__('Runners|Usage (min)'),
        thAlignRight: true,
        thClass,
        tdClass: 'gl-text-right',
      };
    },
    topRunnersFields() {
      return [this.runnerField, this.ciDurationField];
    },
    topProjectsFields() {
      return [this.projectField, this.ciDurationField];
    },
    dateRangeTooltip() {
      return sprintf(s__('Runners|Date range limited to %{dateRange} days'), {
        dateRange: DAYS_PER_YEAR,
      });
    },
  },
  methods: {
    formatBigIntString(value) {
      try {
        const n = BigInt(value);
        return formatNumber(n);
      } catch {
        return '-';
      }
    },
    runnerName(runner) {
      const { id: graphqlId, shortSha, description } = runner;
      const id = getIdFromGraphQLId(graphqlId);

      if (description) {
        return `#${id} (${shortSha}) - ${description}`;
      }
      return `#${id} (${shortSha})`;
    },
    onDaterangeInput({ startDate, endDate }) {
      this.fromDate = startDate;
      this.toDate = endDate;
    },
    async onClick() {
      const confirmed = await confirmAction(
        s__(
          'Runner|The CSV export contains a list of projects, the number of minutes used by instance runners, and the number of jobs that ran. When the export is completed, it is sent as an attachment to your email.',
        ),
        {
          title: s__('Runner|Export runner usage for selected dates'),
          primaryBtnText: s__('Runner|Export runner usage'),
        },
      );

      if (!confirmed) {
        return;
      }

      try {
        this.exporting = true;

        const {
          data: {
            runnersExportUsage: { errors },
          },
        } = await this.$apollo.mutate({
          mutation: RunnerUsageExportMutation,
          variables: {
            input: {
              ...this.queryVariables,
            },
          },
        });

        if (errors.length) {
          throw new Error(errors.join(' '));
        }

        this.$toast.show(
          s__(
            'Runner|Your CSV export has started. It will be sent to your email inbox when its ready.',
          ),
        );
      } catch (e) {
        createAlert({
          message: s__(
            'Runner|Something went wrong while generating the CSV export. Please try again.',
          ),
        });
        Sentry.captureException(e);
      } finally {
        this.exporting = false;
      }
    },
    dateRangeLabel(daysSelected) {
      if (typeof daysSelected === 'number' && daysSelected > 0) {
        return n__('Runner|1 day selected', 'Runner|%d days selected', daysSelected);
      }
      return '';
    },
  },
  DAYS_PER_YEAR,
};
</script>
<template>
  <div class="gl-border gl-rounded-base gl-p-5">
    <div class="gl-mb-4 gl-flex gl-items-center">
      <h2 class="gl-m-0 gl-grow gl-text-lg">
        {{ s__('Runners|Runner Usage') }}
      </h2>
      <gl-loading-icon v-if="loading" class="gl-ml-auto" />
    </div>

    <div class="-gl-mx-5 gl-mb-4 gl-flex gl-gap-4 gl-bg-subtle gl-px-5 gl-py-4">
      <gl-daterange-picker
        class="gl-grow"
        :default-start-date="fromDate"
        :default-end-date="toDate"
        :default-max-date="maxToDate"
        :max-date-range="$options.DAYS_PER_YEAR"
        :tooltip="dateRangeTooltip"
        @input="onDaterangeInput"
      >
        <template #default="{ daysSelected }">
          <span class="gl-hidden @lg/panel:gl-inline">{{ dateRangeLabel(daysSelected) }}</span>
        </template>
      </gl-daterange-picker>

      <div class="gl-self-end">
        <gl-button :loading="exporting" @click="onClick">
          {{ s__('Runners|Export as CSV') }}
        </gl-button>
      </div>
    </div>

    <div class="gl-items-start gl-justify-between gl-gap-4 @md/panel:gl-flex">
      <gl-table-lite
        :fields="topProjectsFields"
        :items="topProjects"
        class="runners-usage-table runners-top-result-table runners-dashboard-half-gap-4"
        data-testid="top-projects-table"
      >
        <template #cell(project)="{ value }">
          <div
            v-if="value"
            v-tooltip-on-truncate="value.nameWithNamespace"
            class="gl-overflow-hidden gl-text-ellipsis gl-whitespace-nowrap"
          >
            <gl-avatar
              :label="value.name"
              :src="value.avatarUrl"
              shape="rect"
              :size="16"
              :entity-name="value.name"
            />
            <gl-link :href="value.webUrl" class="!gl-text-default">
              {{ value.nameWithNamespace }}
            </gl-link>
          </div>
          <template v-else> {{ s__('Runners|Other projects') }} </template>
        </template>
        <template #cell(ciDuration)="{ item }">{{ formatBigIntString(item.ciDuration) }}</template>
      </gl-table-lite>

      <gl-table-lite
        :fields="topRunnersFields"
        :items="topRunners"
        class="runners-usage-table runners-top-result-table runners-dashboard-half-gap-4"
        data-testid="top-runners-table"
      >
        <template #cell(runner)="{ value }">
          <div
            v-tooltip-on-truncate
            class="gl-overflow-hidden gl-text-ellipsis gl-whitespace-nowrap"
          >
            <template v-if="value">
              <gl-link v-if="value.adminUrl" :href="value.adminUrl" class="!gl-text-default">
                {{ runnerName(value) }}
              </gl-link>
              <template v-else>{{ runnerName(value) }}</template>
            </template>
            <template v-else> {{ s__('Runners|Other runners') }} </template>
          </div>
        </template>
        <template #cell(ciDuration)="{ item }">{{ formatBigIntString(item.ciDuration) }}</template>
      </gl-table-lite>
    </div>
  </div>
</template>
