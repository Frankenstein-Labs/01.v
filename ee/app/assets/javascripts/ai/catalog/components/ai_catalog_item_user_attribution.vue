<script>
import { GlAvatarLink, GlIcon, GlSprintf } from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { __ } from '~/locale';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { getByVersionKey, isGitLabMaintainedItem } from 'ee/ai/catalog/utils';

export default {
  name: 'AiCatalogItemUserAttribution',
  components: {
    GlAvatarLink,
    GlIcon,
    GlSprintf,
    TimeAgoTooltip,
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
    versionKey: {
      type: String,
      required: true,
    },
    authorClasses: {
      type: String,
      required: false,
      default: 'gl-font-bold gl-text-default',
    },
  },
  computed: {
    activeVersion() {
      return getByVersionKey(this.item, this.versionKey);
    },
    isFirstVersion() {
      return this.activeVersion?.createdAt === this.item.createdAt;
    },
    createdBy() {
      return this.activeVersion?.createdBy;
    },
    isGitLabMaintained() {
      return isGitLabMaintainedItem(this.item);
    },
    authorName() {
      return this.isGitLabMaintained ? __('GitLab') : (this.createdBy?.name ?? __('Unknown'));
    },
    hasUserLink() {
      return Boolean(this.createdBy) && !this.isGitLabMaintained;
    },
    userId() {
      return getIdFromGraphQLId(this.createdBy?.id);
    },
    actionMessage() {
      if (this.time) {
        return this.isFirstVersion
          ? __('Created %{timeAgo} by %{author}')
          : __('Updated %{timeAgo} by %{author}');
      }
      return this.isFirstVersion ? __('Created by %{author}') : __('Updated by %{author}');
    },
    time() {
      return this.activeVersion?.createdAt;
    },
    testId() {
      return this.isFirstVersion ? 'created-by' : 'modified-by';
    },
  },
};
</script>

<template>
  <span :data-testid="`metadata-${testId}`" class="-gl-translate-x-1 gl-gap-2 gl-text-subtle">
    <gl-icon name="user" variant="subtle" />
    <gl-sprintf :message="actionMessage">
      <template #timeAgo>
        <time-ago-tooltip :time="time" />
      </template>
      <template #author>
        <gl-avatar-link
          v-if="hasUserLink"
          class="js-user-link"
          :class="authorClasses"
          data-testid="user-link"
          :data-user-id="userId"
          :data-username="createdBy.username"
          :href="createdBy.webUrl"
        >
          {{ authorName }}
        </gl-avatar-link>
        <span v-else :class="authorClasses">{{ authorName }}</span>
      </template>
    </gl-sprintf>
  </span>
</template>
