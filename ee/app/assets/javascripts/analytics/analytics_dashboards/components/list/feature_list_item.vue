<script>
import { uniqueId } from 'lodash-es';
import { GlIcon, GlBadge, GlButton, GlLink, GlPopover, GlSprintf } from '@gitlab/ui';
import { __ } from '~/locale';

export default {
  name: 'FeatureListItem',
  components: {
    GlButton,
    GlIcon,
    GlBadge,
    GlLink,
    GlPopover,
    GlSprintf,
  },
  props: {
    title: {
      type: String,
      required: true,
    },
    description: {
      type: String,
      required: true,
    },
    to: {
      type: String,
      required: true,
    },
    badgeText: {
      type: String,
      required: false,
      default: null,
    },
    badgePopoverText: { type: String, required: false, default: null },
    badgePopoverLink: { type: String, required: false, default: null },
    actionText: {
      type: String,
      required: false,
      default: __('Set up'),
    },
    actionDisabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  featureAvatarColor: 1,
  badgeId: uniqueId('badge-'),
};
</script>

<template>
  <li class="!gl-flex gl-items-center !gl-px-5">
    <div class="gl-float-left gl-mr-4 gl-flex gl-items-center">
      <gl-icon name="cloud-gear" class="gl-mr-3" :size="16" variant="disabled" />
    </div>
    <div class="gl-flex gl-grow gl-items-center gl-justify-between">
      <div class="gl-flex gl-flex-col">
        <strong class="gl-text-gray-300">
          {{ title }}
        </strong>
        <p class="gl-m-0 gl-leading-normal gl-text-gray-300">
          {{ description }}
        </p>
      </div>
      <div class="gl-float-right">
        <template v-if="badgeText">
          <gl-badge :id="$options.badgeId">{{ badgeText }}</gl-badge>
          <gl-popover v-if="badgePopoverText" :target="$options.badgeId">
            <gl-sprintf v-if="badgePopoverLink" :message="badgePopoverText">
              <template #link="{ content }">
                <gl-link :href="badgePopoverLink">{{ content }}</gl-link>
              </template>
            </gl-sprintf>
            <template v-else>{{ badgePopoverText }}</template>
          </gl-popover>
        </template>
        <gl-button data-testid="setup-button" :to="to" :disabled="actionDisabled">{{
          actionText
        }}</gl-button>
      </div>
    </div>
  </li>
</template>
