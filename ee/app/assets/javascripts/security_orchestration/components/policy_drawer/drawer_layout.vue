<script>
import { GlIcon, GlLink, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import { getSecurityPolicyListUrl } from '~/editor/extensions/source_editor_security_policy_schema_ext';
import { isPolicyInherited, policyHasNamespace, isGroup } from '../utils';
import {
  DEFAULT_DESCRIPTION_LABEL,
  DESCRIPTION_TITLE,
  ENABLED_LABEL,
  INHERITED_SHORT_LABEL,
  NOT_ENABLED_LABEL,
  SOURCE_TITLE,
  STATUS_TITLE,
  TYPE_TITLE,
} from './constants';
import ScopeInfoRow from './scope_info_row.vue';
import InfoRow from './info_row.vue';

export default {
  name: 'DrawerLayout',
  components: {
    GlIcon,
    GlLink,
    GlSprintf,
    InfoRow,
    ScopeInfoRow,
  },
  i18n: {
    policyTypeTitle: TYPE_TITLE,
    descriptionTitle: DESCRIPTION_TITLE,
    defaultDescription: DEFAULT_DESCRIPTION_LABEL,
    sourceTitle: SOURCE_TITLE,
    statusTitle: STATUS_TITLE,
    inheritedShortLabel: INHERITED_SHORT_LABEL,
  },
  inject: { namespaceType: { default: '' } },
  props: {
    description: {
      type: String,
      required: false,
      default: '',
    },
    showPolicyScope: {
      type: Boolean,
      required: false,
      default: true,
    },
    policyScope: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    policy: {
      type: Object,
      required: false,
      default: null,
    },
    type: {
      type: String,
      required: true,
    },
    showStatus: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  computed: {
    inheritedLabel() {
      return this.policy?.csp
        ? s__('SecurityOrchestration|This instance policy is inherited from %{namespace}')
        : s__('SecurityOrchestration|This policy is inherited from %{namespace}');
    },

    isInherited() {
      return isPolicyInherited(this.policy?.source);
    },
    isInstanceLevel() {
      return this.policy?.csp;
    },
    policyHasNamespace() {
      return policyHasNamespace(this.policy?.source);
    },
    sourcePolicyListUrl() {
      return getSecurityPolicyListUrl({ namespacePath: this.policy?.source.namespace.fullPath });
    },
    statusLabel() {
      return this.policy?.enabled ? ENABLED_LABEL : NOT_ENABLED_LABEL;
    },
    typeLabel() {
      if (isGroup(this.namespaceType)) {
        return this.policy?.csp
          ? s__('SecurityOrchestration|This is an instance policy')
          : s__('SecurityOrchestration|This is a group-level policy');
      }

      return s__('SecurityOrchestration|This is a project-level policy');
    },
  },
};
</script>

<template>
  <div>
    <slot name="summary"></slot>

    <info-row data-testid="policy-type" :label="$options.i18n.policyTypeTitle">
      {{ type }}
    </info-row>

    <info-row :label="$options.i18n.descriptionTitle">
      <div v-if="description" data-testid="custom-description-text">
        {{ description }}
      </div>
      <div v-else class="gl-text-subtle" data-testid="default-description-text">
        {{ $options.i18n.defaultDescription }}
      </div>
    </info-row>

    <scope-info-row
      v-if="showPolicyScope"
      :is-instance-level="isInstanceLevel"
      :policy-scope="policyScope"
    />

    <info-row :label="$options.i18n.sourceTitle">
      <div data-testid="policy-source">
        <gl-sprintf v-if="isInherited && policyHasNamespace" :message="inheritedLabel">
          <template #namespace>
            <gl-link :href="sourcePolicyListUrl" target="_blank">
              {{ policy.source.namespace.name }}
            </gl-link>
          </template>
        </gl-sprintf>
        <span v-else-if="isInherited && !policyHasNamespace">{{
          $options.i18n.inheritedShortLabel
        }}</span>
        <span v-else>{{ typeLabel }}</span>
      </div>
    </info-row>

    <slot name="additional-details"></slot>

    <info-row v-if="showStatus" :label="$options.i18n.statusTitle">
      <div v-if="policy.enabled" class="gl-text-success" data-testid="enabled-status-text">
        <gl-icon name="check-circle-filled" class="gl-mr-3" variant="success" />{{ statusLabel }}
      </div>
      <div v-else class="gl-text-subtle" data-testid="not-enabled-status-text">
        {{ statusLabel }}
      </div>
    </info-row>
  </div>
</template>
