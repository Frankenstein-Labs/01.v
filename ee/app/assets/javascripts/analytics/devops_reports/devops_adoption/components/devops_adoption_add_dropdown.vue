<script>
import { GlCollapsibleListbox, GlTooltipDirective } from '@gitlab/ui';
import { debounce } from 'lodash-es';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { TYPENAME_GROUP } from '~/graphql_shared/constants';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import {
  DEBOUNCE_DELAY,
  I18N_GROUP_DROPDOWN_TEXT,
  I18N_GROUP_DROPDOWN_HEADER,
  I18N_ADMIN_DROPDOWN_TEXT,
  I18N_ADMIN_DROPDOWN_HEADER,
  I18N_NO_RESULTS,
  I18N_NO_SUB_GROUPS,
} from '../constants';
import bulkEnableDevopsAdoptionNamespacesMutation from '../graphql/mutations/bulk_enable_devops_adoption_namespaces.mutation.graphql';
import disableDevopsAdoptionNamespaceMutation from '../graphql/mutations/disable_devops_adoption_namespace.mutation.graphql';

export default {
  name: 'DevopsAdoptionAddDropdown',
  i18n: {
    noResults: I18N_NO_RESULTS,
  },
  components: {
    GlCollapsibleListbox,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: {
    isGroup: {
      default: false,
    },
    groupGid: {
      default: null,
    },
  },
  props: {
    groups: {
      type: Array,
      required: true,
    },
    isLoadingGroups: {
      type: Boolean,
      required: false,
      default: false,
    },
    hasSubgroups: {
      type: Boolean,
      required: false,
      default: false,
    },
    enabledNamespaces: {
      type: Object,
      required: false,
      default: () => ({ nodes: [] }),
    },
  },
  emits: [
    'enabled-namespaces-added',
    'enabled-namespaces-removed',
    'fetch-groups',
    'track-modal-open-state',
  ],
  computed: {
    dropdownTitle() {
      return this.isGroup ? I18N_GROUP_DROPDOWN_TEXT : I18N_ADMIN_DROPDOWN_TEXT;
    },
    dropdownHeader() {
      return this.isGroup ? I18N_GROUP_DROPDOWN_HEADER : I18N_ADMIN_DROPDOWN_HEADER;
    },
    tooltipText() {
      return this.isLoadingGroups || this.hasSubgroups ? false : I18N_NO_SUB_GROUPS;
    },
    enabledNamespaceIds() {
      return this.enabledNamespaces.nodes.map((enabledNamespace) =>
        getIdFromGraphQLId(enabledNamespace.namespace.id),
      );
    },
    groupsItems() {
      return this.groups?.map((group) => {
        return {
          value: group.id,
          text: group.full_name,
        };
      });
    },
  },
  beforeDestroy() {
    clearTimeout(this.timeout);
    this.timeout = null;
  },
  methods: {
    namespaceIdByGroupId(groupId) {
      return this.enabledNamespaces.nodes?.find(
        (enabledNamespace) => getIdFromGraphQLId(enabledNamespace.namespace.id) === groupId,
      ).id;
    },
    handleGroupSelect(selected) {
      const newlySelected = selected.filter((item) => !this.enabledNamespaceIds.includes(item));
      const newlyRemoved = this.enabledNamespaceIds.filter((item) => !selected.includes(item));

      this.enableGroup(newlySelected);
      this.disableGroup(newlyRemoved);
    },
    enableGroup(ids) {
      if (!ids?.length) return;

      const preparedIds = ids.map((id) => {
        return convertToGraphQLId(TYPENAME_GROUP, id);
      });

      this.$apollo
        .mutate({
          mutation: bulkEnableDevopsAdoptionNamespacesMutation,
          variables: {
            namespaceIds: preparedIds,
            displayNamespaceId: this.groupGid,
          },
          update: (store, { data }) => {
            const {
              bulkEnableDevopsAdoptionNamespaces: { enabledNamespaces, errors: requestErrors },
            } = data;

            if (!requestErrors.length) this.$emit('enabled-namespaces-added', enabledNamespaces);
          },
        })
        .catch((error) => {
          Sentry.captureException(error);
        });
    },
    disableGroup(ids) {
      if (!ids?.length) return;

      const preparedIds = ids.map((id) => {
        return this.namespaceIdByGroupId(id);
      });

      this.$apollo
        .mutate({
          mutation: disableDevopsAdoptionNamespaceMutation,
          variables: {
            id: preparedIds,
          },
          update: () => {
            this.$emit('enabled-namespaces-removed', preparedIds);
          },
        })
        .catch((error) => {
          Sentry.captureException(error);
        });
    },
    debouncedSearch: debounce(async function debouncedSearch($event) {
      this.$emit('fetch-groups', $event);
    }, DEBOUNCE_DELAY),
  },
};
</script>
<template>
  <gl-collapsible-listbox
    v-gl-tooltip="tooltipText"
    class="gl-text-left"
    searchable
    multiple
    :toggle-text="dropdownTitle"
    :header-text="dropdownHeader"
    :search-placeholder="__('Search')"
    :no-results-text="$options.i18n.noResults"
    :selected="enabledNamespaceIds"
    :items="groupsItems"
    :disabled="!hasSubgroups"
    :loading="isLoadingGroups"
    @select="handleGroupSelect"
    @search="debouncedSearch"
    @shown="$emit('track-modal-open-state', true)"
    @hidden="$emit('track-modal-open-state', false)"
  />
</template>
