<script>
import { GlIcon, GlPopover, GlSprintf, GlTooltipDirective, GlLink } from '@gitlab/ui';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import {
  AI_CATALOG_TYPE_AGENT,
  AI_CATALOG_TYPE_FLOW,
  AI_CATALOG_TYPE_FOUNDATIONAL_AGENT,
} from 'ee/ai/catalog/constants';

const AGENT_HELP = {
  path: helpPagePath('user/duo_agent_platform/agents/foundational_agents/_index.md'),
  text: s__('AICatalog|Learn more about foundational agents'),
};

const FOUNDATIONAL_ITEM_HELP_ATTRIBUTES = {
  [AI_CATALOG_TYPE_AGENT]: AGENT_HELP,
  [AI_CATALOG_TYPE_FOUNDATIONAL_AGENT]: AGENT_HELP,
  [AI_CATALOG_TYPE_FLOW]: {
    path: helpPagePath('user/duo_agent_platform/flows/foundational_flows/_index.md'),
    text: s__('AICatalog|Learn more about foundational flows'),
  },
};

export default {
  name: 'FoundationalIcon',
  components: {
    GlIcon,
    GlPopover,
    GlSprintf,
    GlLink,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    resourceId: {
      type: String,
      required: true,
    },
    itemType: {
      type: String,
      required: false,
      default: AI_CATALOG_TYPE_AGENT,
    },
    size: {
      type: Number,
      required: false,
      default: 24,
    },
  },
  computed: {
    popoverTarget() {
      return `${getIdFromGraphQLId(this.resourceId)}-foundational-icon`;
    },
    helpPagePath() {
      return FOUNDATIONAL_ITEM_HELP_ATTRIBUTES[this.itemType]?.path;
    },
    helpLinkText() {
      return FOUNDATIONAL_ITEM_HELP_ATTRIBUTES[this.itemType]?.text;
    },
  },
};
</script>

<template>
  <span>
    <gl-icon
      :id="popoverTarget"
      v-gl-tooltip
      name="tanuki-verified"
      variant="subtle"
      :size="size"
    />
    <gl-popover :target="popoverTarget" triggers="hover focus">
      <div class="gl-flex gl-flex-col gl-gap-4">
        <span>
          <gl-sprintf
            :message="s__('AICatalog|Created and maintained by %{boldStart}GitLab%{boldEnd}')"
          >
            <template #bold="{ content }">
              <strong>
                {{ content }}
              </strong>
            </template>
          </gl-sprintf>
        </span>
        <gl-link v-if="helpPagePath" :href="helpPagePath">
          {{ helpLinkText }}
        </gl-link>
      </div>
    </gl-popover>
  </span>
</template>
