<script>
import { GlIcon, GlFormRadioGroup, GlFormRadio, GlPopover, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import { CLOSED, OPEN } from './constants';

export default {
  name: 'FallbackSection',
  i18n: {
    subtitle: s__(
      "ScanResultPolicy|When this policy's criteria %{strongStart}cannot be met:%{strongEnd}",
    ),
    closedText: s__('ScanResultPolicy|Fail closed'),
    closedHelpText: s__('ScanResultPolicy|Block the merge request until all criteria are met'),
    openText: s__('ScanResultPolicy|Fail open'),
    openHelpText: s__(
      'ScanResultPolicy|Allow the merge request to proceed, even if not all criteria are met',
    ),
    popoverTitle: s__('ScanResultPolicy|Failure cases:'),
    popoverDesc: [
      s__(
        'ScanResultPolicy|Required scanners defined in the condition did not run or produce any artifacts.',
      ),
      s__(
        'ScanResultPolicy|For scanners that require builds, when a project does not have a build pipeline.',
      ),
      s__(
        'ScanResultPolicy|Required number of approvals became higher than available, valid approvers.',
      ),
      s__('ScanResultPolicy|When a security policy fails for an unspecified reason.'),
    ],
  },
  components: {
    GlIcon,
    GlFormRadioGroup,
    GlFormRadio,
    GlPopover,
    GlSprintf,
  },
  props: {
    property: {
      type: String,
      required: true,
      validation: (value) => [CLOSED, OPEN].includes(value),
    },
  },
  emits: ['changed'],
  computed: {
    fallbackOptions() {
      return [
        {
          value: OPEN,
          text: this.$options.i18n.openText,
          helpText: this.$options.i18n.openHelpText,
        },
        {
          value: CLOSED,
          text: this.$options.i18n.closedText,
          helpText: this.$options.i18n.closedHelpText,
        },
      ];
    },
  },
  methods: {
    updateProperty(value) {
      this.$emit('changed', 'fallback_behavior', { fail: value });
    },
  },
  POPOVER_TARGET_SELECTOR: 'fallback-popover',
};
</script>

<template>
  <div>
    <gl-sprintf :message="$options.i18n.subtitle">
      <template #strong="{ content }">
        <strong>{{ content }}</strong>
      </template>
    </gl-sprintf>
    <gl-icon :id="$options.POPOVER_TARGET_SELECTOR" name="information-o" />
    <div class="gl-mt-3">
      <gl-form-radio-group :checked="property" @change="updateProperty">
        <gl-form-radio v-for="option in fallbackOptions" :key="option.value" :value="option.value">
          {{ option.text }}
          <template #help>
            {{ option.helpText }}
          </template>
        </gl-form-radio>
      </gl-form-radio-group>
    </div>
    <gl-popover :target="$options.POPOVER_TARGET_SELECTOR" :title="$options.i18n.popoverTitle">
      <ul>
        <li v-for="(desc, index) in $options.i18n.popoverDesc" :key="index">
          {{ desc }}
        </li>
      </ul>
    </gl-popover>
  </div>
</template>
