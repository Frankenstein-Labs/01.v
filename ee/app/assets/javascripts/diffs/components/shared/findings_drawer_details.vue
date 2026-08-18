<script>
import { GlBadge, GlButton, GlLink } from '@gitlab/ui';
import { VULNERABILITY_DETAIL_CODE_FLOWS } from 'ee/security_dashboard/constants';
import { CODE_QUALITY_SCALE_KEY } from '~/ci/reports/constants';
import { __, s__ } from '~/locale';
import { SAST_FINDING_DISMISSED } from '~/diffs/constants';
import DrawerItem from './findings_drawer_item.vue';

export default {
  name: 'FindingsDrawerDetails',
  DrawerItem,
  codeQuality: CODE_QUALITY_SCALE_KEY,
  components: { DrawerItem, GlBadge, GlLink, GlButton },
  props: {
    drawer: {
      type: Object,
      required: true,
    },
    project: {
      type: Object,
      required: false,
      default: () => {},
    },
    insideTab: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['redirect-to-code-flow-tab'],
  computed: {
    findingsStatus() {
      return this.drawer.state === SAST_FINDING_DISMISSED ? 'neutral' : 'warning';
    },
    isCodeQuality() {
      return this.drawer.scale === this.$options.codeQuality;
    },
    showCodeFlowTabs() {
      const codeFlowData = this.drawer.details?.find(
        (detail) => detail.type === VULNERABILITY_DETAIL_CODE_FLOWS,
      );
      return codeFlowData?.items?.length > 0;
    },
  },
  methods: {
    concatIdentifierName(name, index) {
      return name + (index !== this.drawer.identifiers.length - 1 ? ', ' : '');
    },
  },
  i18n: {
    name: __('Name'),
    status: __('Status'),
    description: __('Description'),
    project: __('Project'),
    file: __('File'),
    identifiers: __('Identifiers'),
    tool: __('Tool'),
    codeQuality: s__('FindingsDrawer|Code Quality'),
    sast: __('SAST'),
    engine: __('Engine'),
    codeFlowButton: s__('FindingsDrawer|View code flow'),
  },
};
</script>

<template>
  <ul
    class="gl-mb-0 gl-list-none !gl-pb-0 gl-border-b-initial"
    :class="{ 'gl-pl-0': insideTab }"
    data-testid="drawer-container"
  >
    <drawer-item
      v-if="drawer.title"
      :description="$options.i18n.name"
      :value="drawer.title"
      data-testid="findings-drawer-title"
    />

    <drawer-item v-if="drawer.state" :description="$options.i18n.status">
      <template #value>
        <gl-badge :variant="findingsStatus" class="!gl-capitalize">{{ drawer.state }}</gl-badge>
      </template>
    </drawer-item>

    <drawer-item
      v-if="drawer.description"
      :description="$options.i18n.description"
      :value="drawer.description"
    />

    <drawer-item
      v-if="project && drawer.scale !== $options.codeQuality"
      :description="$options.i18n.project"
    >
      <template #value>
        <gl-link :href="`/${project.fullPath}`">{{ project.nameWithNamespace }}</gl-link>
      </template>
    </drawer-item>

    <drawer-item v-if="drawer.location || drawer.webUrl" :description="$options.i18n.file">
      <template #value>
        <span v-if="drawer.webUrl && drawer.filePath && drawer.line">
          <gl-link :href="drawer.webUrl">{{ drawer.filePath }}:{{ drawer.line }}</gl-link>
        </span>
        <span v-else-if="drawer.location">
          {{ drawer.location.file }}:{{ drawer.location.startLine }}
        </span>
      </template>
    </drawer-item>

    <drawer-item v-if="showCodeFlowTabs" data-testid="code-flow-button">
      <template #value>
        <gl-button
          category="primary"
          variant="default"
          data-testid="show-code-flow"
          @click="$emit('redirect-to-code-flow-tab')"
        >
          {{ $options.i18n.codeFlowButton }}
        </gl-button>
      </template>
    </drawer-item>

    <drawer-item
      v-if="drawer.identifiers && drawer.identifiers.length"
      :description="$options.i18n.identifiers"
    >
      <template #value>
        <span v-for="(identifier, index) in drawer.identifiers" :key="identifier.externalId">
          <gl-link v-if="identifier.url" :href="identifier.url">
            {{ concatIdentifierName(identifier.name, index) }}
          </gl-link>
          <span v-else>
            {{ concatIdentifierName(identifier.name, index) }}
          </span>
        </span>
      </template>
    </drawer-item>

    <drawer-item
      v-if="drawer.scale"
      :description="$options.i18n.tool"
      :value="isCodeQuality ? $options.i18n.codeQuality : $options.i18n.sast"
    />

    <drawer-item
      v-if="drawer.engineName"
      :description="$options.i18n.engine"
      :value="drawer.engineName"
    />
  </ul>
</template>
