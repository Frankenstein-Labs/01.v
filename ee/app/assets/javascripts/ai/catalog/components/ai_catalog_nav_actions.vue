<script>
import { GlButton } from '@gitlab/ui';
import { s__ } from '~/locale';
import { isLoggedIn } from '~/lib/utils/common_utils';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import {
  AI_CATALOG_INDEX_ROUTE,
  AI_CATALOG_AGENTS_ROUTE,
  AI_CATALOG_AGENTS_NEW_ROUTE,
  AI_CATALOG_FLOWS_ROUTE,
  AI_CATALOG_FLOWS_NEW_ROUTE,
  AI_CATALOG_MCP_SERVERS_ROUTE,
  AI_CATALOG_MCP_SERVERS_NEW_ROUTE,
} from '../router/constants';

export default {
  name: 'AiCatalogNavActions',
  components: {
    GlButton,
  },
  mixins: [glAbilitiesMixin()],
  inject: {
    isGlobalNamespace: {
      default: false,
    },
  },
  props: {
    canAdmin: {
      type: Boolean,
      required: false,
      default: false,
    },
    canCreate: {
      type: Boolean,
      required: false,
      default: false,
    },
    newButtonVariant: {
      type: String,
      required: false,
      default: 'confirm',
    },
  },
  computed: {
    showNewButton() {
      return (
        (this.glAbilities.readAiCatalog ||
          (isLoggedIn() && this.canAdmin && !this.isGlobalNamespace && this.canCreate)) &&
        this.newButtonProps.route
      );
    },
    newButtonProps() {
      switch (this.$route.name) {
        case AI_CATALOG_INDEX_ROUTE:
        case AI_CATALOG_AGENTS_ROUTE:
          return {
            route: AI_CATALOG_AGENTS_NEW_ROUTE,
            label: s__('AICatalog|New agent'),
          };
        case AI_CATALOG_FLOWS_ROUTE:
          return {
            route: AI_CATALOG_FLOWS_NEW_ROUTE,
            label: s__('AICatalog|New flow'),
          };
        case AI_CATALOG_MCP_SERVERS_ROUTE:
          return this.glAbilities.createAiCatalogMcpServer
            ? {
                route: AI_CATALOG_MCP_SERVERS_NEW_ROUTE,
                label: s__('AICatalog|New MCP server'),
              }
            : { route: null, label: '' };
        default:
          return {
            route: null,
            label: '',
          };
      }
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-items-center gl-gap-3">
    <gl-button
      v-if="showNewButton"
      :to="{ name: newButtonProps.route }"
      :variant="newButtonVariant"
    >
      {{ newButtonProps.label }}
    </gl-button>
    <slot></slot>
  </div>
</template>
