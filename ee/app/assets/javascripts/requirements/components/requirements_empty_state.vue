<script>
import { GlEmptyState, GlButton } from '@gitlab/ui';
import { __ } from '~/locale';

import { filterState, filterStateEmptyMessage } from '../constants';

export default {
  name: 'RequirementsEmptyState',
  components: {
    GlEmptyState,
    GlButton,
  },
  props: {
    filterBy: {
      type: String,
      required: true,
    },
    emptyStatePath: {
      type: String,
      required: true,
    },
    requirementsCount: {
      type: Object,
      required: true,
    },
    canCreateRequirement: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['click-import-requirements', 'click-new-requirement'],
  computed: {
    emptyStateTitle() {
      return this.requirementsCount[filterState.all]
        ? filterStateEmptyMessage[this.filterBy]
        : __('With requirements, you can set criteria to check your products against');
    },
    emptyStateDescription() {
      return !this.requirementsCount[filterState.all]
        ? __(
            `Requirements can be based on users, stakeholders, system, software,
            or anything else you find important to capture.`,
          )
        : null;
    },
  },
};
</script>

<template>
  <gl-empty-state
    :svg-path="emptyStatePath"
    :title="emptyStateTitle"
    :description="emptyStateDescription"
    data-testid="requirements-empty-state"
  >
    <template v-if="emptyStateDescription && canCreateRequirement" #actions>
      <gl-button
        class="gl-mx-2 gl-mb-3"
        category="primary"
        variant="confirm"
        @click="$emit('click-new-requirement')"
        >{{ __('New requirement') }}</gl-button
      >
      <gl-button
        class="gl-mx-2 gl-mb-3"
        category="secondary"
        variant="default"
        @click="$emit('click-import-requirements')"
      >
        {{ __('Import requirements') }}
      </gl-button>
    </template>
  </gl-empty-state>
</template>
