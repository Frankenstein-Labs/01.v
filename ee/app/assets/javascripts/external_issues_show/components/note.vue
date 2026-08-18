<script>
import { GlAvatarLink, GlAvatar, GlLink } from '@gitlab/ui';
import SafeHtml from '~/vue_shared/directives/safe_html';
import TimelineEntryItem from '~/vue_shared/components/notes/timeline_entry_item.vue';
import TimelineIcon from '~/vue_shared/components/notes/timeline_icon.vue';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';

export default {
  name: 'ExternalIssuesNote',
  components: {
    GlAvatarLink,
    GlAvatar,
    GlLink,
    TimelineEntryItem,
    TimelineIcon,
    TimeAgoTooltip,
  },
  directives: {
    SafeHtml,
  },
  props: {
    authorAvatarUrl: {
      type: String,
      required: true,
    },
    authorWebUrl: {
      type: String,
      required: true,
    },
    authorName: {
      type: String,
      required: true,
    },
    noteBodyHtml: {
      type: String,
      required: true,
    },
    noteCreatedAt: {
      type: String,
      required: true,
    },
    authorUsername: {
      type: String,
      required: false,
      default: undefined,
    },
  },
  computed: {
    noteAnchor() {
      return `#${this.$attrs.id || ''}`;
    },
  },
};
</script>

<template>
  <timeline-entry-item class="gl-p-5">
    <timeline-icon class="gl-ml-2 gl-mr-5">
      <gl-avatar-link target="_blank" :href="authorWebUrl">
        <gl-avatar :size="32" :src="authorAvatarUrl" :alt="authorName" />
      </gl-avatar-link>
    </timeline-icon>

    <div>
      <div class="gl-flex gl-justify-between">
        <div class="gl-mb-3 gl-flex gl-items-center">
          <gl-link
            :href="authorWebUrl"
            class="gl-mr-2 gl-whitespace-nowrap gl-font-bold gl-text-default"
          >
            {{ authorName }}
          </gl-link>

          <gl-link
            v-if="authorUsername"
            :href="authorWebUrl"
            class="gl-mr-2 gl-whitespace-nowrap gl-text-subtle"
            data-testid="author-username"
          >
            @{{ authorUsername }}
          </gl-link>

          <span class="gl-mr-2 gl-text-subtle">·</span>

          <gl-link class="gl-text-subtle" :href="noteAnchor" data-testid="time-ago-link">
            <time-ago-tooltip :time="noteCreatedAt" tooltip-placement="bottom" />
          </gl-link>
        </div>

        <div data-testid="badges-container">
          <slot name="badges"></slot>
        </div>
      </div>

      <div>
        <div class="gl-overflow-x-auto gl-overflow-y-hidden">
          <div v-safe-html="noteBodyHtml" class="md"></div>
        </div>
      </div>
    </div>
  </timeline-entry-item>
</template>
