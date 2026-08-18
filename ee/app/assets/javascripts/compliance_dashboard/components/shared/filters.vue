<script>
import { GlButton, GlFilteredSearch, GlPopover } from '@gitlab/ui';

import { __, s__ } from '~/locale';
import GroupToken from '~/vue_shared/components/filtered_search_bar/tokens/group_token.vue';

import {
  FRAMEWORKS_FILTER_TYPE_FRAMEWORK,
  FRAMEWORKS_FILTER_TYPE_PROJECT,
  FRAMEWORKS_FILTER_TYPE_GROUP,
  FRAMEWORKS_FILTER_TYPE_PROJECT_STATUS,
} from '../../constants';
import ProjectSearchToken from './filter_tokens/project_search_token.vue';
import ProjectStatusToken from './filter_tokens/project_status_token.vue';
import ComplianceFrameworkToken from './filter_tokens/compliance_framework_token.vue';

export default {
  name: 'ComplianceSharedFilters',
  components: {
    GlButton,
    GlFilteredSearch,
    GlPopover,
  },
  props: {
    value: {
      type: Array,
      required: false,
      default: () => [],
    },
    groupPath: {
      type: String,
      required: true,
    },
    showUpdatePopover: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['submit', 'update-popover-hidden'],
  computed: {
    filterTokens() {
      return [
        {
          icon: 'shield',
          title: s__('ComplianceReport|Compliance framework'),
          type: FRAMEWORKS_FILTER_TYPE_FRAMEWORK,
          entityType: 'framework',
          token: ComplianceFrameworkToken,
          groupPath: this.groupPath,
          includeNoFramework: true,
        },
        {
          unique: true,
          icon: 'project',
          title: __('Project'),
          type: FRAMEWORKS_FILTER_TYPE_PROJECT,
          entityType: 'project',
          token: ProjectSearchToken,
          operators: [{ value: 'matches', description: 'matches' }],
        },
        {
          unique: true,
          icon: 'group',
          title: __('Group'),
          type: FRAMEWORKS_FILTER_TYPE_GROUP,
          entityType: 'groupPath',
          token: GroupToken,
          fullPath: this.groupPath,
          skipIdPrefix: true,
          operators: [{ value: 'matches', description: 'matches' }],
        },
        {
          unique: true,
          icon: 'archive',
          title: __('Project Status'),
          type: FRAMEWORKS_FILTER_TYPE_PROJECT_STATUS,
          entityType: 'project_status',
          token: ProjectStatusToken,
          fullPath: this.groupPath,
        },
      ];
    },
  },
  methods: {
    onFilterSubmit(newFilters) {
      this.$emit('submit', newFilters ?? this.value);
    },
    handleFilterClear() {
      this.$emit('submit', []);
    },
  },
  i18n: {
    placeholder: __('Search or filter results…'),
    updatePopoverTitle: s__('ComplianceReport|Update filtered results?'),
    updatePopoverContent: s__(
      'ComplianceReport|Do you want to refresh the filtered results to include your change?',
    ),
    updatePopoverAction: s__('ComplianceReport|Update result'),
  },
};
</script>

<template>
  <div class="row-content-block gl-relative gl-border-0">
    <gl-popover
      ref="popover"
      :target="() => $refs.popoverTarget"
      :show="showUpdatePopover"
      show-close-button
      placement="bottomright"
      triggers="manual"
      :title="$options.i18n.updatePopoverTitle"
      @hidden="$emit('update-popover-hidden')"
    >
      {{ $options.i18n.updatePopoverContent }}
      <div class="gl-mt-4">
        <gl-button size="small" category="primary" variant="confirm" @click="onFilterSubmit()">
          {{ $options.i18n.updatePopoverAction }}
        </gl-button>
        <gl-button
          size="small"
          category="secondary"
          variant="reset"
          @click="$refs.popover.$emit('close')"
        >
          {{ __('Dismiss') }}
        </gl-button>
      </div>
    </gl-popover>
    <span ref="popoverTarget" class="gl-pointer-events-none gl-absolute gl-ml-5 gl-h-7">
      &nbsp;
    </span>
    <gl-filtered-search
      :value="value"
      :placeholder="$options.i18n.placeholder"
      :available-tokens="filterTokens"
      @submit="onFilterSubmit"
      @clear="handleFilterClear"
    />
  </div>
</template>
