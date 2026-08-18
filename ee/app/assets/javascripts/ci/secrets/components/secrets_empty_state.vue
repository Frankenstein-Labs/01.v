<script>
import { GlButton, GlCard, GlPopover } from '@gitlab/ui';
import EmptySecretsSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-secrets-md.svg?url';
import { s__ } from '~/locale';
import { ENTITY_GROUP, I18N_SECRETS_EMPTY_STATE, NEW_ROUTE_NAME } from 'ee/ci/secrets/constants';

export default {
  name: 'SecretsEmptyState',
  components: {
    GlButton,
    GlCard,
    GlPopover,
  },
  inject: ['contextConfig', 'isProvisioning', 'secretManagerStatus'],
  props: {
    canCreateSecret: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['provision-secrets-manager'],
  computed: {
    isGroupContext() {
      return this.contextConfig.type === ENTITY_GROUP;
    },
  },
  methods: {
    onNewSecretClick() {
      if (this.secretManagerStatus === null) {
        this.$emit('provision-secrets-manager');
      } else {
        this.$router.push({ name: NEW_ROUTE_NAME });
      }
    },
  },
  EmptySecretsSvg,
  i18n: {
    ...I18N_SECRETS_EMPTY_STATE,
    provisioningTitle: s__('SecretsManager|Enabling GitLab Secrets Manager'),
    provisioningDescription: s__(
      'SecretsManager|Please wait while the secrets manager is enabled.',
    ),
  },
};
</script>
<template>
  <gl-card
    data-testid="secrets-list-empty-state"
    body-class="gl-flex gl-flex-col gl-items-center gl-text-center gl-py-8"
  >
    <template #header>
      <strong>{{ s__('SecretsManager|Secrets') }}</strong>
      <p v-if="isGroupContext" data-testid="group-subheader" class="gl-mb-0 gl-text-subtle">
        {{ $options.i18n.groupSubheader }}
      </p>
    </template>
    <!-- eslint-disable-next-line @gitlab/vue-require-i18n-attribute-strings -->
    <img :src="$options.EmptySecretsSvg" alt="" class="gl-mb-4" />
    <h2 class="gl-mb-3 gl-mt-0 gl-text-size-h2">
      {{ $options.i18n.title }}
    </h2>
    <p class="gl-mb-5">
      {{ $options.i18n.description }}
    </p>
    <gl-button
      v-if="canCreateSecret"
      ref="newSecretButton"
      :loading="isProvisioning"
      data-testid="empty-state-new-secret-button"
      @click="onNewSecretClick"
    >
      {{ s__('SecretsManager|New secret') }}
    </gl-button>
    <gl-popover
      :target="() => $refs.newSecretButton"
      :show="isProvisioning"
      :title="$options.i18n.provisioningTitle"
      placement="bottom"
      triggers="manual"
    >
      {{ $options.i18n.provisioningDescription }}
    </gl-popover>
  </gl-card>
</template>
