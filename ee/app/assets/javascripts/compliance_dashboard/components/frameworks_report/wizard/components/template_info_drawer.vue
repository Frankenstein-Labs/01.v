<script>
import { GlBadge, GlButton, GlDrawer, GlLabel } from '@gitlab/ui';
import { s__ } from '~/locale';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import { getControls } from '../../../../utils';
import complianceRequirementControlsQuery from '../../../../graphql/compliance_requirement_controls.query.graphql';
import DrawerAccordion from '../../../shared/drawer_accordion.vue';

export default {
  name: 'TemplateInfoDrawer',
  components: { GlBadge, GlButton, GlDrawer, GlLabel, DrawerAccordion },
  props: {
    template: {
      type: Object,
      required: false,
      default: null,
    },
  },
  emits: ['close', 'use-template'],
  apollo: {
    gitlabControls: {
      query: complianceRequirementControlsQuery,
      update(data) {
        return data?.complianceRequirementControls?.controlExpressions ?? [];
      },
    },
  },
  data() {
    return {
      gitlabControls: [],
    };
  },
  computed: {
    isOpen() {
      return Boolean(this.template);
    },
    requirements() {
      return this.template?.requirements ?? [];
    },
  },
  methods: {
    getContentWrapperHeight,
    displayControls(controls) {
      const normalised = (controls ?? []).map((control) => ({
        ...control,
        controlType: control.controlType ?? control.control_type,
      }));
      return getControls(normalised, this.gitlabControls);
    },
  },
  DRAWER_Z_INDEX,
  i18n: {
    useTemplate: s__('ComplianceFramework|Use template'),
    description: s__('ComplianceFramework|Description'),
    requirements: s__('ComplianceFramework|Requirements'),
    controls: s__('ComplianceFramework|Controls'),
    noControls: s__('ComplianceFramework|No controls'),
  },
};
</script>

<template>
  <gl-drawer
    :open="isOpen"
    :header-height="getContentWrapperHeight()"
    :z-index="$options.DRAWER_Z_INDEX"
    @close="$emit('close')"
  >
    <template v-if="template" #title>
      <div class="gl-flex gl-flex-wrap gl-items-center gl-gap-4">
        <h2 class="gl-heading-2" data-testid="drawer-template-name">{{ template.name }}</h2>
        <gl-label
          v-if="template.color"
          class="gl-mb-5"
          :background-color="template.color"
          :title="template.name"
        />
      </div>
    </template>

    <template v-if="template" #header>
      <gl-button
        category="primary"
        variant="confirm"
        data-testid="drawer-use-template-btn"
        @click="$emit('use-template', template)"
      >
        {{ $options.i18n.useTemplate }}
      </gl-button>
    </template>

    <template v-if="template" #default>
      <div class="-gl-mx-5 gl-flex gl-flex-col">
        <div class="gl-mb-5 gl-px-5" data-testid="drawer-template-description">
          <h3 class="gl-heading-3">{{ $options.i18n.description }}</h3>
          <p class="gl-mb-0 gl-text-default">{{ template.description }}</p>
        </div>

        <div class="gl-border-t" data-testid="drawer-template-requirements">
          <div class="gl-flex gl-items-center gl-gap-1 gl-px-5">
            <h3 class="gl-heading-3 gl-mt-5">{{ $options.i18n.requirements }}</h3>
            <gl-badge class="gl-ml-2" variant="neutral" data-testid="drawer-requirements-count">{{
              requirements.length
            }}</gl-badge>
          </div>
          <drawer-accordion :items="requirements" class="!gl-p-0">
            <template #header="{ item: requirement }">
              <h4 class="gl-heading-4 gl-mb-3">{{ requirement.name }}</h4>
            </template>
            <template #default="{ item: requirement }">
              <p v-if="requirement.description" class="gl-text-subtle">
                {{ requirement.description }}
              </p>
              <template v-if="requirement.controls && requirement.controls.length">
                <h5 class="gl-mb-2 gl-mt-3 gl-font-bold gl-text-default">
                  {{ $options.i18n.controls }}:
                </h5>
                <ul class="gl-mb-0 gl-pl-5">
                  <li v-for="(control, idx) in displayControls(requirement.controls)" :key="idx">
                    {{ control.displayValue }}
                  </li>
                </ul>
              </template>
              <p v-else class="gl-mt-3 gl-text-subtle">{{ $options.i18n.noControls }}</p>
            </template>
          </drawer-accordion>
        </div>
      </div>
    </template>
  </gl-drawer>
</template>
