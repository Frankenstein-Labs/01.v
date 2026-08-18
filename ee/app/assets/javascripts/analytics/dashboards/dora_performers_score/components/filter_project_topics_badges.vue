<script>
import { GlBadge, GlButton, GlPopover } from '@gitlab/ui';
import { __, s__, sprintf } from '~/locale';
import { joinPaths } from '~/lib/utils/url_utility';

const MAX_PRIMARY_BADGES = 2;

export default {
  name: 'FilterProjectTopicsBadges',
  components: {
    GlBadge,
    GlButton,
    GlPopover,
  },
  inject: ['topicsExploreProjectsPath'],
  props: {
    topics: {
      type: Array,
      required: true,
    },
  },
  computed: {
    // The topics visible outside the popover
    primaryBadges() {
      return this.topics.slice(0, MAX_PRIMARY_BADGES);
    },

    showMoreVisible() {
      return this.topics.length > MAX_PRIMARY_BADGES;
    },

    showMoreButtonText() {
      return sprintf(__('+ %{count} more'), { count: this.topics.length - MAX_PRIMARY_BADGES });
    },
  },
  methods: {
    popoverTargetFn() {
      return this.$refs.popoverTarget?.$el;
    },
    getHref(topic) {
      return joinPaths(this.topicsExploreProjectsPath, encodeURIComponent(topic));
    },
  },
  i18n: {
    filteredBy: s__('DORA4Metrics|Filtered by'),
    allTopics: s__('DORA4Metrics|All topics'),
  },
};
</script>
<template>
  <div>
    <span class="gl-mr-2 gl-text-sm gl-text-default">{{ $options.i18n.filteredBy }}</span>
    <span data-testid="primary-badges">
      <gl-badge
        v-for="topic in primaryBadges"
        :key="topic"
        variant="neutral"
        class="gl-ml-2"
        :href="getHref(topic)"
        >{{ topic }}</gl-badge
      >
    </span>

    <template v-if="showMoreVisible">
      <gl-button
        ref="popoverTarget"
        class="gl-ml-2 !gl-no-underline"
        variant="link"
        size="small"
        button-text-classes="gl-text-subtle"
      >
        {{ showMoreButtonText }}
      </gl-button>
      <gl-popover :target="popoverTargetFn" :title="$options.i18n.allTopics" placement="bottom">
        <div class="gl-flex gl-flex-col gl-gap-2">
          <div v-for="topic in topics" :key="topic">
            <gl-badge variant="neutral" :href="getHref(topic)">{{ topic }}</gl-badge>
          </div>
        </div>
      </gl-popover>
    </template>
  </div>
</template>
