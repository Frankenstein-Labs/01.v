<script>
import { defineAsyncComponent } from 'vue';
import { GlBadge, GlButton, GlIcon } from '@gitlab/ui';
import TooltipOnTruncate from '~/vue_shared/directives/tooltip_on_truncate';
import { SIDEBAR_INDENTATION_INCREMENT } from '../../constants';

export default {
  components: {
    GlBadge,
    GlButton,
    GlIcon,
    GroupList: defineAsyncComponent(() => import('./group_list.vue')),
  },
  directives: {
    TooltipOnTruncate,
  },
  props: {
    group: {
      type: Object,
      required: true,
    },
    activeFullPath: {
      type: String,
      required: false,
      default: '',
    },
    indentation: {
      type: Number,
      required: false,
      default: 0,
    },
    hasSearch: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['select-subgroup'],
  data() {
    return {
      expanded: false,
    };
  },
  computed: {
    isActiveGroup() {
      return this.activeFullPath === this.group.fullPath;
    },
    containsActiveGroup() {
      return this.activeFullPath.startsWith(`${this.group.fullPath}/`);
    },
    showExpandButton() {
      return this.group.descendantGroupsCount && !this.hasSearch;
    },
  },
  watch: {
    activeFullPath() {
      this.expandIfContainsActiveGroup();
    },
  },
  mounted() {
    this.expandIfContainsActiveGroup();
  },
  methods: {
    toggleExpanded(event) {
      event.stopPropagation();
      this.expanded = !this.expanded;
    },
    selectSubgroup(subgroupFullPath) {
      this.$emit('select-subgroup', subgroupFullPath);
    },
    expandIfContainsActiveGroup() {
      if (this.containsActiveGroup) this.expanded = true;
    },
  },
  SIDEBAR_INDENTATION_INCREMENT,
};
</script>
<template>
  <div>
    <div
      class="gl-relative gl-m-1 gl-flex gl-h-8 gl-cursor-pointer gl-items-center gl-gap-4 gl-rounded-base gl-px-3 hover:!gl-bg-status-neutral"
      :class="{ 'gl-bg-strong': isActiveGroup }"
      data-testid="subgroup"
      :style="{ left: `${indentation}px` }"
      tabindex="0"
      role="button"
      @click="selectSubgroup(group.fullPath)"
      @keydown.enter.space.prevent="selectSubgroup(group.fullPath)"
    >
      <gl-icon name="subgroup" variant="subtle" class="gl-mx-2 gl-shrink-0" />
      <div
        v-tooltip-on-truncate="group.name"
        class="gl-grow gl-overflow-hidden gl-text-ellipsis gl-whitespace-nowrap"
        data-testid="subgroup-name"
      >
        {{ group.name }}
      </div>

      <div class="gl-sticky gl-right-0 gl-float-right gl-flex gl-gap-4">
        <gl-badge v-if="group.projectsCount" icon="project">
          {{ group.projectsCount }}
        </gl-badge>

        <gl-button
          v-if="showExpandButton"
          :icon="expanded ? 'chevron-down' : 'chevron-right'"
          :aria-label="expanded ? __('Collapse') : __('Expand')"
          category="tertiary"
          size="small"
          icon-only
          @click="toggleExpanded"
          @keydown.enter.space.prevent="toggleExpanded"
        />
      </div>
    </div>
    <group-list
      v-if="expanded && !hasSearch"
      :group-full-path="group.fullPath"
      :active-full-path="activeFullPath"
      :selected-subgroup="activeFullPath"
      :indentation="indentation + $options.SIDEBAR_INDENTATION_INCREMENT"
      @select-subgroup="selectSubgroup"
    />
  </div>
</template>
