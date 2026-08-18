<script>
import { GlIcon, GlLink, GlTooltipDirective } from '@gitlab/ui';
import IterationTitle from 'ee/iterations/components/iteration_title.vue';
import { getIterationPeriod, groupOptionsByIterationCadences } from 'ee/iterations/utils';
import { TYPE_ISSUE } from '~/issues/constants';
import { IssuableAttributeType } from '../../constants';
import SidebarDropdownWidget from '../sidebar_dropdown_widget.vue';

export default {
  name: 'SidebarIterationWidget',
  issuableAttribute: IssuableAttributeType.Iteration,
  components: {
    GlIcon,
    GlLink,
    SidebarDropdownWidget,
    IterationTitle,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    attrWorkspacePath: {
      required: true,
      type: String,
    },
    iid: {
      required: true,
      type: String,
    },
    issuableType: {
      type: String,
      required: true,
      validator(value) {
        return value === TYPE_ISSUE;
      },
    },
    workspacePath: {
      required: true,
      type: String,
    },
  },
  emits: ['iteration-updated'],
  methods: {
    getCadenceTitle(currentIteration) {
      return currentIteration?.iterationCadence?.title;
    },
    groupOptionsByIterationCadences,
    getIterationPeriod,
  },
};
</script>

<template>
  <sidebar-dropdown-widget
    :attr-workspace-path="attrWorkspacePath"
    :iid="iid"
    :issuable-attribute="$options.issuableAttribute"
    :issuable-type="issuableType"
    :workspace-path="workspacePath"
    :group-by="groupOptionsByIterationCadences"
    @attribute-updated="$emit('iteration-updated', $event)"
  >
    <template #value="{ attributeUrl, currentAttribute }">
      <p class="gl-font-size-sm gl-line-height-21 gl-my-1 gl-text-subtle">
        {{ getCadenceTitle(currentAttribute) }}
      </p>
      <gl-link
        class="gl-leading-20 !gl-text-default"
        :href="attributeUrl"
        data-testid="iteration-link"
      >
        <div>
          <gl-icon name="iteration" class="gl-mr-1" />
          {{ getIterationPeriod(currentAttribute) }}
        </div>
        <iteration-title v-if="currentAttribute.title" :title="currentAttribute.title" />
      </gl-link>
    </template>
    <template #value-collapsed="{ currentAttribute }">
      <div
        v-if="currentAttribute"
        v-gl-tooltip.left.viewport
        :title="__('Iteration')"
        class="sidebar-collapsed-icon"
      >
        <gl-icon :aria-label="__('Iteration')" name="iteration" />
        <span class="collapse-truncated-title gl-px-3 gl-pt-2 gl-text-sm">
          {{ getIterationPeriod(currentAttribute) }}
        </span>
      </div>
    </template>
    <template #group-label="{ group }">
      <span data-testid="cadence-title">{{ group.text }}</span>
    </template>
    <template #list-item="{ item }">
      <span :data-testid="`${$options.issuableAttribute}-items`">
        {{ item.text }}
        <iteration-title v-if="item.title" :title="item.title" />
      </span>
    </template>
  </sidebar-dropdown-widget>
</template>
