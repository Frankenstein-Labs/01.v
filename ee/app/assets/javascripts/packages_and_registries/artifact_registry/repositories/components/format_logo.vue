<script>
import { GlAvatar } from '@gitlab/ui';
import { REPOSITORY_FORMAT_LABELS, REPOSITORY_FORMAT_LOGOS } from '../../constants';

export default {
  name: 'ArtifactRegistryFormatLogo',
  components: {
    GlAvatar,
  },
  props: {
    format: {
      type: String,
      required: true,
    },
    // One of the avatar sizes, because a format without a logo falls back to an avatar
    // and those come in fixed steps.
    size: {
      type: Number,
      required: false,
      default: 16,
    },
  },
  computed: {
    logoUrl() {
      return REPOSITORY_FORMAT_LOGOS[this.format];
    },
    formatLabel() {
      return REPOSITORY_FORMAT_LABELS[this.format];
    },
  },
};
</script>

<template>
  <!-- Decorative either way: the fallback avatar renders itself `aria-hidden` and takes no
       alternative text, so a caller with no text naming the format has to supply that name
       itself rather than through the logo. -->
  <!-- eslint-disable @gitlab/vue-require-i18n-attribute-strings -->
  <img
    v-if="logoUrl"
    :src="logoUrl"
    :width="size"
    :height="size"
    alt=""
    class="gl-shrink-0 gl-bg-transparent dark:gl-rounded-base dark:gl-bg-neutral-50"
  />
  <!-- eslint-enable @gitlab/vue-require-i18n-attribute-strings -->
  <!-- A format we have no logo for falls back to the letter avatar that a group or project
       without one uses, rather than borrowing another format's logo. -->
  <gl-avatar v-else :entity-name="formatLabel" :size="size" shape="rect" />
</template>
