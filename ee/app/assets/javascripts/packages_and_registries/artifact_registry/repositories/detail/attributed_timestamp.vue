<script>
import { GlAvatar, GlAvatarLink, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';

const DATE_ONLY = '%{date}';

export default {
  name: 'ArtifactRegistryAttributedTimestamp',
  components: {
    GlAvatar,
    GlAvatarLink,
    GlSprintf,
  },
  mixins: [glSlotsMixin],
  props: {
    title: {
      type: String,
      required: true,
    },
    user: {
      type: Object,
      required: false,
      default: null,
    },
  },
  computed: {
    message() {
      return this.user ? this.$options.i18n.dateByUser : DATE_ONLY;
    },
  },
  i18n: {
    dateByUser: s__('ArtifactRegistry|%{date} by %{user}'),
  },
  avatarSize: 16,
};
</script>

<template>
  <div class="gl-border-t gl-pt-4">
    <h2 class="gl-heading-5 gl-mb-2">{{ title }}</h2>

    <p class="gl-mb-0 gl-flex gl-flex-wrap gl-items-center gl-gap-2">
      <gl-sprintf :message="message">
        <template v-if="glSlots().default" #date><slot></slot></template>
        <template #user>
          <gl-avatar-link
            :href="user.webPath"
            class="gl-flex gl-items-center gl-gap-2 gl-font-bold"
          >
            <gl-avatar :size="$options.avatarSize" :alt="''" :src="user.avatarUrl" />
            {{ user.name }}
          </gl-avatar-link>
        </template>
      </gl-sprintf>
    </p>
  </div>
</template>
