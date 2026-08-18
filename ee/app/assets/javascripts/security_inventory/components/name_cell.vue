<script>
import { GlIcon, GlLink, GlTooltipDirective, GlTruncate } from '@gitlab/ui';
import ProjectAvatar from '~/vue_shared/components/project_avatar.vue';
import { sprintf, n__, __ } from '~/locale';
import { isSubGroup } from '../utils';

export default {
  components: {
    GlIcon,
    GlLink,
    GlTruncate,
    ProjectAvatar,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
    showSearchParam: {
      type: Boolean,
      required: false,
      default: false,
    },
    subgroupHref: {
      type: String,
      required: false,
      default: '',
    },
    hideIcons: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    componentName() {
      return isSubGroup(this.item) ? GlLink : 'div';
    },
    pathComponent() {
      return this.subgroupHref ? GlLink : 'div';
    },
    linkHref() {
      return isSubGroup(this.item) && this.item.fullPath ? `#${this.item.fullPath}` : undefined;
    },
    fullPath() {
      const parentWithSpaces = this.parentPath.split('/').join(' / ');
      return !isSubGroup(this.item) ? parentWithSpaces : '';
    },
    parentPath() {
      const lastSlashIndex = this.item.fullPath?.lastIndexOf('/');
      return this.item.fullPath?.substring(0, lastSlashIndex);
    },
    showFullPath() {
      return this.showSearchParam && this.fullPath;
    },
  },
  methods: {
    isSubGroup,
    iconName(item) {
      return this.isSubGroup(item) ? 'subgroup' : 'project';
    },
    projectAndSubgroupCountText(item) {
      const projectsCount = n__('%d project', '%d projects', item.projectsCount || 0);
      const subGroupsCount = n__('%d subgroup', '%d subgroups', item.descendantGroupsCount || 0);

      return sprintf(__('%{projectsCount}, %{subGroupsCount}'), {
        projectsCount,
        subGroupsCount,
      });
    },
  },
};
</script>

<template>
  <component
    :is="componentName"
    class="gl-flex gl-items-start !gl-text-default hover:gl-no-underline focus-visible:gl-no-underline focus-visible:gl-outline-none"
    :href="linkHref"
    :aria-label="isSubGroup(item) ? `Open subgroup ${item.name}` : undefined"
  >
    <div class="gl-flex gl-items-center">
      <gl-icon
        v-if="!hideIcons"
        :name="iconName(item)"
        variant="subtle"
        class="gl-mr-4 gl-shrink-0"
      />
      <project-avatar
        class="gl-mr-4"
        :project-id="item.id"
        :project-name="item.name"
        :project-avatar-url="item.avatarUrl"
      />
    </div>
    <div class="gl-flex gl-flex-col gl-self-center gl-overflow-hidden">
      <span class="gl-text-base gl-font-bold gl-wrap-anywhere" data-testid="name-cell-item-name">{{
        item.name
      }}</span>
      <span v-if="isSubGroup(item)" class="gl-text-sm gl-font-normal gl-text-subtle">
        {{ projectAndSubgroupCountText(item) }}
      </span>
      <component
        :is="pathComponent"
        v-if="showFullPath"
        v-gl-tooltip.hover.top="fullPath"
        :href="subgroupHref || undefined"
        data-testid="name-cell-item-path"
      >
        <gl-truncate
          :text="fullPath"
          position="middle"
          class="gl-text-sm"
          :class="subgroupHref ? 'gl-cursor-pointer gl-text-link' : 'gl-text-subtle'"
        />
      </component>
    </div>
  </component>
</template>
