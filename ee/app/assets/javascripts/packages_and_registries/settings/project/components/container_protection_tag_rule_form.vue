<script>
import { GlFormGroup, GlFormRadio } from '@gitlab/ui';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import CeContainerProtectionTagRuleForm from '~/packages_and_registries/settings/project/components/container_protection_tag_rule_form.vue';

const PROTECTED_RULE_TYPE = 'protected';
const IMMUTABLE_RULE_TYPE = 'immutable';

export default {
  name: 'ContainerProtectionTagRuleForm',
  components: {
    CeContainerProtectionTagRuleForm,
    GlFormGroup,
    GlFormRadio,
  },
  mixins: [glAbilitiesMixin()],
  props: {
    ...CeContainerProtectionTagRuleForm.props,
    rule: {
      type: Object,
      required: false,
      default: null,
    },
  },
  emits: ['submit', 'cancel'],
  data() {
    return {
      tagRuleType: PROTECTED_RULE_TYPE,
    };
  },
  computed: {
    isProtected() {
      return this.tagRuleType === PROTECTED_RULE_TYPE;
    },
    canCreateImmutableTagRule() {
      return this.glAbilities.createContainerRegistryProtectionImmutableTagRule;
    },
    showProtectionType() {
      return this.canCreateImmutableTagRule && !this.rule;
    },
  },
  PROTECTED_RULE_TYPE,
  IMMUTABLE_RULE_TYPE,
};
</script>

<template>
  <ce-container-protection-tag-rule-form
    :rule="rule"
    :is-protected-tag-rule-type="isProtected"
    @submit="$emit('submit', $event)"
    @cancel="$emit('cancel')"
  >
    <template #protection-type>
      <gl-form-group v-if="showProtectionType" :label="s__('ContainerRegistry|Protection type')">
        <gl-form-radio
          v-model="tagRuleType"
          name="protection-type"
          :value="$options.PROTECTED_RULE_TYPE"
          autofocus
        >
          {{ s__('ContainerRegistry|Protected') }}
          <template #help>
            {{
              s__(
                'ContainerRegistry|Container image tags can be created, overwritten, or deleted by specific user roles.',
              )
            }}
          </template>
        </gl-form-radio>
        <gl-form-radio
          v-model="tagRuleType"
          name="protection-type"
          :value="$options.IMMUTABLE_RULE_TYPE"
        >
          {{ s__('ContainerRegistry|Immutable') }}
          <template #help>
            {{ s__('ContainerRegistry|Container image tags can never be overwritten or deleted.') }}
          </template>
        </gl-form-radio>
      </gl-form-group>
    </template>
  </ce-container-protection-tag-rule-form>
</template>
