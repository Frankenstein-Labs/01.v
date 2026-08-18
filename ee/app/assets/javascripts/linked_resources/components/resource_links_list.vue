<script>
import ResourceLinkItem from './resource_links_list_item.vue';

export default {
  name: 'ResourceLinksList',
  components: {
    ResourceLinkItem,
  },
  props: {
    canAdmin: {
      type: Boolean,
      required: false,
      default: false,
    },
    resourceLinks: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['resource-link-remove-request'],
};
</script>

<template>
  <div class="related-issues-token-body">
    <ul class="related-items-list content-list !-gl-mx-2 !gl-py-3">
      <li
        v-for="link in resourceLinks"
        :key="link.id"
        :data-key="link.id"
        class="list-item !gl-border-0 !gl-py-0"
      >
        <resource-link-item
          data-testid="resource-link-item"
          :id-key="link.id"
          :icon-name="link.linkType"
          :link-text="link.linkText"
          :link-value="link.link"
          :can-remove="canAdmin"
          @remove-request="$emit('resource-link-remove-request', $event)"
        />
      </li>
    </ul>
  </div>
</template>
