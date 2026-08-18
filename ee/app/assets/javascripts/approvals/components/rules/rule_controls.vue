<script>
import { GlButton, GlTooltipDirective } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions } from 'vuex';
import { __, sprintf } from '~/locale';

export default {
  name: 'RuleControls',
  i18n: {
    edit: __('Edit'),
    remove: __('Delete'),
    editItemLabel: __('Edit %{ruleName}'),
    removeItemLabel: __('Delete %{ruleName}'),
  },
  components: {
    GlButton,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    rule: {
      type: Object,
      required: true,
    },
  },
  computed: {
    editAriaLabel() {
      return sprintf(this.$options.i18n.editItemLabel, {
        ruleName: this.rule.name,
      });
    },
    deleteAriaLabel() {
      return sprintf(this.$options.i18n.removeItemLabel, {
        ruleName: this.rule.name,
      });
    },
  },
  methods: {
    ...mapActions(['requestEditRule', 'requestDeleteRule']),
  },
};
</script>

<template>
  <div class="!-gl-my-3 gl-pr-5 gl-text-right">
    <gl-button
      v-gl-tooltip
      category="tertiary"
      icon="pencil"
      :title="$options.i18n.edit"
      :aria-label="editAriaLabel"
      data-testid="edit-rule-button"
      @click="requestEditRule(rule)"
    />
    <gl-button
      v-gl-tooltip
      class="gl-ml-2"
      category="tertiary"
      icon="remove"
      :title="$options.i18n.remove"
      :aria-label="deleteAriaLabel"
      data-testid="delete-rule-button"
      @click="requestDeleteRule(rule)"
    />
  </div>
</template>
