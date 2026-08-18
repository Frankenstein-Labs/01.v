<script>
import { GlLink, GlTableLite } from '@gitlab/ui';
import { s__ } from '~/locale';
import UserDate from '~/vue_shared/components/user_date.vue';
import { SHORT_DATE_FORMAT_WITH_TIME } from '~/vue_shared/constants';
import { formatNumber } from '../../../utils';

export default {
  name: 'EventsTable',
  components: {
    GlLink,
    GlTableLite,
    UserDate,
  },
  props: {
    events: {
      type: Array,
      required: true,
    },
  },
  computed: {
    tableFields() {
      return [
        { key: 'timestamp', label: s__('UsageBilling|Date/Time') },
        { key: 'action', label: s__('UsageBilling|Action') },
        { key: 'location', label: s__('UsageBilling|Location') },
        { key: 'creditsUsed', label: s__('UsageBilling|Credit amount') },
      ];
    },
  },
  methods: {
    formatNumber,
  },
  SHORT_DATE_FORMAT_WITH_TIME,
};
</script>
<template>
  <div>
    <gl-table-lite :fields="tableFields" :items="events">
      <template #cell(timestamp)="{ item }">
        <user-date :date="item.timestamp" :date-format="$options.SHORT_DATE_FORMAT_WITH_TIME" />
      </template>

      <template #cell(location)="{ item }">
        <gl-link v-if="item.location" :href="item.location.webUrl">
          {{ item.location.name }}
        </gl-link>
      </template>

      <template #cell(action)="{ item }">
        <gl-link v-if="item.sessionLink" :href="item.sessionLink">
          {{ item.flowType || item.eventType }}
        </gl-link>
        <template v-else>{{ item.flowType || item.eventType }}</template>
      </template>

      <template #cell(creditsUsed)="{ item }">
        {{ formatNumber(item.creditsUsed || 0) }}
      </template>
    </gl-table-lite>
  </div>
</template>
