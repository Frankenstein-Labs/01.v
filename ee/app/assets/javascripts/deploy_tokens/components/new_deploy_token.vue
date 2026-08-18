<script>
import CeNewDeployToken from '~/deploy_tokens/components/new_deploy_token.vue';
import translations from '../deploy_token_translations';

export default {
  name: 'NewDeployTokenEE',
  components: {
    CeNewDeployToken,
  },
  props: {
    ...CeNewDeployToken.props,
    topLevelGroup: {
      type: Boolean,
      required: true,
    },
  },
  translations,
  computed: {
    readVirtualRegistryText() {
      return this.topLevelGroup
        ? translations.topLevelGroupReadVirtualRegistryHelp
        : translations.readVirtualRegistryHelp;
    },
  },
};
</script>

<template>
  <ce-new-deploy-token :read-virtual-registry-help-text="readVirtualRegistryText" v-bind="$props" />
</template>
