<script>
/**
 * @description
 * This component displays UserCore GraphQL data interface
 * in a UI similar to `~/members/components/avatars/user_avatar.vue`
 */
import { GlAvatarLabeled, GlAvatarLink } from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { getNormalizedURL, setUrlParams } from '~/lib/utils/url_utility';
import { __ } from '~/locale';
import { AVATAR_SIZE } from '../../constants';

export default {
  name: 'UserAvatarEE',
  components: {
    GlAvatarLink,
    GlAvatarLabeled,
  },
  props: {
    user: {
      type: Object,
      required: false,
      default: null,
    },
  },
  computed: {
    userId() {
      return getIdFromGraphQLId(this.user?.id);
    },
    userAvatarUrl() {
      if (!this.user?.avatarUrl) return null;
      return setUrlParams(
        { width: AVATAR_SIZE * 2 },
        { url: getNormalizedURL(this.user.avatarUrl) },
      );
    },
  },
  AVATAR_SIZE,
  i18n: {
    orphanedRequest: __('Orphaned request'),
  },
};
</script>

<template>
  <gl-avatar-link
    v-if="user"
    class="js-user-link"
    :href="user.webUrl"
    :data-user-id="userId"
    :data-username="user.username"
    :data-email="user.publicEmail"
  >
    <gl-avatar-labeled
      :label="user.name"
      :sub-label="`@${user.username}`"
      :src="userAvatarUrl"
      :alt="user.name"
      :size="$options.AVATAR_SIZE"
      :entity-name="user.name"
      :entity-id="userId"
    />
  </gl-avatar-link>

  <gl-avatar-labeled
    v-else
    :label="$options.i18n.orphanedRequest"
    :alt="$options.i18n.orphanedRequest"
    :size="$options.AVATAR_SIZE"
    :entity-name="$options.i18n.orphanedRequest"
    :entity-id="userId"
  />
</template>
