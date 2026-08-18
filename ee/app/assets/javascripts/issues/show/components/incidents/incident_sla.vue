<script>
import { GlIcon } from '@gitlab/ui';
import ServiceLevelAgreement from 'ee_component/vue_shared/components/incidents/service_level_agreement.vue';
import { createAlert } from '~/alert';
import { isValidDateString } from '~/lib/utils/datetime_utility';
import { s__ } from '~/locale';
import getSlaIncidentDataQuery from './graphql/queries/get_sla_due_at.query.graphql';

export default {
  name: 'IncidentSla',
  components: { GlIcon, ServiceLevelAgreement },
  inject: ['fullPath', 'iid', 'slaFeatureAvailable'],
  emits: ['update'],
  apollo: {
    slaDueAt: {
      query: getSlaIncidentDataQuery,
      variables() {
        return {
          fullPath: this.fullPath,
          iid: String(this.iid),
        };
      },
      update({ project }) {
        return project?.issue?.slaDueAt || null;
      },
      result({ data }) {
        const issue = data?.project?.issue;
        const isValidSla = isValidDateString(issue?.slaDueAt);

        // Render component
        this.hasData = isValidSla;

        // Render parent component
        this.$emit('update', isValidSla);
      },
      error() {
        createAlert({
          message: s__('Incident|There was an issue loading incident data. Please try again.'),
        });
      },
    },
  },
  data() {
    return {
      hasData: false,
      slaDueAt: null,
    };
  },
};
</script>

<template>
  <div v-if="slaFeatureAvailable && hasData">
    <span class="gl-font-bold">{{ s__('HighlightBar|Time to SLA:') }}</span>
    <span class="gl-whitespace-nowrap">
      <gl-icon name="timer" />
      <service-level-agreement :sla-due-at="slaDueAt" :issue-iid="iid" :project-path="fullPath" />
    </span>
  </div>
</template>
