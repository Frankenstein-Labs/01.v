<script>
import { GlButton } from '@gitlab/ui';

export default {
  name: 'IndexEntitiesList',
  components: {
    GlButton,
  },
  props: {
    entities: {
      type: Array,
      required: false,
      default: () => [],
    },
    emptyText: {
      type: String,
      required: true,
    },
  },
  emits: ['remove'],
};
</script>

<template>
  <div class="index-entities-list gl-border gl-overflow-auto gl-rounded-small gl-bg-default">
    <ul v-if="entities.length" class="gl-my-2 gl-list-none gl-p-0">
      <li v-for="entity in entities" :key="entity.id" class="gl-px-5 gl-py-2">
        <div class="gl-flex gl-items-center">
          <div class="gl-truncate-end gl-grow gl-pr-3">{{ entity.text }}</div>
          <gl-button
            variant="danger"
            category="secondary"
            icon="remove"
            data-testid="remove-index-entity"
            @click="$emit('remove', entity.id)"
          />
        </div>
      </li>
    </ul>
    <div v-else class="gl-flex gl-h-full gl-items-center gl-justify-center">
      {{ emptyText }}
    </div>
  </div>
</template>
