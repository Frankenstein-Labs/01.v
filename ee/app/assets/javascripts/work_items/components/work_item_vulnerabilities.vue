<script>
import { GlBadge } from '@gitlab/ui';
import { n__, s__, sprintf } from '~/locale';
import { createAlert } from '~/alert';
import { VULNERABILITIES_ITEMS_ANCHOR } from '~/work_items/constants';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import WorkItemChildrenLoadMore from '~/work_items/components/shared/work_item_children_load_more.vue';
import { findVulnerabilitiesWidget } from '~/work_items/utils';
import workItemVulnerabilitiesQuery from '../graphql/work_item_vulnerabilities.query.graphql';
import WorkItemVulnerabilityItem from './work_item_vulnerability_item.vue';

const FETCH_MORE_ITEMS = 50;

export default {
  name: 'WorkItemVulnerabilities',
  components: {
    CrudComponent,
    GlBadge,
    WorkItemVulnerabilityItem,
    WorkItemChildrenLoadMore,
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
    workItemFullPath: {
      type: String,
      required: true,
    },
    workItemIid: {
      type: String,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      relatedVulnerabilities: [],
      pageInfo: {},
      relatedVulnerabilitiesCount: 0,
      fetchNextPageInProgress: false,
    };
  },
  computed: {
    hasRelatedVulnerabilities() {
      return this.relatedVulnerabilitiesCount > 0;
    },
    countBadgeAriaLabel() {
      return sprintf(
        n__(
          'WorkItem|Issue has 1 related vulnerability',
          'WorkItem|Issue has %{itemCount} related vulnerabilities',
          this.relatedVulnerabilitiesCount,
        ),
        { itemCount: this.relatedVulnerabilitiesCount },
      );
    },
    hasNextPage() {
      return this.pageInfo.hasNextPage;
    },
  },
  apollo: {
    relatedVulnerabilities: {
      query: workItemVulnerabilitiesQuery,
      variables() {
        return {
          fullPath: this.workItemFullPath,
          iid: this.workItemIid,
          useWorkItemFeatures: Boolean(this.glFeatures.workItemFeaturesField),
        };
      },
      update(data) {
        const relatedVulnerabilities = this.getRelatedVulnerabilities(data);
        this.pageInfo = relatedVulnerabilities?.pageInfo || {};
        this.relatedVulnerabilitiesCount = relatedVulnerabilities?.count || 0;

        return relatedVulnerabilities?.nodes || [];
      },
      error(error) {
        createAlert({
          message: s__('WorkItem|Something went wrong while fetching related vulnerabilities.'),
          captureError: true,
          error,
        });
      },
      skip() {
        return !this.workItemIid;
      },
    },
  },
  methods: {
    getRelatedVulnerabilities(data) {
      const workItemVulnerabilities = findVulnerabilitiesWidget(data.namespace?.workItem) || {};
      return workItemVulnerabilities.relatedVulnerabilities;
    },
    async fetchNextPage() {
      if (!this.hasNextPage || this.fetchNextPageInProgress) {
        return;
      }

      this.fetchNextPageInProgress = true;

      try {
        await this.$apollo.queries.relatedVulnerabilities.fetchMore({
          variables: {
            after: this.pageInfo.endCursor,
            first: FETCH_MORE_ITEMS,
          },
        });
      } catch (error) {
        createAlert({
          message: s__(
            'WorkItem|Something went wrong while fetching more related vulnerabilities.',
          ),
          captureError: true,
          error,
        });
      } finally {
        this.fetchNextPageInProgress = false;
      }
    },
  },
  VULNERABILITIES_ITEMS_ANCHOR,
};
</script>

<template>
  <crud-component
    v-if="hasRelatedVulnerabilities"
    :title="s__('WorkItem|Related vulnerabilities')"
    :anchor-id="$options.VULNERABILITIES_ITEMS_ANCHOR"
    is-collapsible
    persist-collapsed-state
  >
    <template #count>
      <gl-badge :aria-label="countBadgeAriaLabel" variant="neutral">
        {{ relatedVulnerabilitiesCount }}
      </gl-badge>
    </template>

    <ul class="content-list">
      <li v-for="item in relatedVulnerabilities" :key="item.id">
        <work-item-vulnerability-item :item="item" />
      </li>
    </ul>

    <div v-if="hasNextPage" class="!gl-border-t !gl-border-t-gray-300 !gl-px-2 gl-pb-2 gl-pt-2">
      <work-item-children-load-more
        :fetch-next-page-in-progress="fetchNextPageInProgress"
        data-testid="work-item-vulnerabilities-load-more"
        @fetch-next-page="fetchNextPage"
      />
    </div>
  </crud-component>
</template>
