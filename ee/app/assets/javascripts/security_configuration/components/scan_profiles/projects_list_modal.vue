<script>
import { GlModal, GlLoadingIcon, GlKeysetPagination, GlLink, GlIcon } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_GROUP } from '~/graphql_shared/constants';
import NameCell from 'ee/security_inventory/components/name_cell.vue';
import projectsByScannerStatusQuery from 'ee/security_configuration/graphql/scan_profiles/projects_by_scanner_status.query.graphql';

const PAGE_SIZE = 20;

export default {
  name: 'ProjectsListModal',
  components: {
    GlModal,
    GlLoadingIcon,
    GlKeysetPagination,
    GlLink,
    GlIcon,
    NameCell,
  },
  inject: ['groupId'],
  props: {
    filters: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    title: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['hidden'],
  data() {
    return {
      namespaceSecurityProjects: {},
      visible: false,
      after: null,
      before: null,
    };
  },
  apollo: {
    namespaceSecurityProjects: {
      query: projectsByScannerStatusQuery,
      variables() {
        return {
          namespaceId: convertToGraphQLId(TYPENAME_GROUP, this.groupId),
          ...this.filters,
          first: this.after || !this.before ? PAGE_SIZE : null,
          after: this.after,
          last: this.before ? PAGE_SIZE : null,
          before: this.before,
        };
      },
      update: (data) => data?.namespaceSecurityProjects ?? {},
      skip() {
        return !this.visible;
      },
      error() {
        createAlert({
          message: s__('SecurityConfiguration|Failed to load projects'),
        });
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.namespaceSecurityProjects.loading;
    },
    projects() {
      return this.namespaceSecurityProjects.nodes ?? [];
    },
    pageInfo() {
      return this.namespaceSecurityProjects.pageInfo ?? {};
    },
    hasPagination() {
      return Boolean(this.pageInfo.hasNextPage || this.pageInfo.hasPreviousPage);
    },
  },
  methods: {
    // eslint-disable-next-line vue/no-unused-properties
    show() {
      this.after = null;
      this.before = null;
      this.visible = true;
    },
    handleNext(endCursor) {
      this.after = endCursor;
      this.before = null;
    },
    handlePrev(startCursor) {
      this.before = startCursor;
      this.after = null;
    },
    handleHidden() {
      this.visible = false;
      this.$emit('hidden');
    },
  },
  modalId: 'group-scanners-projects-modal',
  i18n: {
    title: s__('SecurityConfiguration|Projects'),
    viewProject: s__('SecurityConfiguration|View project'),
    noProjects: s__('SecurityConfiguration|No projects found'),
  },
};
</script>

<template>
  <gl-modal
    :modal-id="$options.modalId"
    :visible="visible"
    :title="title || $options.i18n.title"
    header-class="gl-mx-5 gl-px-0 gl-py-5 gl-divide-x-0 !gl-border-b !gl-border-subtle"
    footer-class="gl-mx-5 gl-px-0 gl-py-5 gl-divide-x-0 !gl-border-t !gl-border-subtle"
    :hide-footer="!hasPagination"
    @hidden="handleHidden"
  >
    <gl-loading-icon v-if="isLoading" size="lg" />
    <p v-else-if="!projects.length" class="gl-my-4 gl-text-center gl-text-subtle">
      {{ $options.i18n.noProjects }}
    </p>
    <template v-else>
      <ul
        class="gl-mb-0 gl-flex gl-list-none gl-flex-col gl-divide-x-0 gl-divide-y-1 gl-divide-solid gl-divide-subtle gl-px-4"
      >
        <li
          v-for="project in projects"
          :key="project.id"
          class="gl-flex gl-items-center gl-justify-between gl-gap-3 gl-py-3"
        >
          <name-cell :item="project" show-search-param hide-icons class="gl-min-w-0" />
          <gl-link
            :href="project.webPath"
            target="_blank"
            class="gl-flex gl-shrink-0 gl-items-center gl-gap-2 gl-whitespace-nowrap"
          >
            {{ $options.i18n.viewProject }}
            <gl-icon name="external-link" :size="12" />
          </gl-link>
        </li>
      </ul>
    </template>
    <template #modal-footer>
      <div v-if="hasPagination" class="gl-flex gl-w-full gl-justify-center">
        <gl-keyset-pagination v-bind="pageInfo" @prev="handlePrev" @next="handleNext" />
      </div>
    </template>
  </gl-modal>
</template>
