<script>
import {
  GlFormCheckbox,
  GlFormGroup,
  GlFormInput,
  GlLink,
  GlSprintf,
  GlTooltipDirective,
} from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { duoFlowHelpPath } from '~/pages/projects/shared/permissions/constants';
import CascadingLockIcon from '~/namespaces/cascading_settings/components/cascading_lock_icon.vue';
import { helpPagePath } from '~/helpers/help_page_helper';
import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal';
import DuoCodeReviewConsentMessage from './duo_code_review_consent_message.vue';
import FoundationalFlowSelector from './foundational_flow_selector.vue';

const CODE_REVIEW_FLOW_REFERENCE = 'code_review/v1';

export default {
  name: 'DuoFlowSettings',
  i18n: {
    sectionTitle: __('Flow execution'),
    checkboxLabel: s__('DuoAgentPlatform|Allow flow execution'),
    checkboxHelpTextGroup: s__(
      'AiPowered|Allow GitLab Duo agents to execute flows in this group and its subgroups and projects. %{linkStart}What are flows%{linkEnd}?',
    ),
    checkboxHelpTextInstance: s__(
      'AiPowered|Allow GitLab Duo agents to execute flows for the instance. %{linkStart}What are flows%{linkEnd}?',
    ),
    flowsSectionTitle: s__('AiPowered|Flows'),
    foundationalFlowsLabel: s__('DuoAgentPlatform|Allow foundational flows'),
    foundationalFlowsHelpTextGroup: s__(
      'AiPowered|Allow GitLab Duo agents to execute foundational flows in this group and its subgroups and projects.',
    ),
    foundationalFlowsHelpTextInstance: s__(
      'AiPowered|Allow GitLab Duo agents to execute foundational flows for the instance.',
    ),
    defaultImageRegistryLabel: s__('DuoAgentPlatform|Image registry'),
    defaultImageRegistryHelp: s__(
      'AiPowered|Container registry for the foundational flow image. Enter either a registry hostname to use the default image from that registry or a full image reference to override the image entirely (for example, "registry.example.com/group/project/image:tag"). Leave blank to use "registry.gitlab.com".',
    ),
    defaultImageRegistryPlaceholder: s__('AiPowered|registry.gitlab.com'),
    codeReviewConfirmationMessage: s__(
      "DuoCodeReview|When you enable Code Review Flow for this namespace, all reviews will consume GitLab Credits, regardless of the user's seat. You can disable Code Review Flow at any time.",
    ),
    codeReviewConfirmationTitle: s__('DuoCodeReview|Enable Code Review Flow for this namespace?'),
    codeReviewConfirmationButton: s__('DuoCodeReview|Enable Code Review Flow'),
  },
  components: {
    CascadingLockIcon,
    DuoCodeReviewConsentMessage,
    GlFormCheckbox,
    GlFormGroup,
    GlFormInput,
    GlLink,
    GlSprintf,
    FoundationalFlowSelector,
  },

  directives: {
    tooltip: GlTooltipDirective,
  },
  inject: [
    'isGroupSettings',
    'isSaaS',
    'duoRemoteFlowsCascadingSettings',
    'duoFoundationalFlowsCascadingSettings',
    'duoEnterpriseActive',
    'initialCodeReviewFlowConsentGiven',
  ],
  props: {
    disabledCheckbox: {
      type: Boolean,
      required: true,
    },
    duoRemoteFlowsAvailability: {
      type: Boolean,
      required: true,
    },
    duoFoundationalFlowsAvailability: {
      type: Boolean,
      required: true,
    },
    selectedFoundationalFlowIds: {
      type: Array,
      required: false,
      default: () => [],
    },
    duoWorkflowsDefaultImageRegistry: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: [
    'change',
    'change-default-image-registry',
    'change-foundational-flows',
    'change-selected-flow-ids',
    'change-duo-template-project',
    'consent-given',
  ],
  data() {
    return {
      localSelectedFlowIds: this.selectedFoundationalFlowIds,
      defaultImageRegistry: this.duoWorkflowsDefaultImageRegistry,
      codeReviewFlowConsentGiven: this.initialCodeReviewFlowConsentGiven,
      selectorKey: 0,
    };
  },
  computed: {
    flowEnabled: {
      get() {
        return this.duoRemoteFlowsAvailability;
      },
      set(val) {
        this.$emit('change', val);
      },
    },
    foundationalFlowsEnabled: {
      get() {
        return this.duoFoundationalFlowsAvailability;
      },
      set(val) {
        this.$emit('change-foundational-flows', val);
        if (!val) {
          this.localSelectedFlowIds = [];
          this.$emit('change-selected-flow-ids', []);
        }
      },
    },
    description() {
      return this.isGroupSettings
        ? this.$options.i18n.checkboxHelpTextGroup
        : this.$options.i18n.checkboxHelpTextInstance;
    },
    foundationalFlowsDescription() {
      return this.isGroupSettings
        ? this.$options.i18n.foundationalFlowsHelpTextGroup
        : this.$options.i18n.foundationalFlowsHelpTextInstance;
    },
    disabledFlowCheckbox() {
      return this.disabledCheckbox || !this.flowEnabled;
    },
    disabledFoundationalFlows() {
      return this.disabledFlowCheckbox || !this.foundationalFlowsEnabled;
    },
    showCascadingButton() {
      return (
        this.duoRemoteFlowsCascadingSettings?.lockedByAncestor ||
        this.duoRemoteFlowsCascadingSettings?.lockedByApplicationSetting
      );
    },
    showCascadingButtonFoundationalFlows() {
      return (
        this.duoFoundationalFlowsCascadingSettings?.lockedByAncestor ||
        this.duoFoundationalFlowsCascadingSettings?.lockedByApplicationSetting
      );
    },
    shouldShowImageRegistryInput() {
      return !this.isGroupSettings && !this.isSaaS;
    },
    codeReviewFlowSelected() {
      return this.localSelectedFlowIds.includes(CODE_REVIEW_FLOW_REFERENCE);
    },
    isCodeReviewFlowConsentRequired() {
      return this.duoEnterpriseActive;
    },
  },
  methods: {
    async onFlowSelectionChanged(flowIds) {
      const addingCodeReview =
        flowIds.includes(CODE_REVIEW_FLOW_REFERENCE) &&
        !this.localSelectedFlowIds.includes(CODE_REVIEW_FLOW_REFERENCE);

      if (
        addingCodeReview &&
        this.isCodeReviewFlowConsentRequired &&
        !this.codeReviewFlowConsentGiven
      ) {
        const confirmed = await confirmAction(this.$options.i18n.codeReviewConfirmationMessage, {
          title: this.$options.i18n.codeReviewConfirmationTitle,
          primaryBtnText: this.$options.i18n.codeReviewConfirmationButton,
          primaryBtnVariant: 'confirm',
          cancelBtnText: __('Cancel'),
        });

        if (!confirmed) {
          // Increment the key to remount FoundationalFlowSelector with fresh
          // native DOM state. Vue would otherwise skip the DOM update because
          // :checked on GlFormCheckbox was never seen as false→true→false.
          this.selectorKey += 1;
          return;
        }

        this.codeReviewFlowConsentGiven = true;
        this.$emit('consent-given');
      }

      this.localSelectedFlowIds = flowIds;
      this.$emit('change-selected-flow-ids', flowIds);
    },
    onDefaultImageRegistryChanged() {
      this.$emit('change-default-image-registry', this.defaultImageRegistry);
    },
  },
  codeReviewFlowReference: CODE_REVIEW_FLOW_REFERENCE,
  duoFlowHelpPath,
  duoFlowPrerequisitesHelpPath: helpPagePath('user/duo_agent_platform/flows/_index.md', {
    anchor: 'prerequisites',
  }),
};
</script>
<template>
  <div>
    <h2 class="gl-heading-3 gl-mb-2 gl-mt-5" data-testid="flows-subsection-header">
      {{ $options.i18n.flowsSectionTitle }}
    </h2>
    <p class="gl-text-subtle" data-testid="flows-subsection-description">
      {{ s__('AiPowered|Combine one or more agents to solve a complex problem.') }}
    </p>
    <gl-form-group :label="$options.i18n.sectionTitle">
      <gl-form-checkbox
        v-model="flowEnabled"
        data-testid="duo-flow-features-checkbox"
        :disabled="disabledCheckbox || showCascadingButton"
      >
        <div class="gl-flex">
          <span
            id="duo-flow-checkbox-label"
            v-tooltip:[disabledCheckbox]="
              s__('AiPowered|This setting only applies when GitLab Duo is available.')
            "
            >{{ $options.i18n.checkboxLabel }}</span
          >
          <cascading-lock-icon
            v-if="showCascadingButton"
            class="gl-relative gl--inset-y-3"
            :is-locked-by-group-ancestor="duoRemoteFlowsCascadingSettings.lockedByAncestor"
            :is-locked-by-application-settings="
              duoRemoteFlowsCascadingSettings.lockedByApplicationSetting
            "
            :ancestor-namespace="duoRemoteFlowsCascadingSettings.ancestorNamespace"
          />
        </div>
        <template #help>
          <gl-sprintf :message="description">
            <template #link="{ content }">
              <gl-link :href="$options.duoFlowHelpPath" target="_blank">{{ content }}</gl-link>
            </template>
          </gl-sprintf>
        </template>
      </gl-form-checkbox>
      <gl-form-checkbox
        v-model="foundationalFlowsEnabled"
        data-testid="duo-foundational-flows-features-checkbox"
        :disabled="disabledCheckbox || !flowEnabled || showCascadingButtonFoundationalFlows"
      >
        <div class="gl-flex">
          <span
            id="duo-flow-checkbox-label"
            v-tooltip:[disabledFlowCheckbox]="
              s__('AiPowered|This setting only applies when flow execution is on.')
            "
            >{{ $options.i18n.foundationalFlowsLabel }}</span
          >
          <cascading-lock-icon
            v-if="showCascadingButtonFoundationalFlows"
            class="gl-relative gl--inset-y-3"
            :is-locked-by-group-ancestor="duoFoundationalFlowsCascadingSettings.lockedByAncestor"
            :is-locked-by-application-settings="
              duoFoundationalFlowsCascadingSettings.lockedByApplicationSetting
            "
            :ancestor-namespace="duoFoundationalFlowsCascadingSettings.ancestorNamespace"
          />
        </div>
        <template #help>
          {{ foundationalFlowsDescription }}
          <gl-sprintf
            :message="
              s__(
                'AiPowered|To add members to the group that contains the project, see the %{linkStart}prerequisites%{linkEnd}.',
              )
            "
          >
            <template #link="{ content }">
              <gl-link :href="$options.duoFlowPrerequisitesHelpPath">{{ content }}</gl-link>
            </template>
          </gl-sprintf>
        </template>
      </gl-form-checkbox>

      <foundational-flow-selector
        v-show="foundationalFlowsEnabled"
        :key="selectorKey"
        :value="localSelectedFlowIds"
        :disabled="disabledFoundationalFlows || showCascadingButtonFoundationalFlows"
        @input="onFlowSelectionChanged"
      >
        <template #after-flow="{ reference }">
          <duo-code-review-consent-message
            v-if="reference === $options.codeReviewFlowReference"
            :code-review-flow-selected="codeReviewFlowSelected"
            :code-review-flow-consent-given="codeReviewFlowConsentGiven"
          />
        </template>
      </foundational-flow-selector>

      <div v-if="shouldShowImageRegistryInput" class="gl-mt-5">
        <label for="duo-workflows-default-image-registry">
          {{ $options.i18n.defaultImageRegistryLabel }}
        </label>
        <gl-form-input
          id="duo-workflows-default-image-registry"
          v-model="defaultImageRegistry"
          name="application_setting[duo_workflows_default_image_registry]"
          type="text"
          :placeholder="$options.i18n.defaultImageRegistryPlaceholder"
          :disabled="disabledFoundationalFlows"
          data-testid="duo-workflows-default-image-registry-input"
          @input="onDefaultImageRegistryChanged"
        />
        <p class="gl-mb-0 gl-mt-2 gl-text-subtle">
          {{ $options.i18n.defaultImageRegistryHelp }}
        </p>
      </div>
    </gl-form-group>
  </div>
</template>
