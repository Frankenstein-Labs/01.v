<script>
import { GlIcon, GlTooltipDirective } from '@gitlab/ui';
import { s__ } from '~/locale';
import { isDefaultMode } from 'ee/security_orchestration/components/utils';
import { DEFAULT_PROJECT_TEXT } from 'ee/security_orchestration/components/policy_drawer/constants';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import ToggleList from './toggle_list.vue';

export default {
  name: 'ScopeDefaultLabel',
  i18n: {
    allGroupText: s__('SecurityOrchestration|All projects in the group.'),
    allProjectText: s__('SecurityOrchestration|All projects linked to security policy project.'),
    projectDefaultText: DEFAULT_PROJECT_TEXT,
    defaultModeText: s__('SecurityOrchestration|Default mode'),
  },
  components: {
    GlIcon,
    ToggleList,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    isGroup: {
      type: Boolean,
      required: false,
      default: false,
    },
    policyScope: {
      type: Object,
      required: false,
      default: null,
    },
    linkedItems: {
      type: Array,
      required: false,
      default: () => [],
    },
    itemsToShow: {
      type: Number,
      required: false,
      default: 0,
    },
  },
  computed: {
    isDefaultMode() {
      return isDefaultMode(this.policyScope);
    },
    showDefaultMode() {
      return this.isDefaultMode && this.isGroup;
    },
    showDefaultModeForProject() {
      return this.isDefaultMode && !this.isGroup;
    },
    listItems() {
      return this.linkedItems.map(this.formatProjectGroupName);
    },
  },
  methods: {
    /**
     * Returns project name for project and group name and identifier Group for group
     * So user can see difference between group and project in ul list
     * @param name
     * @param id included type Project or Group
     * @returns {string}
     */
    formatProjectGroupName({ name, id }) {
      return id.toLowerCase().includes(NAMESPACE_TYPES.GROUP)
        ? `${name} - ${NAMESPACE_TYPES.GROUP}`
        : name;
    },
  },
};
</script>

<template>
  <div v-if="showDefaultMode" class="gl-flex gl-items-center gl-gap-3 gl-text-subtle">
    <span>{{ $options.i18n.defaultModeText }}</span>
    <gl-icon v-gl-tooltip name="status_warning" :title="$options.i18n.allGroupText" />
  </div>
  <div v-else-if="showDefaultModeForProject">
    <p class="gl-m-0 gl-mb-3">
      {{ $options.i18n.allProjectText }}
    </p>

    <toggle-list
      v-if="linkedItems.length"
      :bullet-style="true"
      :default-close-button-text="$options.i18n.hideProjectsButtonText"
      :items="listItems"
      :items-to-show="itemsToShow"
    />
  </div>
  <p v-else class="gl-m-0 gl-text-subtle">
    {{ $options.i18n.projectDefaultText }}
  </p>
</template>
