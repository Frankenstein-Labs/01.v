<script>
import { GlButton, GlTooltipDirective } from '@gitlab/ui';
import { s__, __, sprintf } from '~/locale';
import CrudComponent from '~/vue_shared/components/crud_component.vue';

export default {
  name: 'StatusChecksTable',
  i18n: {
    addStatusCheck: s__('BranchRules|Add status check'),
    statusChecksTitle: s__('BranchRules|Status checks'),
    statusChecksEmptyState: s__('BranchRules|No status checks have been added.'),
    editButton: __('Edit'),
    deleteButton: __('Delete'),
    deleteStatusCheckLabel: s__('BranchRules|Delete %{statusCheckName}'),
  },
  components: {
    CrudComponent,
    GlButton,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },

  props: {
    statusChecks: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['open-status-check-delete-modal', 'open-status-check-drawer'],
  methods: {
    getDeleteAriaLabel(name) {
      return sprintf(this.$options.i18n.deleteStatusCheckLabel, {
        statusCheckName: name,
      });
    },
  },
};
</script>

<template>
  <crud-component
    :title="$options.i18n.statusChecksTitle"
    icon="check-circle"
    :count="statusChecks.length"
  >
    <template #actions>
      <gl-button size="small" data-testid="add-btn" @click="$emit('open-status-check-drawer')">
        {{ $options.i18n.addStatusCheck }}
      </gl-button>
    </template>
    <p v-if="!statusChecks.length" class="gl-break-words gl-text-subtle">
      {{ $options.i18n.statusChecksEmptyState }}
    </p>

    <div
      v-for="statusCheck in statusChecks"
      :key="statusCheck.id"
      class="gl-mb-4 gl-flex gl-items-center gl-gap-5 gl-border-t-1 gl-border-default"
    >
      <div class="gl-min-w-0 gl-flex-1">
        <p class="gl-my-0 gl-truncate">{{ statusCheck.name }}</p>
        <p class="gl-my-0 gl-truncate gl-text-subtle">{{ statusCheck.externalUrl }}</p>
      </div>
      <div class="gl-flex gl-gap-2">
        <gl-button
          v-gl-tooltip
          category="tertiary"
          icon="pencil"
          data-testid="edit-btn"
          :title="`${$options.i18n.editButton} ${statusCheck.name}`"
          :aria-label="`${$options.i18n.editButton} ${statusCheck.name}`"
          @click="$emit('open-status-check-drawer', statusCheck)"
        />
        <gl-button
          v-gl-tooltip
          category="tertiary"
          icon="remove"
          data-testid="delete-btn"
          :title="$options.i18n.deleteButton"
          :aria-label="getDeleteAriaLabel(statusCheck.name)"
          @click="$emit('open-status-check-delete-modal', statusCheck)"
        />
      </div>
    </div>
  </crud-component>
</template>
