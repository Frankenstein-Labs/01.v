<script>
import { GlDrawer, GlLink, GlButton } from '@gitlab/ui';
import { uniqueId } from 'lodash-es';
import { s__, __ } from '~/locale';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import { formatDate } from '~/lib/utils/datetime/date_format_utility';
import { FULL_DATE_TIME_FORMAT } from '~/observability/constants';
import RelatedIssue from '~/observability/components/observability_related_issues.vue';
import { helpPagePath } from '~/helpers/help_page_helper';
import RelatedIssuesBadge from '~/observability/components/related_issues_badge.vue';
import { createIssueUrlWithLogDetails } from '../utils';
import RelatedIssuesProvider from './related_issues/related_issues_provider.vue';

const createSectionContent = (obj) =>
  Object.entries(obj)
    .map(([k, v]) => ({ name: k, value: v }))
    .filter((e) => e.value)
    .sort((a, b) => (a.name > b.name ? 1 : -1));

export default {
  components: {
    GlDrawer,
    GlLink,
    GlButton,
    RelatedIssuesProvider,
    RelatedIssue,
    RelatedIssuesBadge,
  },
  i18n: {
    logDetailsTitle: s__('ObservabilityLogs|Metadata'),
    logAttributesTitle: s__('ObservabilityLogs|Attributes'),
    resourceAttributesTitle: s__('ObservabilityLogs|Resource attributes'),
    createIssueTitle: __('Create issue'),
  },
  props: {
    log: {
      required: false,
      type: Object,
      default: null,
    },
    open: {
      required: true,
      type: Boolean,
    },
    tracingIndexUrl: {
      type: String,
      required: true,
    },
    createIssueUrl: {
      required: true,
      type: String,
    },
    projectFullPath: {
      type: String,
      required: true,
    },
  },
  emits: ['close'],
  computed: {
    sections() {
      if (this.log) {
        const {
          log_attributes: logAttributes,
          resource_attributes: resourceAttributes,
          ...rest
        } = this.log;

        const sections = [
          {
            content: createSectionContent(rest),
            title: this.$options.i18n.logDetailsTitle,
            key: 'log-details',
          },
        ];
        if (logAttributes) {
          sections.push({
            title: this.$options.i18n.logAttributesTitle,
            content: createSectionContent(logAttributes),
            key: 'log-attributes',
          });
        }
        if (resourceAttributes) {
          sections.push({
            title: this.$options.i18n.resourceAttributesTitle,
            content: createSectionContent(resourceAttributes),
            key: 'resource-attributes',
          });
        }
        return sections.filter(({ content }) => content.length);
      }
      return [];
    },
    title() {
      if (!this.log) return '';
      return formatDate(this.log.timestamp, FULL_DATE_TIME_FORMAT);
    },
    drawerHeaderHeight() {
      // avoid calculating this in advance because it causes layout thrashing
      // https://gitlab.com/gitlab-org/gitlab/-/issues/331172#note_1269378396
      if (!this.open) return '0';
      return getContentWrapperHeight();
    },
    createIssueUrlWithQuery() {
      return createIssueUrlWithLogDetails({ log: this.log, createIssueUrl: this.createIssueUrl });
    },
  },
  methods: {
    isTraceId(key) {
      return key === 'trace_id';
    },
    traceIdLink(traceId) {
      return `${this.tracingIndexUrl}/${traceId}`;
    },
  },
  DRAWER_Z_INDEX,
  relatedIssuesHelpPath: helpPagePath('/development/feature_development'),
  relatedIssuesId: uniqueId('related-issues-'),
  logDrawerId: uniqueId('log-drawer-'),
};
</script>

<template>
  <related-issues-provider :log="log" :project-full-path="projectFullPath">
    <template #default="{ issues, loading: fetchingIssues, error }">
      <gl-drawer
        :id="$options.logDrawerId"
        :open="open"
        :z-index="$options.DRAWER_Z_INDEX"
        :header-height="drawerHeaderHeight"
        header-sticky
        @close="$emit('close')"
      >
        <template #title>
          <div data-testid="drawer-title">
            <h2 class="gl-mt-0 gl-text-size-h2">{{ title }}</h2>
            <gl-button
              class="gl-mr-2"
              category="primary"
              variant="confirm"
              :href="createIssueUrlWithQuery"
            >
              {{ $options.i18n.createIssueTitle }}
            </gl-button>
            <related-issues-badge
              :issues-total="issues.length"
              :loading="fetchingIssues"
              :error="error"
              :anchor-id="$options.relatedIssuesId"
              :parent-scrolling-id="$options.logDrawerId"
            />
          </div>
        </template>

        <template #default>
          <div
            v-for="section in sections"
            :key="section.key"
            :data-testid="`section-${section.key}`"
            class="gl-border-none !gl-pb-0"
          >
            <h2 v-if="section.title" data-testid="section-title" class="gl-my-0 gl-text-size-h2">
              {{ section.title }}
            </h2>
            <div
              v-for="line in section.content"
              :key="line.name"
              data-testid="section-line"
              class="gl-border-b-1 gl-border-b-strong gl-py-5 gl-border-b-solid"
            >
              <label data-testid="section-line-name">{{ line.name }}</label>
              <div data-testid="section-line-value" class="gl-wrap-anywhere">
                <gl-link v-if="isTraceId(line.name)" :href="traceIdLink(line.value)">
                  {{ line.value }}
                </gl-link>
                <template v-else>
                  {{ line.value }}
                </template>
              </div>
            </div>
          </div>
          <related-issue
            :id="$options.relatedIssuesId"
            class="!gl-pt-0"
            :issues="issues"
            :fetching-issues="fetchingIssues"
            :error="error"
            :help-path="$options.relatedIssuesHelpPath"
          />
        </template>
      </gl-drawer>
    </template>
  </related-issues-provider>
</template>
