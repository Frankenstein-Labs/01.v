<script>
import { GlBadge } from '@gitlab/ui';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import {
  VISIBILITY_TYPE_ICON,
  VISIBILITY_LEVEL_LABELS,
  VISIBILITY_LEVEL_BADGE_VARIANT,
} from '../constants';
import { getAiCatalogItemVisibilityLevel } from '../capabilities';
import AiCatalogItemField from './ai_catalog_item_field.vue';

export default {
  name: 'AiCatalogItemVisibilityField',
  components: {
    GlBadge,
    AiCatalogItemField,
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
    public: {
      type: Boolean,
      required: false,
      default: false,
    },
    visibility: {
      type: String,
      required: true,
    },
    descriptionTexts: {
      type: Object,
      required: true,
    },
  },
  computed: {
    visibilityLevel() {
      return getAiCatalogItemVisibilityLevel(
        { public: this.public, visibility: this.visibility },
        this.glFeatures,
      );
    },
    visibilityDescription() {
      return this.descriptionTexts[this.visibilityLevel];
    },
    badgeIcon() {
      return VISIBILITY_TYPE_ICON[this.visibilityLevel];
    },
    badgeLabel() {
      return VISIBILITY_LEVEL_LABELS[this.visibilityLevel];
    },
    badgeVariant() {
      return VISIBILITY_LEVEL_BADGE_VARIANT[this.visibilityLevel];
    },
  },
};
</script>

<template>
  <ai-catalog-item-field :title="s__('AICatalog|Visibility')">
    <div class="gl-text-subtle">
      {{ visibilityDescription }}
    </div>
    <gl-badge :icon="badgeIcon" :variant="badgeVariant" class="gl-mt-3">
      {{ badgeLabel }}
    </gl-badge>
  </ai-catalog-item-field>
</template>
