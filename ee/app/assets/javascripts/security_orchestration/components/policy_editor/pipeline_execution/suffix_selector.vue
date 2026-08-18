<script>
import { GlCollapsibleListbox, GlSprintf, GlIcon, GlTooltipDirective } from '@gitlab/ui';
import { s__ } from '~/locale';
import { SUFFIX_LIST_BOX_ITEMS, SUFFIX_ITEMS, SUFFIX_ON_CONFLICT } from './constants';

export default {
  SUFFIX_LIST_BOX_ITEMS,
  i18n: {
    suffixLabel: s__('SecurityOrchestration|Add job name suffix %{suffixEditor} %{suffixIcon}'),
    suffixPlaceholder: s__('SecurityOrchestration|Select suffix'),
    suffixInfoText: s__('SecurityOrchestration|Add a numeric suffix to ensure unique job names.'),
  },
  name: 'SuffixSelector',
  directives: { GlTooltip: GlTooltipDirective },
  components: {
    GlCollapsibleListbox,
    GlIcon,
    GlSprintf,
  },
  props: {
    suffix: {
      type: String,
      required: false,
      default: SUFFIX_ON_CONFLICT,
    },
  },
  emits: ['update'],
  computed: {
    toggleText() {
      return SUFFIX_ITEMS[this.suffix] || this.$options.i18n.suffixPlaceholder;
    },
  },
  methods: {
    updateSuffix(value) {
      this.$emit('update', value);
    },
  },
};
</script>

<template>
  <div class="security-policies-bg-subtle gl-flex gl-items-center gl-gap-3 gl-rounded-base">
    <gl-sprintf :message="$options.i18n.suffixLabel">
      <template #suffixEditor>
        <gl-collapsible-listbox
          :selected="suffix"
          :items="$options.SUFFIX_LIST_BOX_ITEMS"
          :toggle-text="toggleText"
          @select="updateSuffix"
        />
      </template>

      <template #suffixIcon>
        <gl-icon v-gl-tooltip name="information-o" :title="$options.i18n.suffixInfoText" />
      </template>
    </gl-sprintf>
  </div>
</template>
