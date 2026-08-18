<script>
import { GlButton, GlIcon } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import GenericConfig from './generic_config.vue';

export default {
  name: 'BuilderSection',
  components: { GlButton, GlIcon, GenericConfig },
  props: {
    section: {
      type: Object,
      required: true,
    },
  },
  emits: ['add', 'remove', 'update-config'],

  methods: {
    hasFields(entry) {
      return Boolean(entry.fields?.length);
    },
    removeLabel(entry) {
      return sprintf(s__('PolicyStore|Remove %{label}'), { label: entry.label });
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-col gl-gap-3">
    <div>
      <h3 class="gl-mb-0.5 gl-text-lg gl-font-bold">{{ section.heading }}</h3>
      <p class="gl-mb-0 gl-text-base">{{ section.description }}</p>
    </div>

    <template v-for="(entry, index) in section.entries">
      <div
        v-if="index > 0"
        :key="`${section.id}-joiner-${entry.id}`"
        class="gl-flex gl-justify-center"
      >
        <span
          class="gl-border gl-rounded-full gl-border-subtle gl-bg-default gl-px-3 gl-py-1 gl-text-xs gl-font-bold gl-uppercase gl-tracking-wide gl-text-subtle"
        >
          {{ section.joiner }}
        </span>
      </div>

      <div
        :key="entry.id"
        :data-testid="`${section.id}-selected`"
        class="gl-border gl-rounded-lg gl-border-default gl-bg-default"
      >
        <div class="gl-flex gl-items-start gl-justify-between gl-p-4">
          <div class="gl-flex gl-min-w-0 gl-flex-1 gl-items-start gl-gap-2">
            <span
              class="gl-flex gl-h-6 gl-w-6 gl-flex-shrink-0 gl-items-center gl-justify-center gl-rounded-base gl-bg-subtle gl-text-subtle"
            >
              <gl-icon :name="entry.icon" :size="14" />
            </span>
            <span class="gl-min-w-0">
              <span class="gl-block gl-text-sm gl-font-semibold">{{ entry.label }}</span>
              <span class="gl-mt-0.5 gl-block gl-text-xs gl-font-normal gl-text-subtle">
                {{ entry.description }}
              </span>
            </span>
          </div>
          <gl-button
            icon="close"
            size="small"
            category="tertiary"
            :aria-label="removeLabel(entry)"
            :data-testid="`${section.id}-selected-remove`"
            @click="$emit('remove', entry.id)"
          />
        </div>

        <div v-if="hasFields(entry)" class="gl-border-t gl-border-subtle gl-p-4">
          <generic-config
            :fields="entry.fields"
            :value="entry.config"
            @input="$emit('update-config', { id: entry.id, config: $event })"
          />
        </div>
      </div>
    </template>

    <gl-button
      v-if="!section.entries.length"
      block
      icon="plus"
      :data-testid="`${section.id}-add`"
      @click="$emit('add')"
    >
      {{ section.addLabel }}
    </gl-button>
  </div>
</template>
