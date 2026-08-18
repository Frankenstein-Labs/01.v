<script>
import { GlLink, GlPopover, GlIcon } from '@gitlab/ui';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';

export default {
  name: 'ApprovalCheckPopover',
  components: {
    GlLink,
    GlPopover,
    GlIcon,
    HelpIcon,
  },
  props: {
    documentationLink: {
      type: String,
      required: false,
      default: '',
    },
    documentationText: {
      type: String,
      required: false,
      default: '',
    },
    title: {
      type: String,
      required: true,
    },
    text: {
      type: String,
      required: false,
      default: '',
    },
    popoverId: {
      type: String,
      required: true,
    },
  },
};
</script>

<template>
  <span class="js-help gl-ml-2 gl-inline-flex">
    <help-icon :id="popoverId" class="author-link" :aria-label="__('help')" />
    <gl-popover :target="popoverId" placement="top" :title="title">
      <div class="gl-mb-3">{{ text }}</div>
      <gl-link v-if="documentationLink" target="_blank" :href="documentationLink">
        <span class="gl-align-middle">{{ documentationText }}</span>
        <gl-icon name="external-link" class="gl-align-middle" />
      </gl-link>
    </gl-popover>
  </span>
</template>
