<script>
import {
  AI_CATALOG_TYPE_AGENT,
  AI_CATALOG_TYPE_FLOW,
  AI_CATALOG_TYPE_FOUNDATIONAL_AGENT,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
} from '../constants';
import AiCatalogAgentDetails from './ai_catalog_agent_details.vue';
import AiCatalogFlowDetails from './ai_catalog_flow_details.vue';

const DETAILS_COMPONENT_MAP = {
  [AI_CATALOG_TYPE_AGENT]: AiCatalogAgentDetails,
  [AI_CATALOG_TYPE_FLOW]: AiCatalogFlowDetails,
  [AI_CATALOG_TYPE_FOUNDATIONAL_AGENT]: AiCatalogAgentDetails,
  [AI_CATALOG_TYPE_THIRD_PARTY_FLOW]: AiCatalogAgentDetails,
};

export default {
  name: 'AiCatalogItemView',
  components: {
    AiCatalogAgentDetails,
    AiCatalogFlowDetails,
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
  },
  computed: {
    detailsComponent() {
      return DETAILS_COMPONENT_MAP[this.item.itemType];
    },
  },
};
</script>

<template>
  <component :is="detailsComponent" :item="item" :version-key="versionKey" class="gl-grow" />
</template>
