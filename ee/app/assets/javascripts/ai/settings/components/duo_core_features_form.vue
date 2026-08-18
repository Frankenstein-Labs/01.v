<script>
import { GlFormCheckbox, GlFormGroup, GlLink, GlSprintf, GlTooltipDirective } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { DOCS_URL } from '~/constants';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import PromoPageLink from '~/vue_shared/components/promo_page_link/promo_page_link.vue';

export default {
  name: 'DuoCoreFeaturesForm',
  i18n: {
    sectionTitle: __('GitLab Duo Core'),
    subtitle: s__(
      'AiPowered|Allow users without a GitLab Duo Pro or Enterprise seat to access GitLab Duo Agent Platform features. %{linkStart}Which features are included%{linkEnd}?',
    ),
    subtitleOld: s__(
      'AiPowered|When this setting is turned on, users can access features included in the GitLab Duo Core add-on. %{linkStart}Which features are included%{linkEnd}?',
    ),
    checkboxLabel: s__('AiPowered|Turn on GitLab Duo Agent Platform access'),
    checkboxLabelOld: s__('AiPowered|Turn on features for GitLab Duo Core'),
    checkboxHelpTextSaaS: s__(
      'AiPowered|This setting applies to the top-level group. By turning on these features, you accept the %{termsLinkStart}GitLab Duo AI Terms%{termsLinkEnd} unless your organization has a separate agreement with GitLab that governs AI usage. %{prerequisitesLinkStart}What are the prerequisites for the GitLab Duo Agent Platform%{prerequisitesLinkEnd}?',
    ),
    checkboxHelpTextSaaSOld: s__(
      'AiPowered|This setting applies to the top-level group. By turning on these features, you accept the %{termsLinkStart}GitLab Duo AI Terms%{termsLinkEnd} unless your organization has a separate agreement with GitLab that governs AI usage.',
    ),
    checkboxHelpTextSelfManaged: s__(
      'AiPowered|This setting applies to the entire instance. By turning on these features, you accept the %{termsLinkStart}GitLab Duo AI Terms%{termsLinkEnd} unless your organization has a separate agreement with GitLab that governs AI usage. %{prerequisitesLinkStart}What are the prerequisites for the GitLab Duo Agent Platform%{prerequisitesLinkEnd}?',
    ),
    checkboxHelpTextSelfManagedOld: s__(
      'AiPowered|This setting applies to the entire instance. By turning on these features, you accept the %{termsLinkStart}GitLab Duo AI Terms%{termsLinkEnd} unless your organization has a separate agreement with GitLab that governs AI usage.',
    ),
  },
  components: {
    GlFormCheckbox,
    GlFormGroup,
    GlLink,
    GlSprintf,
    PromoPageLink,
  },
  directives: {
    tooltip: GlTooltipDirective,
  },
  mixins: [glFeatureFlagMixin()],
  inject: ['isSaaS'],
  props: {
    disabledCheckbox: {
      type: Boolean,
      required: true,
    },
    duoCoreFeaturesEnabled: {
      type: Boolean,
      required: true,
    },
    disabledByDap: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['change'],
  data() {
    return {
      duoCoreEnabled: this.duoCoreFeaturesEnabled,
    };
  },
  computed: {
    isCheckboxDisabled() {
      return this.disabledCheckbox || this.disabledByDap;
    },
    subtitle() {
      return this.glFeatures.noDuoClassicForDuoCoreUsers
        ? this.$options.i18n.subtitle
        : this.$options.i18n.subtitleOld;
    },
    checkboxLabel() {
      return this.glFeatures.noDuoClassicForDuoCoreUsers
        ? this.$options.i18n.checkboxLabel
        : this.$options.i18n.checkboxLabelOld;
    },
    description() {
      if (this.isSaaS) {
        return this.glFeatures.noDuoClassicForDuoCoreUsers
          ? this.$options.i18n.checkboxHelpTextSaaS
          : this.$options.i18n.checkboxHelpTextSaaSOld;
      }
      return this.glFeatures.noDuoClassicForDuoCoreUsers
        ? this.$options.i18n.checkboxHelpTextSelfManaged
        : this.$options.i18n.checkboxHelpTextSelfManagedOld;
    },
  },
  methods: {
    checkboxChanged() {
      this.$emit('change', this.duoCoreEnabled);
    },
  },
  // eslint-disable-next-line @gitlab/no-hardcoded-urls -- External GitLab handbook URL used with PromoPageLink, which prepends the about.gitlab.com base URL
  termsPath: `/handbook/legal/ai-functionality-terms/`,
  duoCoreFeaturesPath: `${DOCS_URL}/user/gitlab_duo/feature_summary/`,
  duoCorePrerequisitesPath: `${DOCS_URL}/user/duo_agent_platform/#prerequisites`,
};
</script>
<template>
  <div>
    <gl-form-group :label="$options.i18n.sectionTitle" class="gl-my-4">
      <template #label-description>
        <gl-sprintf :message="subtitle">
          <template #link="{ content }">
            <gl-link :href="$options.duoCoreFeaturesPath" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </template>
      <gl-form-checkbox
        v-model="duoCoreEnabled"
        data-testid="use-duo-core-features-checkbox"
        :disabled="isCheckboxDisabled"
        @change="checkboxChanged"
      >
        <span
          id="duo-core-checkbox-label"
          v-tooltip="
            disabledCheckbox
              ? s__('AiPowered|This setting only applies when GitLab Duo is available.')
              : disabledByDap
                ? s__(
                    'AiPowered|This setting only applies when GitLab Duo Agent Platform is enabled.',
                  )
                : ''
          "
          >{{ checkboxLabel }}</span
        >
        <template #help>
          <gl-sprintf :message="description">
            <template #br>
              <br />
            </template>
            <template #termsLink="{ content }">
              <promo-page-link :path="$options.termsPath" target="_blank">{{
                content
              }}</promo-page-link>
            </template>
            <template
              v-if="glFeatures.noDuoClassicForDuoCoreUsers"
              #prerequisitesLink="{ content }"
            >
              <gl-link :href="$options.duoCorePrerequisitesPath" target="_blank">{{
                content
              }}</gl-link>
            </template>
          </gl-sprintf>
        </template>
      </gl-form-checkbox>
    </gl-form-group>
  </div>
</template>
