<script>
import {
  GlModal,
  GlCollapsibleListbox,
  GlButton,
  GlModalDirective,
  GlFormGroup,
  GlLink,
} from '@gitlab/ui';
import { debounce } from 'lodash-es';
import { __, s__ } from '~/locale';
import { newGroupPath } from '~/lib/utils/path_helpers/routes';
import searchGroups from 'ee/ai/graphql/search_groups.query.graphql';
import { SEARCH_DEBOUNCE_MS } from '~/vue_shared/components/ref/constants';

export default {
  name: 'GroupSelector',
  components: { GlModal, GlCollapsibleListbox, GlButton, GlFormGroup, GlLink },
  directives: {
    GlModal: GlModalDirective,
  },
  actionCancel: {
    text: __('Cancel'),
  },
  inject: {
    groupFullPath: { default: null },
    newGroupPath: { default: () => newGroupPath() },
  },
  props: {
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['group-selected'],
  data() {
    return {
      shouldFetch: false,
      groups: [],
      selectedGroupId: null,
      searchTerm: '',
      isError: false,
    };
  },
  apollo: {
    groups: {
      query: searchGroups,
      variables() {
        if (this.groupFullPath) {
          return {
            search: this.searchTerm,
            parentPath: this.groupFullPath,
            topLevelOnly: null,
          };
        }

        return {
          search: this.searchTerm,
          topLevelOnly: true,
          parentPath: null,
        };
      },
      skip() {
        return !this.shouldFetch;
      },
      update(data) {
        return data?.groups?.nodes ?? [];
      },
      result() {
        if (this.groups.length > 0) {
          this.isError = false;
        }
      },
      error() {
        this.isError = true;
      },
    },
  },
  computed: {
    isLoadingGroups() {
      return this.$apollo.queries.groups.loading;
    },
    listboxItems() {
      return this.groups.map((item) => ({
        value: item.id,
        text: item.name,
        fullPath: item.fullPath,
      }));
    },
    selectedGroup() {
      return this.groups?.find((group) => group?.id === this.selectedGroupId);
    },
    groupNameText() {
      return this.selectedGroup?.name || s__('AiPowered|Select group');
    },
    actionPrimary() {
      return {
        text: __('Add'),
        attributes: {
          variant: 'confirm',
          disabled: !this.selectedGroupId,
          title: !this.selectedGroupId ? s__('AiPowered|Select a group to continue') : '',
        },
      };
    },
    noResultsText() {
      if (this.isError) {
        return s__('AiPowered|Failed to load groups');
      }

      return s__('AiPowered|No groups found');
    },
  },
  created() {
    this.debouncedSearch = debounce(this.search, SEARCH_DEBOUNCE_MS);
  },
  methods: {
    resetModal() {
      this.selectedGroupId = null;
    },
    onDropdownShown() {
      this.searchTerm = '';
      this.shouldFetch = true;
    },
    search(searchTerm) {
      this.searchTerm = searchTerm;
    },
    addGroup() {
      if (this.selectedGroupId) {
        this.$emit('group-selected', this.selectedGroup);
      }
    },
    itemDisplayText(item) {
      return `${item.text} (${item.fullPath})`;
    },
    onSearch(searchTerm) {
      this.debouncedSearch(searchTerm);
    },
  },
};
</script>
<template>
  <div class="gl-flex gl-items-center gl-gap-3">
    <gl-button v-gl-modal="'group-selector-modal'" category="secondary" :disabled="disabled">
      {{ s__('AiPowered|Add group') }}
    </gl-button>

    <gl-link :href="newGroupPath" target="_blank" rel="noopener noreferrer" class="gl-ml-3">
      {{ s__('AiPowered|Create group') }}
    </gl-link>

    <gl-modal
      modal-id="group-selector-modal"
      size="sm"
      :title="s__('AiPowered|Add group')"
      :aria-label="s__('AiPowered|Add group')"
      :action-primary="actionPrimary"
      :action-cancel="$options.actionCancel"
      @primary="addGroup"
      @hidden="resetModal"
    >
      <gl-form-group :label="__('Group')" label-for="gl-collapsible-listbox-1">
        <gl-collapsible-listbox
          id="gl-collapsible-listbox-1"
          v-model="selectedGroupId"
          :items="listboxItems"
          block
          fluid-width
          searchable
          :searching="isLoadingGroups"
          :toggle-text="groupNameText"
          :no-results-text="noResultsText"
          @shown="onDropdownShown"
          @search="onSearch"
        >
          <template #list-item="{ item }">
            <span class="gl-break-words">{{ itemDisplayText(item) }}</span>
          </template>
        </gl-collapsible-listbox>
      </gl-form-group>
    </gl-modal>
  </div>
</template>
