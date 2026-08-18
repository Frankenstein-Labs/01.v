<script>
import { GlIcon, GlTooltipDirective } from '@gitlab/ui';
import { __ } from '~/locale';
import SidebarEditableItem from '~/sidebar/components/sidebar_editable_item.vue';

export default {
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    GlIcon,
    SidebarEditableItem,
  },
  provide: {
    canUpdate: false,
  },
  props: {
    icon: {
      type: String,
      required: true,
    },
    title: {
      type: String,
      required: true,
    },
    value: {
      type: String,
      required: false,
      default: null,
    },
  },
  emits: ['expand-sidebar'],
  computed: {
    tooltipProps() {
      return {
        boundary: 'viewport',
        placement: 'left',
        title: this.value || this.title,
      };
    },
    valueWithFallback() {
      return this.value || __('None');
    },
    valueClass() {
      return {
        'no-value': !this.value,
      };
    },
  },
  methods: {
    expandSidebar() {
      this.$emit('expand-sidebar', this.$refs.editableItem);
    },
  },
};
</script>

<template>
  <div class="block">
    <sidebar-editable-item ref="editableItem" :title="title" :can-edit="false">
      <template #collapsed>
        <div
          v-gl-tooltip="tooltipProps"
          class="sidebar-collapsed-icon"
          data-testid="field-collapsed"
          @click="expandSidebar"
        >
          <gl-icon :name="icon" />
        </div>

        <div class="hide-collapsed">
          <div class="value" data-testid="field-value">
            <span :class="valueClass">{{ valueWithFallback }}</span>
          </div>
        </div>
      </template>
    </sidebar-editable-item>
  </div>
</template>
