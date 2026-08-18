<script>
import { GlSearchBoxByType } from '@gitlab/ui';
import { setLocationHash } from '~/lib/utils/url_utility';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import TooltipOnTruncate from '~/vue_shared/directives/tooltip_on_truncate';
import PanelResizer from '~/vue_shared/components/panel_resizer.vue';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import ProjectAvatar from '~/vue_shared/components/project_avatar.vue';
import {
  SIDEBAR_WIDTH_INITIAL,
  SIDEBAR_WIDTH_MINIMUM,
  SIDEBAR_WIDTH_STORAGE_KEY,
} from '../../constants';
import SubgroupsQuery from '../../graphql/subgroups.query.graphql';
import GroupList from './group_list.vue';

export default {
  components: {
    GroupList,
    PanelResizer,
    LocalStorageSync,
    ProjectAvatar,
    GlSearchBoxByType,
  },
  directives: {
    TooltipOnTruncate,
  },
  inject: ['groupFullPath'],
  props: {
    activeFullPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      group: {
        name: '',
      },
      search: '',
      panelWidth: SIDEBAR_WIDTH_INITIAL,
    };
  },
  apollo: {
    group: {
      query: SubgroupsQuery,
      client: 'appendGroupsClient',
      variables() {
        return {
          fullPath: this.groupFullPath,
        };
      },
      error(error) {
        createAlert({
          message: s__(
            'SecurityInventory|An error occurred while fetching subgroups. Please try again.',
          ),
          error,
          captureError: true,
        });
        Sentry.captureException(error);
      },
    },
  },
  computed: {
    isActiveGroup() {
      return this.groupFullPath === this.activeFullPath;
    },
  },
  methods: {
    onSizeUpdate(value) {
      this.panelWidth = value;
    },
    selectSubgroup(subgroupFullPath) {
      setLocationHash(subgroupFullPath);
    },
  },
  SIDEBAR_WIDTH_MINIMUM,
  SIDEBAR_WIDTH_STORAGE_KEY,
};
</script>
<template>
  <div
    :style="{
      width: `${panelWidth}px`,
      minWidth: `${panelWidth}px`,
      maxWidth: `${panelWidth}px`,
      boxSizing: 'border-box',
    }"
    data-testid="panel"
  >
    <div
      class="gl-relative gl-h-full gl-border-r-1 gl-border-neutral-100 gl-pr-2 gl-pt-5 gl-border-r-solid"
    >
      <local-storage-sync
        v-model="panelWidth"
        :storage-key="$options.SIDEBAR_WIDTH_STORAGE_KEY"
        @input="onSizeUpdate"
      />
      <panel-resizer
        :start-size="panelWidth"
        :min-size="$options.SIDEBAR_WIDTH_MINIMUM"
        side="right"
        @update:size="onSizeUpdate"
      />

      <div class="gl-sticky gl-top-10 gl-h-screen gl-overflow-auto gl-pb-10 gl-pr-3">
        <gl-search-box-by-type
          v-model.trim="search"
          :placeholder="s__('SecurityInventory|Search subgroups (3 char min)')"
          class="gl-m-2"
        />

        <div
          class="gl-relative gl-ml-1 gl-mt-6 gl-flex gl-h-8 gl-cursor-pointer gl-items-center gl-gap-4 gl-rounded-base gl-px-3 hover:!gl-bg-status-neutral"
          tabindex="0"
          role="button"
          :class="{ 'gl-bg-strong': isActiveGroup }"
          @click="selectSubgroup(group.fullPath)"
          @keydown.enter.space.prevent="selectSubgroup(group.fullPath)"
        >
          <project-avatar
            :project-name="group.name"
            :project-avatar-url="group.avatarUrl"
            :size="24"
          />
          <div
            v-tooltip-on-truncate="group.name"
            class="gl-grow gl-overflow-hidden gl-text-ellipsis gl-whitespace-nowrap"
          >
            {{ group.name }}
          </div>
        </div>
        <group-list
          :group-full-path="groupFullPath"
          :active-full-path="activeFullPath"
          :search="search"
          @select-subgroup="selectSubgroup"
        />
      </div>
    </div>
  </div>
</template>
