<script>
import { GlButton, GlForm, GlCollapsibleListbox, GlTooltipDirective } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { EMPTY_TYPE, GROUP_TYPE, ROLE_TYPE, USER_TYPE } from 'ee/security_orchestration/constants';
import UserSelect from 'ee/security_orchestration/components/shared/user_select.vue';
import RoleSelect from 'ee/security_orchestration/components/shared/role_select.vue';
import SectionLayout from '../../section_layout.vue';
import {
  ADD_APPROVER_LABEL,
  APPROVER_TYPE_LIST_ITEMS,
  DEFAULT_APPROVER_DROPDOWN_TEXT,
} from '../lib/actions';
import GroupSelect from './group_select.vue';

export default {
  name: 'ApproverSelect',
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    SectionLayout,
    GlButton,
    GlForm,
    GlCollapsibleListbox,
    GroupSelect,
    UserSelect,
    RoleSelect,
  },
  props: {
    actionIndex: {
      type: Number,
      required: false,
      default: 0,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    errors: {
      type: Array,
      required: false,
      default: () => [],
    },
    disabledTypes: {
      type: Array,
      required: false,
      default: () => [],
    },
    showAdditionalText: {
      type: Boolean,
      required: false,
      default: false,
    },
    showRemoveButton: {
      type: Boolean,
      required: false,
      default: false,
    },
    selectedType: {
      type: String,
      required: false,
      default: '',
    },
    selectedItems: {
      type: Array,
      required: false,
      default: () => [],
    },
    selectedNames: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['error', 'remove', 'select-items', 'select-type'],
  computed: {
    approverComponent() {
      switch (this.selectedType) {
        case GROUP_TYPE:
          return GroupSelect;
        case ROLE_TYPE:
          return RoleSelect;
        case USER_TYPE:
          return UserSelect;
        default:
          return undefined;
      }
    },
    toggleText() {
      return this.selectedType && this.selectedType !== EMPTY_TYPE
        ? this.selectedItemText
        : DEFAULT_APPROVER_DROPDOWN_TEXT;
    },
    selectedItemText() {
      return APPROVER_TYPE_LIST_ITEMS.find((v) => v.value === this.selectedType)?.text;
    },
    listBoxItems() {
      return APPROVER_TYPE_LIST_ITEMS.map(({ value, text }) => ({
        value,
        text,
        disabled: this.isTypeDisabled(value),
      }));
    },
    isApproverFieldValid() {
      return this.errors
        .filter((error) => error.index === this.actionIndex)
        .every((error) => error.field !== 'actions');
    },
  },
  methods: {
    isTypeDisabled(type) {
      return this.disabledTypes.includes(type);
    },
    selectType(type) {
      if (this.isTypeDisabled(type)) {
        return;
      }

      this.$emit('select-type', type);
    },
    removeApprover() {
      this.$emit('remove');
    },
    selectItems(payload) {
      this.$emit('select-items', payload);
    },
  },
  i18n: {
    ADD_APPROVER_LABEL,
    disabledTitle: s__('SecurityOrchestration|You can select this option only once.'),
    multipleApproverTypesHumanizedTemplate: __('or'),
  },
};
</script>

<template>
  <section-layout
    class="gl-w-full gl-items-end gl-rounded-none gl-bg-default gl-py-0 gl-pr-0 @md/panel:gl-items-start"
    content-classes="gl-flex gl-w-full "
    :show-remove-button="showRemoveButton"
    @remove="removeApprover"
  >
    <template #content>
      <gl-form
        class="gl-w-full gl-flex-wrap gl-items-center @md/panel:gl-flex @md/panel:gl-gap-y-3"
        @submit.prevent
      >
        <gl-collapsible-listbox
          class="gl-mx-0 gl-mb-3 gl-block @md/panel:gl-mb-0 @md/panel:gl-mr-3"
          data-testid="available-types"
          :disabled="disabled"
          :items="listBoxItems"
          :selected="selectedType"
          :toggle-text="toggleText"
          @select="selectType"
        >
          <template #list-item="{ item }">
            <span
              v-gl-tooltip.right.viewport="{
                disabled: !item.disabled,
                title: $options.i18n.disabledTitle,
              }"
              class="gl-flex"
              data-testid="list-item-content"
              :class="{ '!gl-pointer-events-auto': item.disabled }"
            >
              <span
                :id="item.value"
                data-testid="list-item-text"
                class="gl-pr-3"
                :class="{ 'gl-text-subtle': item.disabled }"
              >
                {{ item.text }}
              </span>
            </span>
          </template>
        </gl-collapsible-listbox>

        <template v-if="selectedType">
          <keep-alive>
            <component
              :is="approverComponent"
              :key="selectedType"
              :selected="selectedItems"
              :selected-names="selectedNames"
              :state="isApproverFieldValid"
              class="security-policies-approver-max-width"
              data-testid="approver-items"
              @error="$emit('error')"
              @select-items="selectItems"
            />
          </keep-alive>
        </template>
        <p
          v-if="showAdditionalText"
          data-testid="additional-text"
          class="gl-mb-0 gl-ml-0 gl-mt-2 @md/panel:gl-ml-3 @md/panel:gl-mt-0"
        >
          {{ $options.i18n.multipleApproverTypesHumanizedTemplate }}
        </p>
      </gl-form>
    </template>
  </section-layout>
</template>
