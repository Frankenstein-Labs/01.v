<script>
import { GlLabel, GlPopover, GlButton } from '@gitlab/ui';
import { sprintf, s__ } from '~/locale';
import { isSubGroup } from '../utils';
import { VISIBLE_ATTRIBUTE_COUNT, LIGHT_GRAY } from '../constants';

export default {
  components: {
    GlLabel,
    GlPopover,
    GlButton,
  },
  inject: ['canManageAttributes'],
  props: {
    item: {
      type: Object,
      required: true,
    },
    index: {
      type: Number,
      required: true,
    },
    editable: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['open-attributes-drawer'],
  computed: {
    attributes() {
      return this.item.securityAttributes?.nodes || [];
    },
    hasAttributes() {
      return this.attributes.length > 0;
    },

    visibleAttributes() {
      return this.attributes.slice(0, VISIBLE_ATTRIBUTE_COUNT);
    },
    showOverflow() {
      return this.attributes.length > VISIBLE_ATTRIBUTE_COUNT;
    },
    overflowAttributeText() {
      return sprintf(s__(`SecurityAttributes|+%{additionalAttributeCount} more`), {
        additionalAttributeCount: this.attributes.length - VISIBLE_ATTRIBUTE_COUNT,
      });
    },
    popoverTitle() {
      return sprintf(s__('SecurityAttributes|Security attributes for %{projectName}'), {
        projectName: this.item.name,
      });
    },
  },
  methods: {
    isSubGroup,
    addSecurityAttributes() {
      this.$emit('open-attributes-drawer', this.item);
    },
  },
  LIGHT_GRAY,
};
</script>
<template>
  <div v-if="!isSubGroup(item)">
    <span v-if="hasAttributes" data-testid="visible-attributes">
      <gl-label
        v-for="attribute in visibleAttributes"
        :key="attribute.id"
        :title="attribute.name"
        :background-color="attribute.color"
        class="gl-m-1"
      />
    </span>
    <span v-else-if="editable && canManageAttributes">
      <gl-button variant="link" @click="addSecurityAttributes">{{
        s__('SecurityAttributes|+ Add attributes')
      }}</gl-button>
    </span>
    <template v-else>
      {{ __('—') }}
    </template>
    <span :id="`attributes-overflow-popover-${index}`">
      <gl-label
        v-if="showOverflow"
        data-testid="overflow-attribute"
        :title="overflowAttributeText"
        :background-color="$options.LIGHT_GRAY"
        class="gl-m-1"
      />
    </span>

    <gl-popover v-if="showOverflow" :target="`attributes-overflow-popover-${index}`">
      <template #title>
        {{ popoverTitle }}
      </template>
      <div data-testid="all-attributes">
        <gl-label
          v-for="attribute in attributes"
          :key="attribute.id"
          :title="attribute.name"
          :background-color="attribute.color"
          class="gl-m-1"
        />
      </div>
    </gl-popover>
  </div>
</template>
