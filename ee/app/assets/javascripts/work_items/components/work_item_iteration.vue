<script>
import { GlLink } from '@gitlab/ui';
import { isEmpty } from 'lodash-es';
import { newWorkItemId } from '~/work_items/utils';
import { getIterationPeriod, groupOptionsByIterationCadences } from 'ee/iterations/utils';
import IterationTitle from 'ee/iterations/components/iteration_title.vue';
import WorkItemSidebarDropdownWidget from '~/work_items/components/shared/work_item_sidebar_dropdown_widget.vue';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import projectIterationsQuery from 'ee/work_items/graphql/project_iterations.query.graphql';
import groupIterationsQuery from 'ee/sidebar/queries/group_iterations.query.graphql';
import { STATUS_OPEN } from '~/issues/constants';
import { s__, sprintf } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import Tracking from '~/tracking';
import {
  I18N_WORK_ITEM_ERROR_UPDATING,
  TRACKING_CATEGORY_SHOW,
  VIEW_CONTEXT,
} from '~/work_items/constants';
import updateWorkItemMutation from '~/work_items/graphql/update_work_item.mutation.graphql';

export default {
  name: 'WorkItemIteration',
  i18n: {
    iteration: s__('WorkItem|Iteration'),
    none: s__('WorkItem|None'),
    iterationPlaceholder: s__('WorkItem|No iteration'),
  },
  components: {
    WorkItemSidebarDropdownWidget,
    IterationTitle,
    GlLink,
  },
  mixins: [Tracking.mixin(), glFeatureFlagsMixin()],
  inject: {
    viewContext: { default: VIEW_CONTEXT.fullScreen },
  },
  props: {
    fullPath: {
      type: String,
      required: true,
    },
    isGroup: {
      type: Boolean,
      required: true,
    },
    iteration: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    canUpdate: {
      type: Boolean,
      required: false,
      default: false,
    },
    workItemId: {
      type: String,
      required: true,
    },
    workItemType: {
      type: String,
      required: true,
    },
  },
  emits: ['error', 'iterationUpdated', 'update-widget-draft'],
  data() {
    return {
      searchTerm: '',
      shouldFetch: false,
      selectedIterationId: this.iteration?.id,
      updateInProgress: false,
      iterations: [],
      localIteration: this.iteration,
    };
  },
  computed: {
    // eslint-disable-next-line vue/no-unused-properties
    tracking() {
      return {
        category: TRACKING_CATEGORY_SHOW,
        label: 'item_iteration',
        property: `type_${this.workItemType}`,
        extra: { viewContext: this.viewContext },
      };
    },
    iterationPeriod() {
      return this.localIteration?.period || getIterationPeriod(this.localIteration);
    },
    iterationTitle() {
      return this.localIteration?.title || this.iterationPeriod;
    },
    listboxItems() {
      return groupOptionsByIterationCadences(this.iterations);
    },
    isLoadingIterations() {
      return this.$apollo.queries.iterations.loading;
    },
    noIterationDefaultText() {
      return this.canUpdate ? this.$options.i18n.iterationPlaceholder : this.$options.i18n.none;
    },
    dropdownText() {
      return this.localIteration?.id ? this.iterationTitle : this.noIterationDefaultText;
    },
    selectedIteration() {
      return !isEmpty(this.iterations)
        ? this.iterations.find(({ id }) => id === this.selectedIterationId)
        : this.localIteration;
    },
    selectedIterationCadenceName() {
      return this.selectedIteration?.iterationCadence?.title;
    },
    localIterationId() {
      return this.localIteration ? this.localIteration?.id : null;
    },
    localIterationNumericId() {
      return this.localIterationId ? getIdFromGraphQLId(this.localIterationId) : '';
    },
  },
  watch: {
    iteration(newVal) {
      this.localIteration = newVal;
      this.selectedIterationId = newVal?.id;
    },
  },
  apollo: {
    iterations: {
      query() {
        return this.isGroup ? groupIterationsQuery : projectIterationsQuery;
      },
      variables() {
        const search = this.searchTerm ? `"${this.searchTerm}"` : '';
        return {
          fullPath: this.fullPath,
          title: search,
          state: STATUS_OPEN,
        };
      },
      update(data) {
        return data.namespace?.attributes?.nodes || [];
      },
      skip() {
        return !this.shouldFetch;
      },
      error() {
        this.$emit(
          'error',
          s__('WorkItem|Something went wrong when fetching iterations. Please try again.'),
        );
      },
    },
  },
  methods: {
    onDropdownShown() {
      this.searchTerm = '';
      this.shouldFetch = true;
    },
    search(searchTerm) {
      this.searchTerm = searchTerm;
      this.shouldFetch = true;
    },
    async updateWorkItemIteration(selectedIterationId) {
      if (this.iteration?.id === selectedIterationId) {
        return;
      }

      this.localIteration = selectedIterationId
        ? this.iterations.find(({ id }) => id === selectedIterationId)
        : null;
      this.selectedIterationId = selectedIterationId;
      this.track('update_iteration');

      this.updateInProgress = true;

      try {
        if (this.workItemId === newWorkItemId(this.workItemType)) {
          this.$emit('update-widget-draft', { iteration: this.localIteration });
          this.updateInProgress = false;
          return;
        }

        const {
          data: {
            workItemUpdate: { errors },
          },
        } = await this.$apollo.mutate({
          mutation: updateWorkItemMutation,
          variables: {
            input: {
              id: this.workItemId,
              iterationWidget: {
                iterationId: selectedIterationId,
              },
            },
            useWorkItemFeatures: Boolean(this.glFeatures?.workItemFeaturesField),
          },
        });
        this.track('updated_iteration');
        this.$emit('iterationUpdated', selectedIterationId);
        if (errors.length > 0) {
          throw new Error(errors.join('\n'));
        }
      } catch (error) {
        const msg = sprintf(I18N_WORK_ITEM_ERROR_UPDATING, {
          workItemType: this.workItemType,
        });
        this.$emit('error', msg);
        this.localIteration = this.iteration;
        Sentry.captureException(error);
      } finally {
        this.updateInProgress = false;
        this.searchTerm = '';
        this.shouldFetch = false;
        this.selectedIterationId = selectedIterationId;
      }
    },
  },
};
</script>

<template>
  <work-item-sidebar-dropdown-widget
    :dropdown-label="$options.i18n.iteration"
    :can-update="canUpdate"
    dropdown-name="iteration"
    :loading="isLoadingIterations"
    :list-items="listboxItems"
    :item-value="localIterationId"
    :update-in-progress="updateInProgress"
    :toggle-dropdown-text="dropdownText"
    :header-text="__('Select iteration')"
    :reset-button-label="__('Clear')"
    data-testid="work-item-iteration"
    @dropdown-shown="onDropdownShown"
    @search-started="search"
    @update-value="updateWorkItemIteration"
  >
    <template #list-item="{ item }">
      <div>
        {{ item.text }}
      </div>
      <div v-if="item.title">{{ item.title }}</div>
    </template>
    <template #readonly>
      <div class="gl-mr-2 gl-text-subtle">
        {{ selectedIterationCadenceName }}
      </div>
      <gl-link
        class="has-popover !gl-text-default"
        :data-iteration="localIterationNumericId"
        :data-namespace-path="fullPath"
        data-reference-type="iteration"
        data-placement="left"
        :href="localIteration.webUrl"
        data-testid="work-item-iteration-link"
      >
        {{ iterationPeriod }}
        <iteration-title v-if="localIteration.title" :title="localIteration.title" />
      </gl-link>
    </template>
  </work-item-sidebar-dropdown-widget>
</template>
