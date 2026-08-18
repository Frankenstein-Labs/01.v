<script>
import { GlAvatar, GlTable } from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { s__, sprintf } from '~/locale';
import NoMinutesAlert from '../shared/no_minutes_alert.vue';

export default {
  name: 'MinutesUsageByNamespace',
  components: {
    GlAvatar,
    GlTable,
    NoMinutesAlert,
  },
  props: {
    usageData: {
      type: Array,
      required: true,
    },
  },
  computed: {
    tableFields() {
      return [
        {
          key: 'namespace',
          label: s__('UsageQuota|Namespace'),
          thClass: 'gl-w-1/3',
          tdClass: 'table-col gl-flex gl-items-center @sm/panel:gl-table-cell',
        },
        {
          key: 'hostedRunnerDuration',
          label: s__('UsageQuota|Hosted runner duration'),
          thClass: 'gl-w-1/3',
          tdClass: 'table-col gl-flex gl-items-center gl-content-center @sm/panel:gl-table-cell',
        },
        {
          key: 'computeUsage',
          label: s__('UsageQuota|Compute usage'),
          thClass: 'gl-w-1/3',
          tdClass: 'table-col gl-flex gl-items-center gl-content-center @sm/panel:gl-table-cell',
        },
      ];
    },
    emptyData() {
      return this.usageData.length === 0;
    },
  },
  methods: {
    formatDeletedNamespaceName(id) {
      return sprintf(
        s__('UsageQuota|Deleted Namespace #%{id}'),
        { id: getIdFromGraphQLId(id) },
        false,
      );
    },
    formatRunnerValues(value) {
      return parseFloat(value.toFixed(2));
    },
  },
};
</script>
<template>
  <div>
    <no-minutes-alert v-if="emptyData" />
    <gl-table
      v-else
      thead-class="gl-border-b-solid gl-border-default gl-border-1"
      :fields="tableFields"
      :items="usageData"
      stacked="md"
      fixed
    >
      <template
        #cell(namespace)="{
          item: {
            rootNamespace: { avatarUrl, name, id },
          },
        }"
      >
        <div class="gl-flex gl-items-center">
          <gl-avatar :src="avatarUrl" :size="32" />
          <span class="gl-ml-4" data-testid="runner-namespace">{{
            name || formatDeletedNamespaceName(id)
          }}</span>
        </div>
      </template>
      <template #cell(hostedRunnerDuration)="{ item: { durationMinutes } }">
        <span data-testid="runner-duration">{{ formatRunnerValues(durationMinutes) }}</span>
      </template>
      <template #cell(computeUsage)="{ item: { computeMinutesUsage } }">
        <span data-testid="compute-minutes">{{ formatRunnerValues(computeMinutesUsage) }}</span>
      </template>
    </gl-table>
  </div>
</template>
