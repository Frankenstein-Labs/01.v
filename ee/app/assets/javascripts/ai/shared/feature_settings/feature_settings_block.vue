<script>
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';

export default {
  name: 'FeatureSettingsBlock',
  components: {
    SettingsBlock,
  },
  mixins: [glSlotsMixin],
  props: {
    id: {
      type: String,
      required: true,
    },
    title: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      expanded: true,
    };
  },
  methods: {
    toggleExpanded(expanded) {
      this.expanded = expanded;
    },
  },
};
</script>
<template>
  <div class="gl-border-t-1 gl-border-subtle gl-pb-5 gl-pt-5 gl-border-t-solid">
    <settings-block :id="id" :title="title" :expanded="expanded" @toggle-expand="toggleExpanded">
      <template v-if="glSlots().description" #description>
        <slot name="description"></slot>
      </template>
      <template v-if="glSlots().content" #default>
        <slot name="content"></slot>
      </template>
    </settings-block>
  </div>
</template>
