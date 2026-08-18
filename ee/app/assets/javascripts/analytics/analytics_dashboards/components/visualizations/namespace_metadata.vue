<script>
import { GlAvatar, GlIcon, GlTooltipDirective } from '@gitlab/ui';
import TooltipOnTruncate from '~/vue_shared/components/tooltip_on_truncate/tooltip_on_truncate.vue';
import { __, sprintf } from '~/locale';

export default {
  name: 'NamespaceMetadata',
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    GlAvatar,
    GlIcon,
    TooltipOnTruncate,
  },
  props: {
    data: {
      type: Object,
      required: true,
      validator: (value) =>
        [
          'fullName',
          'id',
          'namespaceType',
          'namespaceTypeIcon',
          'visibilityLevelIcon',
          'visibilityLevelTooltip',
        ].every((key) => value[key]),
    },
  },
  computed: {
    namespaceFullName() {
      return this.data.fullName;
    },
    avatarAltText() {
      return sprintf(__("%{name}'s avatar"), { name: this.namespaceFullName });
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-items-center gl-gap-3">
    <gl-avatar
      shape="rect"
      :src="data.avatarUrl"
      :size="48"
      :entity-name="namespaceFullName"
      :entity-id="data.id"
      :fallback-on-error="true"
      :alt="avatarAltText"
    />

    <div class="gl-min-w-0 gl-leading-24">
      <div class="-gl-mb-1 gl-flex gl-items-center gl-gap-2">
        <gl-icon
          data-testid="namespace-metadata-namespace-type-icon"
          variant="subtle"
          :name="data.namespaceTypeIcon"
        />
        <span class="gl-text-base gl-font-normal gl-text-subtle">{{ data.namespaceType }}</span>
      </div>
      <div class="gl-flex gl-items-center gl-gap-2">
        <tooltip-on-truncate
          :title="namespaceFullName"
          class="gl-truncate gl-text-size-h2 gl-font-bold"
          boundary="viewport"
          >{{ namespaceFullName }}</tooltip-on-truncate
        >
        <button
          v-gl-tooltip.viewport
          data-testid="namespace-metadata-visibility-button"
          class="gl-min-w-5 gl-border-0 gl-bg-transparent gl-p-0 gl-leading-0"
          :title="data.visibilityLevelTooltip"
          :aria-label="data.visibilityLevelTooltip"
        >
          <gl-icon variant="subtle" :name="data.visibilityLevelIcon" />
        </button>
      </div>
    </div>
  </div>
</template>
