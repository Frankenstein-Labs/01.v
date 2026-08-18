<script>
import { GlLink, GlPopover, GlSprintf } from '@gitlab/ui';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';

export default {
  name: 'PolicyPopover',
  components: {
    GlLink,
    GlPopover,
    GlSprintf,
    HelpIcon,
  },
  props: {
    content: {
      type: String,
      required: true,
    },
    href: {
      type: String,
      required: false,
      default: null,
    },
    target: {
      type: String,
      required: false,
      default: 'popover-icon',
    },
    title: {
      type: String,
      required: false,
      default: null,
    },
    showCloseButton: {
      type: Boolean,
      required: false,
      default: true,
    },
    showPopover: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
};
</script>

<template>
  <div>
    <gl-popover
      v-if="showPopover"
      :target="target"
      :show-close-button="showCloseButton"
      :title="title"
    >
      <gl-sprintf :message="content">
        <template #link="{ content: linkContent }">
          <gl-link v-if="href" class="gl-text-sm" target="_blank" :href="href">{{
            linkContent
          }}</gl-link>
        </template>
      </gl-sprintf>
    </gl-popover>

    <slot name="trigger">
      <help-icon :id="target" />
    </slot>
  </div>
</template>
