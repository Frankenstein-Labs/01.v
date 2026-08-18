<script>
import { debounce } from 'lodash-es';
import produce from 'immer';
import { GlAvatarLabeled, GlButton, GlCollapsibleListbox, GlTooltipDirective } from '@gitlab/ui';
import { visitUrl } from '~/lib/utils/url_utility';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { TYPENAME_GROUP } from '~/graphql_shared/constants';
import { s__ } from '~/locale';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import Api from 'ee/api';
import getGroups from 'ee/security_orchestration/graphql/queries/get_groups_by_ids.query.graphql';
import ConfirmationModal from './confirmation_modal.vue';

export default {
  name: 'CentralizedSecurityPolicyManagement',
  apollo: {
    groups: {
      query: getGroups,
      variables() {
        return {
          search: this.searchValue,
          topLevelOnly: true,
        };
      },
      update(data) {
        return (
          data.groups?.nodes?.map((group) => {
            const id = getIdFromGraphQLId(group.id);
            return {
              ...group,
              id,
              value: id,
              text: group.fullPath,
            };
          }) || []
        );
      },
      result({ data }) {
        this.pageInfo = data.groups?.pageInfo || {};

        // If not searching, select existing group if it exists
        if (!this.searchValue && this.initialSelectedGroupId) {
          this.selectedGroup = this.groups.find(
            (group) => group.id === this.initialSelectedGroupId,
          );

          if (!this.selectedGroup) {
            this.loadMoreGroups(this.initialSelectedGroupId);
          }
        }
      },
    },
  },
  components: {
    ConfirmationModal,
    GlAvatarLabeled,
    GlButton,
    GlCollapsibleListbox,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    centralizedSecurityPolicyGroupLocked: {
      type: Boolean,
      required: true,
    },
    formId: {
      type: String,
      required: true,
    },
    initialSelectedGroupId: {
      type: Number,
      required: false,
      default: null,
    },
    newGroupPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      groups: [],
      pageInfo: {},
      saving: false,
      searchValue: '',
      selectedGroup: null,
    };
  },
  computed: {
    disableSave() {
      return this.centralizedSecurityPolicyGroupLocked || this.loading;
    },
    hasNextPage() {
      return this.pageInfo.hasNextPage;
    },
    loading() {
      return this.$apollo.queries.groups.loading || this.saving;
    },
    selectedGroupId() {
      return this.selectedGroup?.id;
    },
    toggleText() {
      return this.selectedGroup?.fullName || s__('SecurityOrchestration|Select a group');
    },
  },
  created() {
    this.handleSearch = debounce(this.setSearchValue, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  destroyed() {
    this.handleSearch.cancel();
  },
  methods: {
    handleCreateGroup() {
      visitUrl(this.newGroupPath);
    },
    async loadMoreGroups(id) {
      if (!this.hasNextPage) return [];

      try {
        return await this.$apollo.queries.groups.fetchMore({
          variables: {
            ...(id ? { ids: [convertToGraphQLId(TYPENAME_GROUP, id)] } : {}),
            search: this.searchValue,
            after: this.pageInfo.endCursor,
          },
          updateQuery(previousResult, { fetchMoreResult }) {
            return produce(fetchMoreResult, (draftData) => {
              draftData.groups.nodes = [
                ...previousResult.groups.nodes,
                ...fetchMoreResult.groups.nodes,
              ];
            });
          },
        });
      } catch {
        return [];
      }
    },
    setSearchValue(value = '') {
      this.searchValue = value;
    },
    async assignGroup() {
      this.saving = true;
      try {
        await Api.updateCompliancePolicySettings({
          // If no group selected, group will be cleared (null)
          csp_namespace_id: this.selectedGroupId || null,
        });
        document.getElementById(this.formId).submit();
      } catch (error) {
        this.saving = false;
      }
    },
    handleSelect(groupId) {
      this.selectedGroup = this.groups.find((group) => group.id === groupId) || null;
    },
    showModalWindow() {
      if (this.disableSave) return;
      this.$refs.confirmationModal.showModalWindow();
    },
  },
};
</script>

<template>
  <div>
    <gl-collapsible-listbox
      data-testid="exceptions-selector"
      is-check-centered
      searchable
      :header-text="__('Select group')"
      :items="groups"
      :infinite-scroll="hasNextPage"
      :loading="loading"
      :reset-button-label="__('Clear')"
      :selected="selectedGroupId"
      :toggle-text="toggleText"
      @bottom-reached="loadMoreGroups"
      @reset="handleSelect"
      @search="handleSearch"
      @select="handleSelect"
    >
      <template #list-item="{ item }">
        <gl-avatar-labeled
          :entity-name="item.fullName"
          :label="item.fullName"
          :size="32"
          :src="item.avatarUrl"
          :sub-label="item.fullPath"
        />
      </template>

      <template #footer>
        <div
          class="gl-flex gl-flex-col gl-border-t-1 gl-border-t-dropdown-divider !gl-p-2 !gl-pt-0 gl-border-t-solid"
        >
          <gl-button
            category="tertiary"
            class="!gl-mt-2 !gl-justify-start"
            data-testid="create-group-button"
            @click="handleCreateGroup"
          >
            {{ __('New group') }}
          </gl-button>
        </div>
      </template>
    </gl-collapsible-listbox>
    <div>
      <div
        v-gl-tooltip="{
          disabled: !centralizedSecurityPolicyGroupLocked,
          title: s__(
            'SecurityOrchestration|This setting will be locked for 10 minutes after making changes to prevent further performance issues.',
          ),
        }"
        class="gl-inline"
      >
        <gl-button
          data-testid="save-button"
          class="gl-mt-5"
          category="primary"
          variant="confirm"
          :disabled="disableSave"
          @click="showModalWindow"
        >
          {{ s__('SecurityOrchestration|Save changes') }}
        </gl-button>
      </div>
    </div>
    <confirmation-modal ref="confirmationModal" @change="assignGroup" />
  </div>
</template>
