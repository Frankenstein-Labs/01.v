<script>
import { GlAvatarLink, GlAvatarLabeled, GlLink, GlIcon } from '@gitlab/ui';
import { ListType, ListTypeTitles } from '~/boards/constants';

export default {
  name: 'BoardSettingsListTypes',
  components: {
    GlLink,
    GlAvatarLink,
    GlAvatarLabeled,
    GlIcon,
  },
  props: {
    boardListType: {
      type: String,
      required: true,
    },
    activeList: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      ListType,
    };
  },
  computed: {
    activeListObject() {
      return this.activeList[this.boardListType] || {};
    },
    listTypeHeader() {
      return ListTypeTitles[this.boardListType] || '';
    },
    statusIconName() {
      return this.activeListObject?.iconName;
    },
    statusColor() {
      return this.activeListObject?.color;
    },
    statusName() {
      return this.activeListObject?.name;
    },
  },
};
</script>

<template>
  <div>
    <label class="js-list-label gl-block">{{ listTypeHeader }}</label>
    <gl-avatar-link
      v-if="boardListType === ListType.assignee"
      class="js-assignee"
      :href="activeListObject.webUrl"
    >
      <gl-avatar-labeled
        :size="32"
        :label="activeListObject.name"
        :sub-label="`@${activeListObject.username}`"
        :src="activeListObject.avatar"
      />
    </gl-avatar-link>
    <div
      v-else-if="boardListType === ListType.status"
      data-testid="status-list-type"
      class="gl-truncate"
    >
      <gl-icon :name="statusIconName" :size="12" class="gl-mr-2" :style="{ color: statusColor }" />
      <span>{{ statusName }}</span>
    </div>
    <gl-link v-else class="js-list-title" :href="activeListObject.webUrl">
      {{ activeListObject.title }}
    </gl-link>
  </div>
</template>
