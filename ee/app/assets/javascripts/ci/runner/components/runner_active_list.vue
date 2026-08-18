<script>
import { GlLink, GlTable, GlSkeletonLoader } from '@gitlab/ui';
import { formatNumber, s__ } from '~/locale';

import { tableField } from '~/ci/runner/utils';
import CiIcon from '~/vue_shared/components/ci_icon/ci_icon.vue';

import RunnerFullName from './runner_full_name.vue';

export default {
  name: 'RunnerActiveList',
  components: {
    GlLink,
    GlTable,
    CiIcon,
    GlSkeletonLoader,
    RunnerFullName,
  },
  props: {
    activeRunners: {
      type: Array,
      default: () => [],
      required: false,
    },
    loading: {
      type: Boolean,
      default: false,
      required: false,
    },
  },
  methods: {
    formatNumber,
  },
  fields: [
    tableField({ key: 'runner', label: s__('Runners|Runner') }),
    tableField({
      key: 'runningJobCount',
      label: s__('Runners|Running Jobs'),
      tdClass: '!gl-align-middle',
    }),
  ],
  CI_ICON_STATUS: { group: 'running', icon: 'status_running' },
};
</script>
<template>
  <div class="gl-border gl-rounded-base gl-p-5">
    <h2 class="gl-mt-0 gl-text-lg">{{ s__('Runners|Most active runners') }}</h2>

    <gl-table
      v-if="loading || activeRunners.length"
      :busy="loading"
      :fields="$options.fields"
      :items="activeRunners"
      class="runner-active-list-table"
    >
      <template #table-busy>
        <gl-skeleton-loader :lines="9" />
      </template>
      <template #cell(runner)="{ item = {} }">
        <runner-full-name :runner="item" />
      </template>
      <template #cell(runningJobCount)="{ item = {}, value }">
        <gl-link :href="item.webUrl">
          <ci-icon :status="$options.CI_ICON_STATUS" />
          {{ formatNumber(value) }}
        </gl-link>
      </template>
    </gl-table>
    <p v-else>
      {{
        s__(
          'Runners|There are no runners running jobs right now. Active runners will populate here as they pick up jobs.',
        )
      }}
    </p>
  </div>
</template>
