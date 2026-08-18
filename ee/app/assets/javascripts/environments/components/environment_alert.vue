<script>
import { GlLink, GlSprintf, GlTooltipDirective as GlTooltip } from '@gitlab/ui';
import SeverityBadge from 'ee/vue_shared/security_reports/components/severity_badge.vue';
import { s__ } from '~/locale';
import TimeagoMixin from '~/vue_shared/mixins/timeago';
import alertQuery from '../graphql/queries/environment.query.graphql';

export default {
  name: 'EnvironmentAlert',
  components: {
    GlLink,
    GlSprintf,
    SeverityBadge,
  },
  directives: {
    GlTooltip,
  },
  mixins: [TimeagoMixin],
  inject: {
    projectPath: {
      default: '',
    },
  },
  props: {
    environment: {
      required: true,
      type: Object,
    },
  },
  data() {
    return { alert: null };
  },
  apollo: {
    alert: {
      query: alertQuery,
      variables() {
        return {
          fullPath: this.projectPath,
          environmentName: this.environment.name,
        };
      },
      update(data) {
        return data?.project?.environment?.latestOpenedMostSevereAlert;
      },
    },
  },
  translations: {
    alertText: s__(
      'EnvironmentsAlert|%{severity} • %{title}. %{linkStart}View Details%{linkEnd} · %{startedAt} ',
    ),
  },
  computed: {
    severity() {
      return this.alert?.severity;
    },
  },
  classes: [
    'gl-py-2',
    'gl-pl-3',
    'gl-text-default',
    'gl-border-t-solid',
    'gl-border-default',
    'gl-border-1',
  ],
};
</script>
<template>
  <div v-if="alert" :class="$options.classes" data-testid="alert">
    <gl-sprintf :message="$options.translations.alertText">
      <template #severity>
        <severity-badge v-if="severity" :severity="severity" class="gl-inline" />
      </template>
      <template #startedAt>
        <time v-gl-tooltip :datetime="alert.startedAt" :title="tooltipTitle(alert.startedAt)">
          {{ timeFormatted(alert.startedAt) }}
        </time>
      </template>
      <template #title>
        <span>{{ alert.title }}</span>
      </template>
      <template #link="{ content }">
        <gl-link :href="alert.detailsUrl" data-testid="alert-link">{{ content }}</gl-link>
      </template>
    </gl-sprintf>
  </div>
</template>
