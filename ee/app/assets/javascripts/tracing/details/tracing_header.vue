<script>
import { GlCard, GlBadge, GlButton } from '@gitlab/ui';
import { formatDate } from '~/lib/utils/datetime/date_format_utility';
import { s__, __ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import RelatedIssuesBadge from '~/observability/components/related_issues_badge.vue';
import { formatTraceDuration } from '../trace_utils';
import { createIssueUrlWithTraceDetails } from './utils';

const CARD_CLASS = 'gl-mr-7 gl-w-3/20 gl-min-w-fit';
const HEADER_CLASS = 'gl-p-2 gl-font-bold gl-flex gl-justify-center gl-items-center';
const BODY_CLASS =
  'gl-flex gl-justify-center gl-items-center gl-flex-col gl-my-0 gl-p-4 gl-font-bold gl-text-center gl-grow gl-text-lg';

const DATE_FORMAT = 'mmm d, yyyy';
const TIME_FORMAT = 'H:MM:ss.l Z';

export default {
  name: 'TracingHeader',
  CARD_CLASS,
  HEADER_CLASS,
  BODY_CLASS,
  components: {
    GlCard,
    GlBadge,
    PageHeading,
    GlButton,
    RelatedIssuesBadge,
  },
  i18n: {
    inProgress: s__('Tracing|In progress'),
    logsButtonTitle: s__('Tracing|View logs'),
    metricsButtonTitle: s__('Tracing|View metrics'),
    createIssueTitle: __('Create issue'),
  },
  props: {
    trace: {
      required: true,
      type: Object,
    },
    incomplete: {
      required: true,
      type: Boolean,
    },
    viewLogsUrl: {
      required: true,
      type: String,
    },
    viewMetricsUrl: {
      required: true,
      type: String,
    },
    createIssueUrl: {
      required: true,
      type: String,
    },
    totalErrors: {
      required: true,
      type: Number,
    },
    issues: {
      required: true,
      type: Array,
    },
    fetchingIssues: {
      type: Boolean,
      required: true,
    },
    error: {
      type: String,
      required: false,
      default: null,
    },
    relatedIssuesId: {
      required: true,
      type: String,
    },
  },
  computed: {
    title() {
      return `${this.trace.service_name} : ${this.trace.operation}`;
    },
    traceDate() {
      return formatDate(this.trace.timestamp, DATE_FORMAT);
    },
    traceTime() {
      return formatDate(this.trace.timestamp, TIME_FORMAT);
    },
    traceDuration() {
      return formatTraceDuration(this.trace.duration_nano);
    },
    createIssueUrlWithQuery() {
      return createIssueUrlWithTraceDetails({
        trace: this.trace,
        createIssueUrl: this.createIssueUrl,
        totalErrors: this.totalErrors,
      });
    },
  },
};
</script>

<template>
  <div>
    <header>
      <page-heading>
        <template #heading>
          {{ title }}
          <gl-badge v-if="incomplete" variant="warning" class="gl-ml-3 gl-align-middle">{{
            $options.i18n.inProgress
          }}</gl-badge>
        </template>
        <template #actions>
          <related-issues-badge
            :issues-total="issues.length"
            :loading="fetchingIssues"
            :error="error"
            :anchor-id="relatedIssuesId"
          />
          <gl-button :title="$options.i18n.logsButtonTitle" :href="viewLogsUrl">{{
            $options.i18n.logsButtonTitle
          }}</gl-button>
          <gl-button :title="$options.i18n.metricsButtonTitle" :href="viewMetricsUrl">{{
            $options.i18n.metricsButtonTitle
          }}</gl-button>
          <gl-button category="primary" variant="confirm" :href="createIssueUrlWithQuery">
            {{ $options.i18n.createIssueTitle }}
          </gl-button>
        </template>
      </page-heading>
    </header>
    <div class="gl-my-7 gl-flex gl-flex-wrap gl-justify-center gl-gap-y-6">
      <gl-card
        data-testid="trace-date-card"
        :class="$options.CARD_CLASS"
        :body-class="$options.BODY_CLASS"
        :header-class="$options.HEADER_CLASS"
      >
        <template #header>
          {{ s__('Tracing|Trace start') }}
        </template>

        <template #default>
          <span>{{ traceDate }}</span>
          <span class="gl-font-normal gl-text-subtle">{{ traceTime }}</span>
        </template>
      </gl-card>

      <gl-card
        data-testid="trace-duration-card"
        :class="$options.CARD_CLASS"
        :body-class="$options.BODY_CLASS"
        :header-class="$options.HEADER_CLASS"
      >
        <template #header>
          {{ s__('Tracing|Duration') }}
        </template>

        <template #default>
          <span>{{ traceDuration }}</span>
        </template>
      </gl-card>

      <gl-card
        data-testid="trace-spans-card"
        :class="$options.CARD_CLASS"
        :body-class="$options.BODY_CLASS"
        :header-class="$options.HEADER_CLASS"
      >
        <template #header>
          {{ s__('Tracing|Total spans') }}
        </template>

        <template #default>
          <span>{{ trace.total_spans }}</span>
        </template>
      </gl-card>
    </div>
  </div>
</template>
