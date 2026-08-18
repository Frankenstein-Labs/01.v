<script>
import { GlAlert, GlButton, GlDisclosureDropdown, GlIcon, GlModal } from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { STATUS_OPEN, NAMESPACE_GROUP, NAMESPACE_PROJECT } from '~/issues/constants';
import { fetchPolicies } from '~/lib/graphql';
import { __, n__, s__, sprintf } from '~/locale';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { getIterationPeriod } from '../utils';
import { CADENCE_AND_DUE_DATE_DESC, ITERATIONS_PER_PAGE } from '../constants';
import groupQuery from '../queries/group_iterations_in_cadence.query.graphql';
import projectQuery from '../queries/project_iterations_in_cadence.query.graphql';
import TimeboxStatusBadge from './timebox_status_badge.vue';

const i18n = Object.freeze({
  noResults: {
    opened: s__('Iterations|No open iterations.'),
    closed: s__('Iterations|No closed iterations.'),
    all: s__('Iterations|No iterations in cadence.'),
  },
  addIteration: s__('Iterations|Add iteration'),
  error: __('Error loading iterations'),

  deleteCadence: s__('Iterations|Delete cadence'),
  modalTitle: s__('Iterations|Delete iteration cadence?'),
  modalText: s__(
    'Iterations|This will delete the cadence as well as all of the iterations within it.',
  ),
  modalConfirm: s__('Iterations|Delete cadence'),
  modalCancel: __('Cancel'),
});

export default {
  name: 'IterationCadenceListItem',
  i18n,
  components: {
    GlAlert,
    GlButton,
    GlDisclosureDropdown,
    GlIcon,
    GlModal,
    TimeboxStatusBadge,
    CrudComponent,
  },
  apollo: {
    namespace: {
      fetchPolicy: fetchPolicies.NETWORK_ONLY,
      skip() {
        return !this.expanded;
      },
      query() {
        return this.query;
      },
      variables() {
        return this.queryVariables;
      },
      error() {
        this.error = i18n.error;
      },
    },
  },
  inject: ['fullPath', 'canEditCadence', 'canCreateIteration', 'namespaceType'],
  props: {
    title: {
      type: String,
      required: true,
    },
    automatic: {
      type: Boolean,
      required: false,
      default: false,
    },
    durationInWeeks: {
      type: Number,
      required: false,
      default: null,
    },
    cadenceId: {
      type: String,
      required: true,
    },
    iterationState: {
      type: String,
      required: true,
    },
    showStateBadge: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['delete-cadence'],
  data() {
    return {
      i18n,
      expanded: false,
      // query response
      namespace: {
        iterations: {
          nodes: [],
          pageInfo: {
            hasNextPage: true,
          },
        },
      },
      error: '',
    };
  },
  computed: {
    actionItems() {
      const items = [
        {
          text: s__('Iterations|Edit cadence'),
          action: () => this.goTo('edit'),
        },
        {
          text: i18n.deleteCadence,
          action: this.showModal,
          variant: 'danger',
          extraAttrs: {
            'data-testid': 'delete-cadence',
          },
        },
      ];

      if (this.showAddIteration) {
        items.unshift({
          text: i18n.addIteration,
          action: () => this.goTo('newIteration'),
          extraAttrs: {
            'data-testid': 'add-cadence',
          },
        });
      }

      return items;
    },
    query() {
      if (this.namespaceType === NAMESPACE_GROUP) {
        return groupQuery;
      }
      if (this.namespaceType === NAMESPACE_PROJECT) {
        return projectQuery;
      }
      throw new Error('Must provide a namespaceType');
    },
    queryVariables() {
      return {
        fullPath: this.fullPath,
        iterationCadenceId: this.cadenceId,
        firstPageSize: ITERATIONS_PER_PAGE,
        state: this.iterationState,
        sort: this.iterationSortOrder,
      };
    },
    pageInfo() {
      return this.namespace.iterations?.pageInfo || {};
    },
    hasNextPage() {
      return this.pageInfo.hasNextPage;
    },
    iterations() {
      return this.namespace?.iterations?.nodes || [];
    },
    loading() {
      return this.$apollo.queries.namespace.loading;
    },
    showAddIteration() {
      return !this.automatic && this.canCreateIteration;
    },
    showDurationBadget() {
      return this.automatic && this.durationInWeeks;
    },
    iterationSortOrder() {
      return this.iterationState === STATUS_OPEN ? null : CADENCE_AND_DUE_DATE_DESC;
    },
    paginationLegend() {
      return sprintf(
        n__(
          'Iterations|Showing %{count} iteration',
          'Iterations|Showing %{count} iterations',
          this.iterations.length,
        ),
        { count: this.iterations.length },
      );
    },
  },
  created() {
    if (
      `${this.$router.currentRoute?.query.createdCadenceId}` ===
      `${getIdFromGraphQLId(this.cadenceId)}`
    ) {
      this.expanded = true;
    }
  },
  methods: {
    goTo(name) {
      this.$router.push({
        name,
        params: {
          cadenceId: getIdFromGraphQLId(this.cadenceId),
        },
      });
    },
    fetchMore() {
      if (this.iterations.length === 0 || !this.hasNextPage || this.loading) {
        return;
      }

      // Fetch more data and transform the original result
      this.$apollo.queries.namespace.fetchMore({
        variables: {
          ...this.queryVariables,
          afterCursor: this.pageInfo.endCursor,
        },
        // Transform the previous result with new data
        updateQuery: (previousResult, { fetchMoreResult }) => {
          const newIterations = fetchMoreResult.namespace?.iterations.nodes || [];

          return {
            namespace: {
              id: fetchMoreResult.namespace.id,
              __typename: this.namespaceType,
              iterations: {
                __typename: 'IterationConnection',
                // Merging the list
                nodes: [...previousResult.namespace.iterations.nodes, ...newIterations],
                pageInfo: fetchMoreResult.namespace?.iterations.pageInfo || {},
              },
            },
          };
        },
      });
    },
    path(iterationId) {
      return {
        name: 'iteration',
        params: {
          cadenceId: getIdFromGraphQLId(this.cadenceId),
          iterationId: getIdFromGraphQLId(iterationId),
        },
      };
    },
    showModal() {
      this.$refs.modal.show();
    },
    focusMenu() {
      this.$refs.menu.$el.focus();
    },
    getIterationPeriod,
  },
};
</script>
<template>
  <li class="!gl-m-0 !gl-border-b-0 !gl-p-0">
    <gl-alert v-if="error" variant="danger" :dismissible="true" @dismiss="error = ''">
      {{ error }}
    </gl-alert>

    <crud-component
      is-collapsible
      :collapsed="!expanded"
      class="!gl-mt-3"
      header-class="!gl-flex-nowrap"
      title-class="gl-flex-wrap"
      @expanded="expanded = true"
      @collapsed="expanded = false"
    >
      <template #title>
        <gl-button
          variant="link"
          class="gl-grow !gl-no-underline !gl-shadow-none"
          button-text-classes="gl-text-left !gl-whitespace-normal gl-inline-flex gl-flex-wrap gl-justify-between gl-gap-2 gl-w-full"
          tabindex="-1"
          @click="expanded = !expanded"
        >
          <span class="gl-text-strong">{{ title }}</span>
          <span
            v-if="showDurationBadget"
            class="gl-shrink-0 gl-text-sm gl-text-subtle"
            data-testid="duration-badge"
          >
            <gl-icon name="clock" class="gl-mr-2" />
            {{ n__('Every week', 'Every %d weeks', durationInWeeks) }}</span
          >
        </gl-button>
      </template>

      <template #actions>
        <gl-disclosure-dropdown
          v-if="canEditCadence"
          ref="menu"
          size="small"
          category="tertiary"
          data-testid="cadence-options-button"
          icon="ellipsis_v"
          placement="bottom-end"
          no-caret
          text-sr-only
          :items="actionItems"
        />
      </template>

      <template v-if="!iterations || iterations.length === 0" #empty>
        {{ i18n.noResults[iterationState] }}
      </template>

      <template #default>
        <div class="gl-max-h-34 gl-overflow-y-auto">
          <ul class="content-list">
            <li
              v-for="iteration in iterations"
              :key="iteration.id"
              class="!gl-flex gl-flex-wrap gl-items-baseline gl-text-left"
            >
              <router-link
                class="gl-grow"
                :to="path(iteration.id)"
                data-testid="iteration-item"
                :data-qa-title="getIterationPeriod(iteration)"
              >
                {{ getIterationPeriod(iteration) }}
              </router-link>
              <timebox-status-badge v-if="showStateBadge" :state="iteration.state" />
            </li>
          </ul>
          <div v-if="hasNextPage" class="gl-mt-3 gl-flex gl-justify-center">
            <gl-button
              category="tertiary"
              variant="confirm"
              size="small"
              :loading="loading"
              data-testid="load-more-iterations"
              @click="fetchMore"
            >
              {{ __('Load more') }}
            </gl-button>
          </div>
        </div>
        <p
          class="gl-my-3 gl-text-center gl-text-sm gl-text-subtle"
          data-testid="iterations-pagination-legend"
        >
          {{ paginationLegend }}
        </p>
      </template>
    </crud-component>

    <gl-modal
      ref="modal"
      :modal-id="`${cadenceId}-delete-modal`"
      :title="i18n.modalTitle"
      :ok-title="i18n.modalConfirm"
      ok-variant="danger"
      @hidden="focusMenu"
      @ok="$emit('delete-cadence', cadenceId)"
    >
      {{ i18n.modalText }}
    </gl-modal>
  </li>
</template>
