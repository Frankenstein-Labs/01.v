<script>
import {
  GlTab,
  GlBadge,
  GlLink,
  GlTable,
  GlKeysetPagination,
  GlAlert,
  GlSkeletonLoader,
  GlTruncate,
} from '@gitlab/ui';
import CiIcon from '~/vue_shared/components/ci_icon/ci_icon.vue';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { DAST_SHORT_NAME } from '~/security_configuration/constants';
import { s__ } from '~/locale';
import { getIdFromGraphQLId, setupQueryPollingByVisibility } from '~/graphql_shared/utils';
import { getQueryHeaders } from '~/ci/pipeline_details/graph/utils';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';
import handlesErrors from '../../mixins/handles_errors';
import Actions from '../actions.vue';
import EmptyState from '../empty_state.vue';
import {
  PIPELINES_PER_PAGE,
  MAX_PIPELINES_COUNT,
  PIPELINES_POLL_INTERVAL,
  ACTION_COLUMN,
} from '../../constants';

const defaultCursor = {
  first: PIPELINES_PER_PAGE,
  last: null,
  after: null,
  before: null,
};

export default {
  PIPELINES_PER_PAGE,
  DAST_SHORT_NAME,
  getIdFromGraphQLId,
  components: {
    GlTab,
    GlBadge,
    GlLink,
    GlTable,
    GlKeysetPagination,
    GlAlert,
    GlSkeletonLoader,
    GlTruncate,
    CiIcon,
    TimeAgoTooltip,
    Actions,
    EmptyState,
  },
  mixins: [handlesErrors, glSlotsMixin],
  inject: ['canEditOnDemandScans', 'projectPath', 'projectOnDemandScanCountsEtag'],
  props: {
    isActive: {
      type: Boolean,
      required: true,
    },
    query: {
      type: Object,
      required: true,
    },
    queryVariables: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    title: {
      type: String,
      required: true,
    },
    itemsCount: {
      type: Number,
      required: true,
    },
    maxItemsCount: {
      type: Number,
      required: false,
      default: MAX_PIPELINES_COUNT,
    },
    emptyStateTitle: {
      type: String,
      required: false,
      default: undefined,
    },
    emptyStateText: {
      type: String,
      required: false,
      default: undefined,
    },
    fields: {
      type: Array,
      required: true,
    },
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    pipelines: {
      query() {
        return this.query;
      },
      variables() {
        return {
          fullPath: this.projectPath,
          ...this.queryVariables,
          ...this.cursor,
        };
      },
      context() {
        return getQueryHeaders(this.projectOnDemandScanCountsEtag);
      },
      update(data) {
        const pipelines = data?.project?.pipelines;
        if (!pipelines?.nodes?.length && (this.cursor.after || this.cursor.before)) {
          this.resetCursor();
          this.updateRoute();
        }
        return pipelines;
      },
      error() {
        this.hasError = true;
      },
      skip() {
        return !this.isActive;
      },
      pollInterval: PIPELINES_POLL_INTERVAL,
    },
  },
  data() {
    const { after, before } = this.$route.query;
    const cursor = { ...defaultCursor };

    if (after) {
      cursor.after = after;
    } else if (before) {
      cursor.before = before;
      cursor.first = null;
      cursor.last = PIPELINES_PER_PAGE;
    }

    return {
      cursor,
      hasError: false,
    };
  },
  computed: {
    formattedCount() {
      const { itemsCount, maxItemsCount } = this;
      return itemsCount === maxItemsCount ? `${itemsCount}+` : itemsCount;
    },
    pipelineNodes() {
      return this.pipelines?.nodes ?? [];
    },
    hasPipelines() {
      return this.pipelineNodes.length > 0;
    },
    pageInfo() {
      return this.pipelines?.pageInfo;
    },
    tableFields() {
      return [...this.fields, ACTION_COLUMN].map((field) => ({
        ...field,
        class: ['gl-text-default'],
        thClass: ['!gl-bg-transparent', 'gl-whitespace-nowrap'],
      }));
    },
  },
  watch: {
    isActive(isActive) {
      if (isActive) {
        this.resetCursor();
        this.resetActionError();
      }
    },
    hasPipelines(hasPipelines) {
      if (this.hasError && hasPipelines) {
        this.hasError = false;
      }
    },
  },
  mounted() {
    this.pollingVisibilityCleanup = setupQueryPollingByVisibility(
      this.$apollo.queries.pipelines,
      PIPELINES_POLL_INTERVAL,
    );
  },
  beforeDestroy() {
    this.pollingVisibilityCleanup?.();
  },
  methods: {
    resetCursor() {
      this.cursor = { ...defaultCursor };
    },
    nextPage(after) {
      this.cursor = {
        ...defaultCursor,
        after,
      };
      this.updateRoute({ after });
    },
    prevPage(before) {
      this.cursor = {
        first: null,
        last: PIPELINES_PER_PAGE,
        after: null,
        before,
      };
      this.updateRoute({ before });
    },
    updateRoute(query = {}) {
      this.scrollToTop();
      this.$router.push({
        path: this.$route.path,
        query,
      });
      this.resetActionError();
    },
  },
  i18n: {
    errorMessage: s__(
      'OnDemandScans|Could not fetch on-demand scans. Please refresh the page, or try again later.',
    ),
  },
};
</script>

<template>
  <gl-tab v-bind="$attrs">
    <template #title>
      <span class="gl-whitespace-nowrap">
        {{ title }}
        <gl-badge class="gl-tab-counter-badge">{{ formattedCount }}</gl-badge>
      </span>
    </template>
    <template v-if="$apollo.queries.pipelines.loading || hasPipelines">
      <gl-table
        thead-class="gl-border-b-solid gl-border-default gl-border-1"
        :fields="tableFields"
        :items="pipelineNodes"
        :busy="$apollo.queries.pipelines.loading"
        stacked="md"
        fixed
      >
        <template #table-colgroup="scope">
          <col v-for="field in scope.fields" :key="field.key" :class="field.columnClass" />
        </template>

        <template #table-busy>
          <gl-skeleton-loader v-for="i in 20" :key="i" :width="1000" :height="45">
            <rect width="85" height="20" x="0" y="5" rx="4" />
            <rect width="100" height="20" x="150" y="5" rx="4" />
            <rect width="150" height="20" x="300" y="5" rx="4" />
            <rect width="100" height="20" x="500" y="5" rx="4" />
            <rect width="150" height="20" x="655" y="5" rx="4" />
            <rect width="70" height="20" x="855" y="5" rx="4" />
          </gl-skeleton-loader>
        </template>

        <template v-if="hasActionError || glSlots().error" #top-row>
          <td :colspan="tableFields.length">
            <gl-alert class="gl-my-4" variant="danger" :dismissible="false">
              <slot name="error">{{ actionErrorMessage }}</slot>
            </gl-alert>
          </td>
        </template>

        <template #cell(status)="{ value }">
          <div class="gl-my-3">
            <ci-icon :status="value" show-status-text />
          </div>
        </template>

        <template #cell(name)="{ value, item }">
          <gl-truncate v-if="value" :text="value" with-tooltip />
          <div v-if="glSlots()['after-name']">
            <slot name="after-name" v-bind="item"></slot>
          </div>
        </template>

        <template #cell(scanType)>
          {{ $options.DAST_SHORT_NAME }}
        </template>

        <template #cell(targetUrl)="{ value }">
          <gl-truncate v-if="value" :text="value" with-tooltip />
        </template>

        <template #cell(createdAt)="{ item }">
          <time-ago-tooltip
            v-if="item.createdAt"
            class="gl-whitespace-nowrap"
            :time="item.createdAt"
          />
        </template>

        <template #cell(id)="{ item }">
          <gl-link :href="item.path">#{{ $options.getIdFromGraphQLId(item.id) }}</gl-link>
        </template>

        <template #cell(actions)="{ item }">
          <actions
            v-if="canEditOnDemandScans"
            :key="item.id"
            :scan="item"
            @action="resetActionError"
            @error="handleActionError"
          />
        </template>

        <template v-for="slot in Object.keys(glSlots())" #[slot]="scope">
          <slot :name="slot" v-bind="scope"></slot>
        </template>
      </gl-table>

      <div class="gl-flex gl-justify-center">
        <gl-keyset-pagination
          data-testid="pagination"
          v-bind="pageInfo"
          @prev="prevPage"
          @next="nextPage"
        />
      </div>

      <slot></slot>
    </template>
    <gl-alert
      v-else-if="hasError"
      variant="danger"
      :dismissible="false"
      class="gl-my-4"
      data-testid="error-alert"
    >
      {{ $options.i18n.errorMessage }}
    </gl-alert>
    <empty-state v-else :title="emptyStateTitle" :text="emptyStateText" no-primary-button />
  </gl-tab>
</template>
