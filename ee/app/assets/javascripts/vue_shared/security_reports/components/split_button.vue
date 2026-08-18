<script>
import {
  GlButtonGroup,
  GlButton,
  GlCollapsibleListbox,
  GlBadge,
  GlTooltipDirective as GlTooltip,
} from '@gitlab/ui';
import { __ } from '~/locale';
import { visitUrl } from '~/lib/utils/url_utility';

export default {
  name: 'SplitButton',
  components: {
    GlButtonGroup,
    GlButton,
    GlCollapsibleListbox,
    GlBadge,
  },
  directives: {
    GlTooltip,
  },
  props: {
    buttons: {
      type: Array,
      required: true,
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['create-issue', 'create-jira-issue', 'create-merge-request', 'download-patch'],
  data() {
    return {
      selectedButtonIndex: 0,
    };
  },
  computed: {
    selectedButton() {
      return this.buttons[this.selectedButtonIndex];
    },
    items() {
      return this.buttons.map((button, index) => ({ ...button, value: index }));
    },
    category() {
      const { category } = this.selectedButton;

      if (category) {
        return category;
      }

      if (this.buttons.length > 1) {
        return 'primary';
      }

      return 'secondary';
    },
  },
  methods: {
    handleClick() {
      if (this.selectedButton.href) {
        visitUrl(this.selectedButton.href, true);
      } else {
        this.$emit(this.selectedButton.action);
      }
    },
  },
  i18n: {
    changeAction: __('Change action'),
  },
};
</script>

<template>
  <gl-button-group v-if="selectedButton">
    <gl-button
      :key="selectedButton.name"
      v-gl-tooltip
      :title="selectedButton.tooltip"
      :aria-label="selectedButton.tooltip"
      variant="confirm"
      :category="category"
      :href="selectedButton.href"
      :icon="selectedButton.icon"
      :loading="loading"
      :data-testid="`${selectedButton.action}-button`"
      @click="handleClick"
    >
      {{ selectedButton.name }}
      <gl-badge v-if="selectedButton.badge" class="gl-ml-1" variant="info">
        {{ selectedButton.badge }}
      </gl-badge>
    </gl-button>
    <gl-collapsible-listbox
      v-if="buttons.length > 1"
      v-model="selectedButtonIndex"
      variant="confirm"
      text-sr-only
      :toggle-text="$options.i18n.changeAction"
      :disabled="loading"
      :items="items"
    >
      <template #list-item="{ item }">
        <div :data-testid="`${item.action}-button`">
          <strong>
            {{ item.name }}
          </strong>
          <p class="gl-m-0">
            {{ item.tagline }}
            <gl-badge v-if="item.badge" variant="info">{{ item.badge }}</gl-badge>
          </p>
        </div>
      </template>
    </gl-collapsible-listbox>
  </gl-button-group>
</template>
