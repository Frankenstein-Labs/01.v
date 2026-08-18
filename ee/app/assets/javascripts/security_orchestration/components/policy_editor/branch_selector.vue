<script>
import { GlButton, GlDisclosureDropdown, GlListboxItem, GlTruncate, GlSprintf } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { getParameterValues } from '~/lib/utils/url_utility';
import { mapExceptionsListBoxItem } from 'ee/security_orchestration/components/policy_editor/utils';
import { APPROVAL_POLICY_TYPE } from '../constants';
import BranchSelectorModal from './branch_selector_modal.vue';
import { BRANCH_TYPES_ITEMS } from './constants';

const BRANCH_SELECTOR_UNSELECTED = 'branch-selector-unselected';
const BRANCH_SELECTOR_SELECTED = 'branch-selector-selected';

export default {
  BRANCH_SELECTOR_UNSELECTED,
  BRANCH_SELECTOR_SELECTED,
  BRANCH_TYPES_ITEMS,
  name: 'BranchSelectorEE',
  i18n: {
    buttonAddBranchText: __('Add branches'),
    buttonAddProtectedText: __('Add protected branches'),
    buttonClearAllText: __('Clear all'),
    header: s__('SecurityOrchestration|Exception branches'),
    noBranchesText: s__('SecurityOrchestration|There are no exception branches yet.'),
    noBranchesAddText: s__(
      'SecurityOrchestration|%{boldStart}Add branches%{boldEnd} first before selection.',
    ),
    toggleText: s__('SecurityOrchestration|choose exception branches'),
  },
  components: {
    BranchSelectorModal,
    GlButton,
    GlDisclosureDropdown,
    GlListboxItem,
    GlTruncate,
    GlSprintf,
  },
  props: {
    selectedExceptions: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['select-branches'],
  data() {
    return {
      branches: this.selectedExceptions.map(mapExceptionsListBoxItem),
    };
  },
  computed: {
    isMergeRequestApprovalPolicy() {
      const [value] = getParameterValues('type');
      return value === APPROVAL_POLICY_TYPE;
    },
    addButtonText() {
      return this.isMergeRequestApprovalPolicy
        ? this.$options.i18n.buttonAddProtectedText
        : this.$options.i18n.buttonAddBranchText;
    },
    mappedToYamlFormatBranches() {
      return this.branches.map(({ name, fullPath }) => {
        if (fullPath) {
          return {
            name,
            full_path: fullPath,
          };
        }

        return name;
      });
    },
    hasBranches() {
      return this.branches?.length > 0;
    },
    toggleText() {
      return this.branches.map(({ name }) => name).join(', ') || this.$options.i18n.toggleText;
    },
  },
  methods: {
    finishEditing() {
      this.$emit('select-branches', this.mappedToYamlFormatBranches);
      this.$refs.dropdown.close();
    },
    showModal() {
      this.$refs.modal.showModalWindow();
    },
    selectBranches(branches) {
      this.branches = branches;
      this.$refs.dropdown.open();
    },
    unselectBranch({ name, fullPath }) {
      this.branches = this.branches.filter(
        (branch) => branch.name !== name || branch.fullPath !== fullPath,
      );
    },
    onResetButtonClicked() {
      this.branches = [];
      this.$emit('select-branches', []);
    },
  },
};
</script>

<template>
  <div>
    <gl-disclosure-dropdown
      ref="dropdown"
      toggle-class="gl-max-w-34"
      :toggle-text="toggleText"
      @hidden="finishEditing"
    >
      <template #header>
        <div class="gl-border-b gl-flex gl-min-h-8 gl-items-center gl-p-4">
          <div class="gl-grow gl-pr-2 gl-text-sm gl-font-bold">
            {{ $options.i18n.header }}
          </div>

          <gl-button
            v-if="hasBranches"
            category="tertiary"
            class="!gl-m-0 !gl-w-auto gl-max-w-1/2 gl-shrink-0 gl-text-ellipsis !gl-px-2 !gl-py-0 !gl-text-sm focus:!gl-shadow-inner-2-blue-400"
            data-testid="reset-button"
            @click="onResetButtonClicked"
          >
            {{ $options.i18n.buttonClearAllText }}
          </gl-button>
        </div>
      </template>

      <div class="gl-w-full">
        <template v-if="!hasBranches">
          <div
            class="security-policies-popover-content-height gl-pl-4 gl-pr-4 gl-pt-2 gl-text-base"
            data-testid="empty-state"
          >
            <p class="gl-mb-2">{{ $options.i18n.noBranchesText }}</p>
            <p>
              <gl-sprintf :message="$options.i18n.noBranchesAddText">
                <template #bold="{ content }">
                  <strong>{{ content }}</strong>
                </template>
              </gl-sprintf>
            </p>
          </div>
        </template>
        <template v-else>
          <gl-listbox-item
            v-for="(item, index) in branches"
            :key="`${item.name}_${index}`"
            is-check-centered
            is-selected
            @select="unselectBranch(item)"
          >
            <gl-truncate :text="item.name" />
            <p v-if="item.fullPath" class="gl-m-0 gl-mt-1 gl-text-sm gl-text-subtle">
              <gl-truncate position="middle" :text="item.fullPath" />
            </p>
          </gl-listbox-item>
        </template>
      </div>

      <template #footer>
        <div class="gl-border-t gl-flex gl-px-2 gl-py-2">
          <gl-button data-testid="add-button" category="tertiary" size="small" @click="showModal">
            {{ addButtonText }}
          </gl-button>
        </div>
      </template>
    </gl-disclosure-dropdown>

    <branch-selector-modal
      ref="modal"
      :branches="branches"
      :for-protected-branches="isMergeRequestApprovalPolicy"
      @add-branches="selectBranches"
    />
  </div>
</template>
