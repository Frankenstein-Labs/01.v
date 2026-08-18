<script>
import { GlTab, GlTabs } from '@gitlab/ui';
import { s__ } from '~/locale';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import {
  AI_CATALOG_AGENTS_ROUTE,
  AI_CATALOG_FLOWS_ROUTE,
  AI_CATALOG_MCP_SERVERS_ROUTE,
} from '../router/constants';

export default {
  name: 'AiCatalogNavTabs',
  components: {
    GlTab,
    GlTabs,
  },
  mixins: [glAbilitiesMixin()],
  computed: {
    tabs() {
      return [
        {
          text: s__('AICatalog|Agents'),
          route: AI_CATALOG_AGENTS_ROUTE,
          active: this.$route.name === AI_CATALOG_AGENTS_ROUTE,
        },
        {
          text: s__('AICatalog|Flows'),
          route: AI_CATALOG_FLOWS_ROUTE,
          active: this.$route.name === AI_CATALOG_FLOWS_ROUTE,
        },
        ...(this.glAbilities.readAiCatalogMcpServer
          ? [
              {
                text: s__('AICatalog|MCP'),
                route: AI_CATALOG_MCP_SERVERS_ROUTE,
                active: this.$route.name === AI_CATALOG_MCP_SERVERS_ROUTE,
              },
            ]
          : []),
      ];
    },
  },
  methods: {
    navigateTo(route) {
      if (this.$route.name !== route) {
        this.$router.push({ name: route, query: this.$route.query });
      }
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-grow @lg/panel:gl-items-center">
    <gl-tabs content-class="gl-py-0">
      <gl-tab
        v-for="tab in tabs"
        :key="tab.text"
        :title="tab.text"
        :active="tab.active"
        @click="navigateTo(tab.route)"
      />
    </gl-tabs>
  </div>
</template>
